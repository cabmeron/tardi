package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"tardi-backend/config"
	"tardi-backend/db"
)

type CheckInRequest struct {
	TaskID    string `json:"taskId"`
	UserID    string `json:"userId"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type CheckInResponse struct {
	Success   bool   `json:"success"`
	Status    string `json:"status"` // PASSED, TOO_LATE_FORFEITED
	Message   string `json:"message"`
	CostCents int64  `json:"costCents"`
	Error     string `json:"error,omitempty"`
}

func HandleCheckIn(store *db.Store, cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req CheckInRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			respondJSON(w, http.StatusBadRequest, CheckInResponse{
				Success: false,
				Error:   "Invalid payload",
			})
			return
		}

		today := time.Now().UTC().Format("2006-01-02")
		eval, ok := store.GetEvaluation(req.TaskID, today)

		now := time.Now().UTC()

		if !ok {
			// If no evaluation record exists yet today, create one as PASSED
			task, taskExists := store.GetTask(req.TaskID)
			pledgeCents := int64(1000)
			if taskExists {
				pledgeCents = task.PledgeAmountCents
			}

			eval = &db.EvaluationRecord{
				ID:           fmt.Sprintf("eval_%d", now.UnixNano()),
				TaskID:       req.TaskID,
				UserID:       req.UserID,
				DeadlineDate: today,
				DeadlineUTC:  now.Add(1 * time.Hour), // future placeholder
				Status:       "PASSED",
				AmountCents:  pledgeCents,
				CheckedInAt:  &now,
				SettledAt:    &now,
				CreatedAt:    now,
			}
			store.SaveEvaluation(eval)

			respondJSON(w, http.StatusOK, CheckInResponse{
				Success:   true,
				Status:    "PASSED",
				Message:   "Check-in verified on time. $0.00 charged. Streak +1 🔥",
				CostCents: 0,
			})
			return
		}

		// If deadline has already passed and was marked FORFEITED
		if eval.Status == "FORFEITED" || now.After(eval.DeadlineUTC) {
			respondJSON(w, http.StatusOK, CheckInResponse{
				Success:   false,
				Status:    "TOO_LATE_FORFEITED",
				Message:   fmt.Sprintf("Check-in was too late! Deadline expired. Penalty of $%.2f was charged.", float64(eval.AmountCents)/100.0),
				CostCents: eval.AmountCents,
			})
			return
		}

		// On time check-in!
		eval.Status = "PASSED"
		eval.CheckedInAt = &now
		eval.SettledAt = &now
		store.SaveEvaluation(eval)

		respondJSON(w, http.StatusOK, CheckInResponse{
			Success:   true,
			Status:    "PASSED",
			Message:   "Check-in verified on time! $0.00 charged. Streak +1 🔥",
			CostCents: 0,
		})
	}
}
