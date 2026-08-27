package handlers

import (
	"encoding/json"
	"net/http"

	"tardi-backend/config"
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

func HandleAccountStatus(cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// In production, queries DB for user's debt status
		// By default, returns clean status
		respondJSON(w, http.StatusOK, AccountStatusResponse{
			IsLocked:               false,
			OutstandingAmountCents: 0,
			Message:                "Account is in good standing",
		})
	}
}

func HandleSettleDebt(cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req SettleDebtRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			respondJSON(w, http.StatusBadRequest, SettleDebtResponse{
				Success: false,
				Error:   "Invalid payload",
			})
			return
		}

		respondJSON(w, http.StatusOK, SettleDebtResponse{
			Success:  true,
			IsLocked: false,
			Message:  "Outstanding stake settled successfully. Account unlocked.",
		})
	}
}
