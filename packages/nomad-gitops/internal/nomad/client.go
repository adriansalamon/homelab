package nomad

import (
	"fmt"

	nomadapi "github.com/hashicorp/nomad/api"
)

const (
	nomadOpsKey       = "nomad-gitops"
	nomadOpsCommitKey = "nomad-gitops-commit"
)

type Client struct {
	client *nomadapi.Client
}

type JobDiff struct {
	IsNew      bool
	HasChanges bool
	Reason     string // Why changes were detected
}

func New() (*Client, error) {
	config := nomadapi.DefaultConfig()

	client, err := nomadapi.NewClient(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create nomad client: %w", err)
	}

	return &Client{client: client}, nil
}

// ParseJob parses HCL job definition
func (c *Client) ParseJob(hcl string) (*nomadapi.Job, error) {
	job, err := c.client.Jobs().ParseHCL(hcl, false)
	if err != nil {
		return nil, fmt.Errorf("failed to parse job: %w", err)
	}
	return job, nil
}

// PlanJob plans a job and detects if there are meaningful changes
func (c *Client) PlanJob(job *nomadapi.Job, hcl string, commitSHA string) (*JobDiff, error) {
	// Add metadata to track managed jobs
	if job.Meta == nil {
		job.Meta = make(map[string]string)
	}
	job.Meta[nomadOpsKey] = "true"
	job.Meta[nomadOpsCommitKey] = commitSHA

	// Check if job already exists
	_, _, err := c.client.Jobs().Info(*job.Name, nil)
	isNew := err != nil

	planResp, _, err := c.client.Jobs().Plan(job, true, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to plan job: %w", err)
	}

	diff := &JobDiff{
		IsNew: isNew,
	}

	if isNew {
		diff.HasChanges = true
		diff.Reason = "job is new"
		return diff, nil
	}

	// Analyze the plan diff
	hasChanges, reason := c.analyzeJobDiff(planResp.Diff)
	diff.HasChanges = hasChanges
	diff.Reason = reason

	return diff, nil
}

// analyzeJobDiff analyzes a job diff and returns whether there are meaningful changes
func (c *Client) analyzeJobDiff(diff *nomadapi.JobDiff) (bool, string) {
	if diff == nil {
		return false, "no diff"
	}

	// Check for top-level object changes (these are always significant)
	if len(diff.Objects) > 0 {
		return true, "top-level objects changed"
	}

	// Check for task group changes
	if len(diff.TaskGroups) > 0 {
		for _, tgDiff := range diff.TaskGroups {
			// Check for field changes (count, volumes, etc.)
			if len(tgDiff.Fields) > 0 {
				return true, "task group fields changed"
			}
			// Check for task changes
			if len(tgDiff.Tasks) > 0 {
				return true, "tasks changed"
			}
			// Check for nested object changes (services, etc.)
			if len(tgDiff.Objects) > 0 {
				return true, "task group objects changed"
			}
		}
	}

	// Check for field changes
	if len(diff.Fields) > 0 {
		for _, field := range diff.Fields {
			// Ignore if only metadata changed and it's just the commit SHA
			if field.Name == fmt.Sprintf("Meta[%s]", nomadOpsCommitKey) && len(diff.Fields) == 1 {
				return false, "only commit SHA changed"
			}
		}
		return true, "job fields changed"
	}

	return false, "no changes detected"
}

// ApplyJob registers a job with Nomad
func (c *Client) ApplyJob(job *nomadapi.Job, hcl string) (string, error) {
	res, _, err := c.client.Jobs().RegisterOpts(job, &nomadapi.RegisterOptions{
		Submission: &nomadapi.JobSubmission{
			Source: hcl,
			Format: "hcl2",
		},
	}, nil)
	if err != nil {
		return "", fmt.Errorf("failed to register job: %w", err)
	}

	return res.EvalID, nil
}

// DeleteJob deregisters a job from Nomad
func (c *Client) DeleteJob(jobName string) error {
	_, _, err := c.client.Jobs().Deregister(jobName, true, nil)
	if err != nil {
		return fmt.Errorf("failed to deregister job: %w", err)
	}
	return nil
}

func (c *Client) GetJob(jobName string) (*nomadapi.Job, error) {
	job, _, err := c.client.Jobs().Info(jobName, nil)
	if err != nil {
		return nil, err
	}
	return job, nil
}

func (c *Client) ListJobs() ([]*nomadapi.JobListStub, error) {
	jobs, _, err := c.client.Jobs().List(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to list jobs: %w", err)
	}
	return jobs, nil
}

func (c *Client) GetManagedJobs() (map[string]*nomadapi.Job, error) {
	jobList, err := c.ListJobs()
	if err != nil {
		return nil, err
	}

	managed := make(map[string]*nomadapi.Job)
	for _, stub := range jobList {
		job, err := c.GetJob(stub.Name)
		if err != nil {
			continue
		}
		if job.Meta != nil && job.Meta[nomadOpsKey] == "true" {
			managed[stub.Name] = job
		}
	}

	return managed, nil
}
