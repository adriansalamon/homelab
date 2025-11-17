package consul

import (
	"encoding/json"
	"fmt"
	"time"

	consulapi "github.com/hashicorp/consul/api"
)

type State struct {
	client *consulapi.Client
	prefix string
}

type SyncState struct {
	LastCommitSHA string    `json:"last_commit_sha"`
	LastSyncTime  time.Time `json:"last_sync_time"`
	LastError     string    `json:"last_error"`
	DeployedJobs  []string  `json:"deployed_jobs"`
}

func New(prefix string) (*State, error) {
	config := consulapi.DefaultConfig()

	client, err := consulapi.NewClient(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create consul client: %w", err)
	}

	return &State{
		client: client,
		prefix: prefix,
	}, nil
}

// GetSyncState retrieves the current sync state
func (s *State) GetSyncState() (*SyncState, error) {
	key := s.prefix + "/state"
	pair, _, err := s.client.KV().Get(key, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get state from consul: %w", err)
	}

	if pair == nil {
		return &SyncState{
			LastSyncTime: time.Now(),
		}, nil
	}

	var state SyncState
	if err := json.Unmarshal(pair.Value, &state); err != nil {
		return nil, fmt.Errorf("failed to unmarshal state: %w", err)
	}

	return &state, nil
}

// SaveSyncState saves the sync state
func (s *State) SaveSyncState(state *SyncState) error {
	key := s.prefix + "/state"
	data, err := json.Marshal(state)
	if err != nil {
		return fmt.Errorf("failed to marshal state: %w", err)
	}

	_, err = s.client.KV().Put(&consulapi.KVPair{
		Key:   key,
		Value: data,
	}, nil)
	if err != nil {
		return fmt.Errorf("failed to save state to consul: %w", err)
	}

	return nil
}

// SaveLastCommitSHA saves just the commit SHA
func (s *State) SaveLastCommitSHA(sha string) error {
	state, err := s.GetSyncState()
	if err != nil {
		return err
	}

	state.LastCommitSHA = sha
	state.LastSyncTime = time.Now()
	state.LastError = ""

	return s.SaveSyncState(state)
}

// SaveError saves the last error
func (s *State) SaveError(errMsg string) error {
	state, err := s.GetSyncState()
	if err != nil {
		return err
	}

	state.LastError = errMsg
	state.LastSyncTime = time.Now()

	return s.SaveSyncState(state)
}

// SaveDeployedJobs saves the list of deployed job names
func (s *State) SaveDeployedJobs(jobs []string) error {
	state, err := s.GetSyncState()
	if err != nil {
		return err
	}

	state.DeployedJobs = jobs

	return s.SaveSyncState(state)
}
