package git

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	gogit "github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing"
)

type Repository struct {
	url      string
	branch   string
	workdir  string
	repo     *gogit.Repository
	worktree *gogit.Worktree
}

func New(url, branch, workdir string) *Repository {
	return &Repository{
		url:     url,
		branch:  branch,
		workdir: workdir,
	}
}

// Init clones the repository if it doesn't exist, otherwise opens it
func (r *Repository) Init(ctx context.Context) error {
	// Create workdir if it doesn't exist
	if err := os.MkdirAll(r.workdir, 0755); err != nil {
		return fmt.Errorf("failed to create workdir: %w", err)
	}

	// Check if repo already exists
	repo, err := gogit.PlainOpen(r.workdir)
	if err == nil {
		r.repo = repo
		worktree, err := repo.Worktree()
		if err != nil {
			return fmt.Errorf("failed to get worktree: %w", err)
		}
		r.worktree = worktree
		return nil
	}

	repo, err = gogit.PlainCloneContext(ctx, r.workdir, false, &gogit.CloneOptions{
		URL:           r.url,
		ReferenceName: plumbing.NewBranchReferenceName(r.branch),
		SingleBranch:  true,
		Depth:         1,
	})
	if err != nil {
		return fmt.Errorf("failed to clone repository: %w", err)
	}

	worktree, err := repo.Worktree()
	if err != nil {
		return fmt.Errorf("failed to get worktree: %w", err)
	}

	r.repo = repo
	r.worktree = worktree
	return nil
}

// Pull updates the repository
func (r *Repository) Pull(ctx context.Context) error {
	if r.worktree == nil {
		return fmt.Errorf("repository not initialized")
	}

	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	err := r.worktree.PullContext(ctx, &gogit.PullOptions{
		ReferenceName: plumbing.NewBranchReferenceName(r.branch),
		SingleBranch:  true,
	})

	if err != nil && err.Error() != "already up-to-date" {
		return fmt.Errorf("failed to pull repository: %w", err)
	}

	return nil
}

func (r *Repository) GetCommitSHA() (string, error) {
	if r.repo == nil {
		return "", fmt.Errorf("repository not initialized")
	}

	ref, err := r.repo.Head()
	if err != nil {
		return "", fmt.Errorf("failed to get HEAD: %w", err)
	}

	return ref.Hash().String(), nil
}

func (r *Repository) GetFilesByGlob(pattern string) ([]string, error) {
	if r.worktree == nil {
		return nil, fmt.Errorf("repository not initialized")
	}

	matches, err := filepath.Glob(filepath.Join(r.workdir, pattern))
	if err != nil {
		return nil, fmt.Errorf("failed to glob files: %w", err)
	}

	// Return relative paths
	var relativePaths []string
	for _, match := range matches {
		rel, err := filepath.Rel(r.workdir, match)
		if err != nil {
			continue
		}
		relativePaths = append(relativePaths, rel)
	}

	return relativePaths, nil
}

func (r *Repository) ReadFile(path string) ([]byte, error) {
	if r.worktree == nil {
		return nil, fmt.Errorf("repository not initialized")
	}

	fullPath := filepath.Join(r.workdir, path)
	return os.ReadFile(fullPath)
}
