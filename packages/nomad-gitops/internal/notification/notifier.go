package notification

type Notifier interface {
	SendSuccess(title, message string)
	SendError(title, message string)
}

type DummyNotifier struct{}

func (d *DummyNotifier) SendSuccess(title, message string) {
	// Do nothing
}

func (d *DummyNotifier) SendError(title, message string) {
	// Do nothing
}

func NewDummyNotifier() *DummyNotifier {
	return &DummyNotifier{}
}
