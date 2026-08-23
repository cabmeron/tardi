package handlers

import (
	"encoding/json"
	"net/http"

	"tardi-backend/config"
	"tardi-backend/db"
)

type AccountStatusResponse struct {
	IsLocked               bool   `json:"isLocked"`
	OutstandingAmountCents int64  `json:"outstandingAmountCents"`
	FailedTaskTitle        string `json:"failedTaskTitle,omitempty"`
	Message                string `json:"message,omitempty"`
}

type SettleDebtRequest struct {
	UserID          string `json:"userId"`
	PaymentMethodID string `json:"paymentMethodId"`
	AmountCents     int64  `json:"amountCents"`
}

type SettleDebtResponse struct {
	Success  bool   `json:"success"`
	IsLocked bool   `json:"isLocked"`
	Message  string `json:"message"`
	Error    string `json:"error,omitempty"`
}

func HandleAccountStatus(store *db.Store, cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.URL.Query().Get("userId")
		if userID == "" {
			userID = "user_default"
		}

		user, ok := store.GetUser(userID)
		if ok && user.IsLockedForDebt {
			respondJSON(w, http.StatusOK, AccountStatusResponse{
				IsLocked:               true,
				OutstandingAmountCents: user.OutstandingDebtAmount,
				FailedTaskTitle:        user.FailedTaskTitle,
				Message:                "Account locked: outstanding forfeited balance due",
			})
			return
		}

		respondJSON(w, http.StatusOK, AccountStatusResponse{
			IsLocked:               false,
			OutstandingAmountCents: 0,
			Message:                "Account is in good standing",
		})
	}
}

func HandleSettleDebt(store *db.Store, cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req SettleDebtRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			respondJSON(w, http.StatusBadRequest, SettleDebtResponse{
				Success: false,
				Error:   "Invalid payload",
			})
			return
		}

		user, ok := store.GetUser(req.UserID)
		if ok {
			user.IsLockedForDebt = false
			user.OutstandingDebtAmount = 0
			store.SaveUser(user)
		}

		respondJSON(w, http.StatusOK, SettleDebtResponse{
			Success:  true,
			IsLocked: false,
			Message:  "Outstanding stake settled successfully. Account unlocked.",
		})
	}
}
