package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"tardi-backend/scheduler"
)

// HandleSchedulerHealth returns a lightweight 200 OK health check for monitoring probes.
func HandleSchedulerHealth(s *scheduler.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		health := s.GetHealth(r.Context())
		status := http.StatusOK
		if health.Status == "degraded" {
			status = http.StatusServiceUnavailable
		}
		respondJSON(w, status, health)
	}
}

// HandleSchedulerStatus returns rich operational telemetry, pending queue depth, and metrics.
func HandleSchedulerStatus(s *scheduler.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		metrics := s.GetStatus(r.Context())
		respondJSON(w, http.StatusOK, metrics)
	}
}

type ScheduleTaskRequest struct {
	TaskID            string `json:"taskId"`
	UserID            string `json:"userId"`
	CustomerID        string `json:"customerId"`
	PledgeAmountCents int64  `json:"pledgeAmountCents"`
	TaskTitle         string `json:"taskTitle"`
	LocationName      string `json:"locationName"`
	DeadlineTimestamp int64  `json:"deadlineTimestamp"` // Unix Epoch timestamp in seconds
	DeadlineDate      string `json:"deadlineDate,omitempty"`
	StoredHMACSeal    string `json:"storedHmacSeal,omitempty"`
}

type ScheduleTaskResponse struct {
	Success           bool   `json:"success"`
	TaskID            string `json:"taskId"`
	DeadlineTimestamp int64  `json:"deadlineTimestamp"`
	Message           string `json:"message"`
	Error             string `json:"error,omitempty"`
}

// HandleScheduleTask registers a new habit task deadline in the Redis Sorted Set.
func HandleScheduleTask(s *scheduler.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req ScheduleTaskRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.TaskID == "" {
			respondJSON(w, http.StatusBadRequest, ScheduleTaskResponse{
				Success: false,
				Error:   "Invalid payload: taskId is required",
			})
			return
		}

		if req.DeadlineTimestamp == 0 && req.DeadlineDate != "" {
			if parsed, err := time.Parse(time.RFC3339, req.DeadlineDate); err == nil {
				req.DeadlineTimestamp = parsed.Unix()
			}
		}

		if req.DeadlineTimestamp == 0 {
			respondJSON(w, http.StatusBadRequest, ScheduleTaskResponse{
				Success: false,
				Error:   "deadlineTimestamp (Unix Epoch seconds) is required",
			})
			return
		}

		item := scheduler.ScheduledDeadline{
			TaskID:            req.TaskID,
			UserID:            req.UserID,
			CustomerID:        req.CustomerID,
			PledgeAmountCents: req.PledgeAmountCents,
			TaskTitle:         req.TaskTitle,
			LocationName:      req.LocationName,
			DeadlineDate:      time.Unix(req.DeadlineTimestamp, 0),
			DeadlineTimestamp: req.DeadlineTimestamp,
			StoredHMACSeal:    req.StoredHMACSeal,
			CreatedAt:         time.Now(),
		}

		if err := s.Schedule(r.Context(), item); err != nil {
			respondJSON(w, http.StatusInternalServerError, ScheduleTaskResponse{
				Success: false,
				Error:   err.Error(),
			})
			return
		}

		respondJSON(w, http.StatusOK, ScheduleTaskResponse{
			Success:           true,
			TaskID:            req.TaskID,
			DeadlineTimestamp: req.DeadlineTimestamp,
			Message:           "Task deadline successfully enqueued in Redis Sorted Set",
		})
	}
}

type CancelTaskRequest struct {
	TaskID string `json:"taskId"`
}

type CancelTaskResponse struct {
	Success bool   `json:"success"`
	TaskID  string `json:"taskId"`
	Message string `json:"message"`
	Error   string `json:"error,omitempty"`
}

// HandleCancelTask removes a scheduled deadline upon verified on-time check-in.
func HandleCancelTask(s *scheduler.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req CancelTaskRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.TaskID == "" {
			respondJSON(w, http.StatusBadRequest, CancelTaskResponse{
				Success: false,
				Error:   "Invalid payload: taskId is required",
			})
			return
		}

		if err := s.Cancel(r.Context(), req.TaskID); err != nil {
			respondJSON(w, http.StatusInternalServerError, CancelTaskResponse{
				Success: false,
				Error:   err.Error(),
			})
			return
		}

		respondJSON(w, http.StatusOK, CancelTaskResponse{
			Success: true,
			TaskID:  req.TaskID,
			Message: "Task deadline canceled from Redis queue (Goal Met!)",
		})
	}
}
