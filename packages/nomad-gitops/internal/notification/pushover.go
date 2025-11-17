package notification

import (
	"fmt"

	"github.com/gregdel/pushover"
)

type PushoverNotifier struct {
	userKey  string
	apiToken string
}

type NotificationPayload struct {
	Title    string
	Message  string
	Priority int // -2 to 2
}

func NewPushover(userKey, apiToken string) *PushoverNotifier {
	return &PushoverNotifier{
		userKey:  userKey,
		apiToken: apiToken,
	}
}

// Send sends a notification via Pushover
func (p *PushoverNotifier) Send(payload *NotificationPayload) error {
	app := pushover.New(p.apiToken)

	recipient := pushover.NewRecipient(p.userKey)

	message := &pushover.Message{
		Title:    payload.Title,
		Message:  payload.Message,
		Priority: payload.Priority,
	}

	response, err := app.SendMessage(message, recipient)
	if err != nil {
		return fmt.Errorf("failed to send pushover notification: %w", err)
	}

	if response.Status != 1 {
		return fmt.Errorf("pushover returned status %d: %s", response.Status, response.Errors)
	}

	return nil
}

// SendSuccess sends a success notification
func (p *PushoverNotifier) SendSuccess(title, message string) error {
	return p.Send(&NotificationPayload{
		Title:    title,
		Message:  message,
		Priority: 0,
	})
}

// SendError sends an error notification
func (p *PushoverNotifier) SendError(title, message string) error {
	return p.Send(&NotificationPayload{
		Title:    title,
		Message:  message,
		Priority: 1,
	})
}
