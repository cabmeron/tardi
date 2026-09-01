package scheduler

import "time"

// ScheduledDeadline represents a habit task commitment with a financial stake waiting for deadline evaluation.
type ScheduledDeadline struct {
	TaskID            string    `json:"taskId"`
	UserID            string    `json:"userId"`
	CustomerID        string    `json:"customerId"`
	PledgeAmountCents int64     `json:"pledgeAmountCents"`
	TaskTitle         string    `json:"taskTitle"`
	LocationName      string    `json:"locationName"`
	DeadlineDate      time.Time `json:"deadlineDate"`
	DeadlineTimestamp int64     `json:"deadlineTimestamp"` // Unix Epoch timestamp in seconds
	StoredHMACSeal    string    `json:"storedHmacSeal,omitempty"`
	CreatedAt         time.Time `json:"createdAt"`
}

// SchedulerStatus represents the detailed real-time health and telemetry metrics of the deadline poller.
type SchedulerStatus struct {
	Service                   string     `json:"service"`
	Status                    string     `json:"status"` // HEALTHY, DEGRADED, SANDBOX_MOCK
	RedisConnected            bool       `json:"redisConnected"`
	RedisAddress              string     `json:"redisAddress"`
	RedisPingLatencyMs        float64    `json:"redisPingLatencyMs"`
	WorkerRunning             bool       `json:"workerRunning"`
	PollIntervalMs            int        `json:"pollIntervalMs"`
	PendingTasksCount         int64      `json:"pendingTasksCount"`
	TotalProcessedCount       int64      `json:"totalProcessedCount"`
	TotalForfeituresCount     int64      `json:"totalForfeituresCount"`
	TotalForfeitedAmountCents int64      `json:"totalForfeitedAmountCents"`
	UptimeSeconds             int64      `json:"uptimeSeconds"`
	LastPollTimestamp         time.Time  `json:"lastPollTimestamp"`
	NextUpcomingDeadline      *time.Time `json:"nextUpcomingDeadline,omitempty"`
	NextUpcomingTaskID        string     `json:"nextUpcomingTaskId,omitempty"`
	Message                   string     `json:"message"`
}

// HealthResponse represents a lightweight health-check response.
type HealthResponse struct {
	Status         string    `json:"status"` // healthy, degraded
	WorkerRunning  bool      `json:"workerRunning"`
	RedisConnected bool      `json:"redisConnected"`
	PendingTasks   int64     `json:"pendingTasks"`
	Timestamp      time.Time `json:"timestamp"`
}
