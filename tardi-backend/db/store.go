package db

import (
	"sync"
	"time"
)

type TaskRecord struct {
	ID                string    `json:"id"`
	UserID            string    `json:"userId"`
	LocationName      string    `json:"locationName"`
	TaskTitle         string    `json:"taskTitle"`
	PledgeAmountCents int64     `json:"pledgeAmountCents"`
	HMACSeal          string    `json:"hmacSeal"`
	DeadlineHour      int       `json:"deadlineHour"`
	DeadlineMinute    int       `json:"deadlineMinute"`
	Timezone          string    `json:"timezone"`
	IsActive          bool      `json:"isActive"`
	CreatedAt         time.Time `json:"createdAt"`
}

type EvaluationRecord struct {
	ID                    string     `json:"id"`
	TaskID                string     `json:"taskId"`
	UserID                string     `json:"userId"`
	DeadlineDate          string     `json:"deadlineDate"` // "2026-08-23"
	DeadlineUTC           time.Time  `json:"deadlineUtc"`
	Status                string     `json:"status"` // PENDING, PASSED, FORFEITED, PAYMENT_FAILED
	AmountCents           int64      `json:"amountCents"`
	StripePaymentIntentID string     `json:"stripePaymentIntentId,omitempty"`
	DeclineCode           string     `json:"declineCode,omitempty"`
	CheckedInAt           *time.Time `json:"checkedInAt,omitempty"`
	SettledAt             *time.Time `json:"settledAt,omitempty"`
	CreatedAt             time.Time  `json:"createdAt"`
}

type UserRecord struct {
	ID                    string `json:"id"`
	Email                 string `json:"email"`
	StripeCustomerID      string `json:"stripeCustomerId"`
	SecureEnclavePubKey   string `json:"secureEnclavePubKey,omitempty"`
	IsLockedForDebt       bool   `json:"isLockedForDebt"`
	OutstandingDebtAmount int64  `json:"outstandingDebtAmount"`
	FailedTaskTitle       string `json:"failedTaskTitle,omitempty"`
}

// Store is an in-memory, thread-safe persistence layer with PostgreSQL interface compatibility
type Store struct {
	mu          sync.RWMutex
	users       map[string]*UserRecord
	tasks       map[string]*TaskRecord
	evaluations map[string]*EvaluationRecord // key: "taskId_deadlineDate"
}

func NewStore() *Store {
	return &Store{
		users:       make(map[string]*UserRecord),
		tasks:       make(map[string]*TaskRecord),
		evaluations: make(map[string]*EvaluationRecord),
	}
}

// User methods
func (s *Store) SaveUser(u *UserRecord) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.users[u.ID] = u
}

func (s *Store) GetUser(userID string) (*UserRecord, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	u, ok := s.users[userID]
	return u, ok
}

// Task methods
func (s *Store) SaveTask(t *TaskRecord) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.tasks[t.ID] = t
}

func (s *Store) GetTask(taskID string) (*TaskRecord, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	t, ok := s.tasks[taskID]
	return t, ok
}

// Evaluation methods
func (s *Store) SaveEvaluation(e *EvaluationRecord) {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := e.TaskID + "_" + e.DeadlineDate
	s.evaluations[key] = e
}

func (s *Store) GetEvaluation(taskID string, deadlineDate string) (*EvaluationRecord, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	key := taskID + "_" + deadlineDate
	e, ok := s.evaluations[key]
	return e, ok
}

// FindExpiredPendingEvaluations returns all evaluations whose deadline passed > gracePeriod ago
func (s *Store) FindExpiredPendingEvaluations(gracePeriod time.Duration) []*EvaluationRecord {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var expired []*EvaluationRecord
	now := time.Now().UTC()

	for _, eval := range s.evaluations {
		if eval.Status == "PENDING" && now.After(eval.DeadlineUTC.Add(gracePeriod)) {
			expired = append(expired, eval)
		}
	}
	return expired
}
