package reconcile

import (
	"context"
	"fmt"
	"log/slog"
	"nomad-gitops/internal/consul"
	"nomad-gitops/internal/git"
	"nomad-gitops/internal/nomad"
	"nomad-gitops/internal/notification"
	"strings"
)

type Reconciler struct {
	nomadClient *nomad.Client
	gitRepo     *git.Repository
	consulState *consul.State
	notifier    notification.Notifier
	jobPaths    []string
	logger      *slog.Logger
}

func New(
	nomadClient *nomad.Client,
	gitRepo *git.Repository,
	consulState *consul.State,
	notifier notification.Notifier,
	jobPaths []string,
	logger *slog.Logger,
) *Reconciler {
	return &Reconciler{
		nomadClient: nomadClient,
		gitRepo:     gitRepo,
		consulState: consulState,
		notifier:    notifier,
		jobPaths:    jobPaths,
		logger:      logger,
	}
}

type ReconcileResult struct {
	Created []string
	Updated []string
	Deleted []string
	Errors  []string
}

// Reconcile syncs the desired state from git with the actual Nomad cluster state
func (r *Reconciler) Reconcile(ctx context.Context) (*ReconcileResult, error) {
	result := &ReconcileResult{
		Created: []string{},
		Updated: []string{},
		Deleted: []string{},
		Errors:  []string{},
	}

	if err := r.gitRepo.Pull(ctx); err != nil {
		r.logger.Error("failed to pull git repository", "error", err)
		r.consulState.SaveError(err.Error())
		return result, err
	}

	commitSHA, err := r.gitRepo.GetCommitSHA()
	if err != nil {
		r.logger.Error("failed to get commit SHA", "error", err)
		r.consulState.SaveError(err.Error())
		return result, err
	}

	prevState, err := r.consulState.GetSyncState()
	if err != nil {
		r.logger.Error("failed to get previous sync state", "error", err)
	}

	// If already synced to this commit, skip. Maybe we should check that all deployed jobs have same commit?
	if prevState != nil && prevState.LastCommitSHA == commitSHA {
		r.logger.Info("already synced to this commit", "sha", commitSHA)
		return result, nil
	}

	r.logger.Info("syncing to commit", "sha", commitSHA)

	// Collect all job files from all paths
	allJobFiles := make(map[string]struct{})
	for _, jobPath := range r.jobPaths {
		jobFiles, err := r.gitRepo.GetFilesByGlob(jobPath)
		if err != nil {
			r.logger.Error("failed to glob job files", "path", jobPath, "error", err)
			r.consulState.SaveError(fmt.Sprintf("glob error in path %s: %v", jobPath, err))
			return result, err
		}
		r.logger.Debug("found job files", "path", jobPath, "count", len(jobFiles))

		for _, jobFile := range jobFiles {
			allJobFiles[jobFile] = struct{}{}
		}
	}

	r.logger.Info("total job files found", "count", len(allJobFiles))

	// Map of desired jobs (name -> job)
	desiredJobs := make(map[string]string)

	for jobFile, _ := range allJobFiles {
		hcl, err := r.gitRepo.ReadFile(jobFile)
		if err != nil {
			errMsg := fmt.Sprintf("failed to read job file %s: %v", jobFile, err)
			r.logger.Error(errMsg)
			result.Errors = append(result.Errors, errMsg)
			continue
		}

		hclStr := string(hcl)

		// Parse job
		parsedJob, err := r.nomadClient.ParseJob(string(hcl))
		if err != nil {
			errMsg := fmt.Sprintf("failed to parse job %s: %v", jobFile, err)
			r.logger.Error(errMsg)
			result.Errors = append(result.Errors, errMsg)
			continue
		}

		jobName := *parsedJob.Name
		desiredJobs[jobName] = hclStr

		// Plan job to detect changes
		jobDiff, err := r.nomadClient.PlanJob(parsedJob, hclStr, commitSHA)
		if err != nil {
			errMsg := fmt.Sprintf("failed to plan job %s: %v", jobName, err)
			r.logger.Error(errMsg)
			result.Errors = append(result.Errors, errMsg)
			continue
		}

		// Only apply if there are changes or if it's a new job
		if !jobDiff.HasChanges && !jobDiff.IsNew {
			r.logger.Debug("job unchanged", "name", jobName, "reason", jobDiff.Reason)
			continue
		}

		// Apply job
		evalID, err := r.nomadClient.ApplyJob(parsedJob, hclStr)
		if err != nil {
			errMsg := fmt.Sprintf("failed to apply job %s: %v", jobName, err)
			r.logger.Error(errMsg)
			result.Errors = append(result.Errors, errMsg)
			continue
		}

		if jobDiff.IsNew {
			r.logger.Info("created job", "name", jobName, "evalID", evalID)
			result.Created = append(result.Created, jobName)
		} else {
			r.logger.Info("updated job", "name", jobName, "reason", jobDiff.Reason, "evalID", evalID)
			result.Updated = append(result.Updated, jobName)
		}
	}

	// Get all managed jobs from Nomad
	managedJobs, err := r.nomadClient.GetManagedJobs()
	if err != nil {
		errMsg := fmt.Sprintf("failed to list managed jobs: %v", err)
		r.logger.Error(errMsg)
		result.Errors = append(result.Errors, errMsg)
	} else {
		// Delete jobs that are no longer in git
		for jobName := range managedJobs {
			if _, exists := desiredJobs[jobName]; !exists {
				if err := r.nomadClient.DeleteJob(jobName); err != nil {
					errMsg := fmt.Sprintf("failed to delete job %s: %v", jobName, err)
					r.logger.Error(errMsg)
					result.Errors = append(result.Errors, errMsg)
					continue
				}
				r.logger.Info("deleted job", "name", jobName)
				result.Deleted = append(result.Deleted, jobName)
			}
		}
	}

	// Save sync state
	allJobs := append(append(result.Created, result.Updated...), result.Deleted...)
	if err := r.consulState.SaveLastCommitSHA(commitSHA); err != nil {
		r.logger.Error("failed to save commit SHA to consul", "error", err)
	}
	if err := r.consulState.SaveDeployedJobs(allJobs); err != nil {
		r.logger.Error("failed to save deployed jobs to consul", "error", err)
	}

	if len(result.Created) > 0 || len(result.Updated) > 0 || len(result.Deleted) > 0 {
		message := fmt.Sprintf("Created: %d, Updated: %d, Deleted: %d",
			len(result.Created), len(result.Updated), len(result.Deleted))
		r.notifier.SendSuccess("Nomad Sync", message)
	}

	if len(result.Errors) > 0 {
		errMessage := strings.Join(result.Errors, "; ")
		r.notifier.SendError("Nomad Sync Error", errMessage)
	}

	return result, nil
}
