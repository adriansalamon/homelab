package main

import (
	"fmt"
	"net/http"
	"net/url"
	"strings"
)

type PushoverClient struct {
	userKey string
	appKey  string
	client  *http.Client
}

func NewPushoverClient(userKey, appKey string) (*PushoverClient, error) {
	if userKey == "" || appKey == "" {
		return nil, fmt.Errorf("user key and app key are required")
	}

	return &PushoverClient{
		userKey: userKey,
		appKey:  appKey,
		client:  &http.Client{},
	}, nil
}

func (p *PushoverClient) Send(title, body, priority string) error {
	data := url.Values{}
	data.Set("user", p.userKey)
	data.Set("token", p.appKey)
	data.Set("title", title)
	data.Set("message", body)
	data.Set("priority", priority)

	req, err := http.NewRequest("POST", "https://api.pushover.net/1/messages.json", strings.NewReader(data.Encode()))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := p.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("pushover request failed with status %d", resp.StatusCode)
	}

	return nil
}
