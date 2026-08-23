package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"tardi-backend/config"
	"tardi-backend/crypto"
	"tardi-backend/db"

	"github.com/stripe/stripe-go/v78"
	"github.com/stripe/stripe-go/v78/paymentintent"
)

type ForfeitRequest struct {
	TaskID            string `json:"taskId"`
	UserID            string `json:"userId"`
	CustomerID        string `json:"customerId"`
	PaymentMethodID   string `json:"paymentMethodId,omitempty"`
	PledgeAmountCents int64  `json:"pledgeAmountCents"`
	DeadlineDate      string `json:"deadlineDate"`
	TaskTitle         string `json:"taskTitle"`
	StoredHMACSeal    string `json:"storedHmacSeal"`
}

type ForfeitResponse struct {
	Success         bool   `json:"success"`
	Status          string `json:"status"` // FORFEITED, PAYMENT_FAILED, ABORTED
	AmountCents     int64  `json:"amountCents"`
	PaymentIntentID string `json:"paymentIntentId,omitempty"`
	DeclineCode     string `json:"declineCode,omitempty"`
	IsLocked        bool   `json:"isLocked,omitempty"`
	Message         string `json:"message,omitempty"`
	Error           string `json:"error,omitempty"`
}

func HandleForfeit(store *db.Store, cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req ForfeitRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			respondJSON(w, http.StatusBadRequest, ForfeitResponse{
				Success: false,
				Error:   "Invalid JSON payload",
			})
			return
		}

		// Defense 1: Verify HMAC Seal (Database Integrity Check)
		if req.StoredHMACSeal != "" {
			if !crypto.VerifyPledgeIntegrity(req.TaskID, req.UserID, req.PledgeAmountCents, req.StoredHMACSeal, cfg.PledgeHMACSecret) {
				log.Printf("🚨 SECURITY ALERT: HMAC signature mismatch for task %s!", req.TaskID)
				respondJSON(w, http.StatusForbidden, ForfeitResponse{
					Success: false,
					Status:  "ABORTED",
					Error:   "Security Violation: Database record integrity check failed",
				})
				return
			}
		}

		// Defense 2: Hard Ceiling & Whitelist checks
		if req.PledgeAmountCents <= 0 || req.PledgeAmountCents > 10000 || !AllowedPledges[req.PledgeAmountCents] {
			respondJSON(w, http.StatusBadRequest, ForfeitResponse{
				Success: false,
				Error:   "Invalid pledge amount",
			})
			return
		}

		now := time.Now().UTC()

		// 1. Mock / Sandbox Mode
		if cfg.IsTestMode {
			mockPI := fmt.Sprintf("pi_mock_%d", now.Unix())
			eval, _ := store.GetEvaluation(req.TaskID, req.DeadlineDate)
			if eval == nil {
				eval = &db.EvaluationRecord{
					ID:           fmt.Sprintf("eval_%d", now.UnixNano()),
					TaskID:       req.TaskID,
					UserID:       req.UserID,
					DeadlineDate: req.DeadlineDate,
					AmountCents:  req.PledgeAmountCents,
					CreatedAt:    now,
				}
			}
			eval.Status = "FORFEITED"
			eval.StripePaymentIntentID = mockPI
			eval.SettledAt = &now
			store.SaveEvaluation(eval)

			respondJSON(w, http.StatusOK, ForfeitResponse{
				Success:         true,
				Status:          "FORFEITED",
				AmountCents:     req.PledgeAmountCents,
				PaymentIntentID: mockPI,
				Message:         fmt.Sprintf("Penalty of $%.2f executed and charged successfully", float64(req.PledgeAmountCents)/100.0),
			})
			return
		}

		// 2. Production Stripe Execution
		params := &stripe.PaymentIntentParams{
			Amount:      stripe.Int64(req.PledgeAmountCents),
			Currency:    stripe.String(string(stripe.CurrencyUSD)),
			Customer:    stripe.String(req.CustomerID),
			Confirm:     stripe.Bool(true),
			OffSession:  stripe.Bool(true),
			Description: stripe.String(fmt.Sprintf("Tardi Penalty: Missed deadline for %s", req.TaskTitle)),
		}
		if req.PaymentMethodID != "" {
			params.PaymentMethod = stripe.String(req.PaymentMethodID)
		}
		params.AddMetadata("taskId", req.TaskID)
		params.AddMetadata("deadlineDate", req.DeadlineDate)

		// Set Idempotency Key to prevent double charges
		params.SetIdempotencyKey(fmt.Sprintf("forfeit_%s_%s", req.TaskID, req.DeadlineDate))

		pi, err := paymentintent.New(params)
		if err != nil {
			if stripeErr, ok := err.(*stripe.Error); ok {
				if stripeErr.DeclineCode == "insufficient_funds" || stripeErr.Code == stripe.ErrorCodeCardDeclined {
					log.Printf("⚠️ Card declined for user %s: %s", req.UserID, stripeErr.DeclineCode)

					user, _ := store.GetUser(req.UserID)
					if user != nil {
						user.IsLockedForDebt = true
						user.OutstandingDebtAmount += req.PledgeAmountCents
						user.FailedTaskTitle = req.TaskTitle
						store.SaveUser(user)
					}

					respondJSON(w, http.StatusOK, ForfeitResponse{
						Success:     false,
						Status:      "PAYMENT_FAILED",
						DeclineCode: string(stripeErr.DeclineCode),
						IsLocked:    true,
						AmountCents: req.PledgeAmountCents,
						Message:     "Card declined due to insufficient funds. Account locked until settled.",
					})
					return
				}
			}

			respondJSON(w, http.StatusInternalServerError, ForfeitResponse{
				Success: false,
				Error:   fmt.Sprintf("Stripe charge failed: %v", err),
			})
			return
		}

		eval, _ := store.GetEvaluation(req.TaskID, req.DeadlineDate)
		if eval == nil {
			eval = &db.EvaluationRecord{
				ID:           fmt.Sprintf("eval_%d", now.UnixNano()),
				TaskID:       req.TaskID,
				UserID:       req.UserID,
				DeadlineDate: req.DeadlineDate,
				AmountCents:  req.PledgeAmountCents,
				CreatedAt:    now,
			}
		}
		eval.Status = "FORFEITED"
		eval.StripePaymentIntentID = pi.ID
		eval.SettledAt = &now
		store.SaveEvaluation(eval)

		respondJSON(w, http.StatusOK, ForfeitResponse{
			Success:         true,
			Status:          "FORFEITED",
			AmountCents:     pi.Amount,
			PaymentIntentID: pi.ID,
			Message:         "Penalty captured. Money charged.",
		})
	}
}
