package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"tardi-backend/config"
	"tardi-backend/crypto"

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

func HandleForfeit(cfg *config.Config) http.HandlerFunc {
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

		// 1. Mock / Sandbox Mode
		if cfg.IsTestMode {
			mockPI := fmt.Sprintf("pi_mock_%d", time.Now().Unix())
			respondJSON(w, http.StatusOK, ForfeitResponse{
				Success:         true,
				Status:          "FORFEITED",
				AmountCents:     req.PledgeAmountCents,
				PaymentIntentID: mockPI,
				Message:         fmt.Sprintf("Mock forfeiture of $%.2f executed successfully", float64(req.PledgeAmountCents)/100.0),
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
			Description: stripe.String(fmt.Sprintf("Tardi Forfeiture: Missed deadline for %s", req.TaskTitle)),
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

		respondJSON(w, http.StatusOK, ForfeitResponse{
			Success:         true,
			Status:          "FORFEITED",
			AmountCents:     pi.Amount,
			PaymentIntentID: pi.ID,
			Message:         "Forfeiture penalty charged successfully",
		})
	}
}

type CancelPaymentIntentRequest struct {
	PaymentIntentID string `json:"paymentIntentId"`
	TaskID          string `json:"taskId,omitempty"`
	Reason          string `json:"reason,omitempty"`
}

type CancelPaymentIntentResponse struct {
	Success bool   `json:"success"`
	Status  string `json:"status"` // CANCELED
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}

// HandleCancelPaymentIntent cancels a pre-authorized PaymentIntent when the user achieves their goal (Arrives on Time!).
func HandleCancelPaymentIntent(cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req CancelPaymentIntentRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.PaymentIntentID == "" {
			respondJSON(w, http.StatusBadRequest, CancelPaymentIntentResponse{
				Success: false,
				Error:   "Missing paymentIntentId",
			})
			return
		}

		log.Printf("\n🎉 [GOAL ACHIEVED] Canceling PaymentIntent: %s", req.PaymentIntentID)

		if cfg.IsTestMode {
			respondJSON(w, http.StatusOK, CancelPaymentIntentResponse{
				Success: true,
				Status:  "CANCELED",
				Message: "PaymentIntent hold released - Goal Achieved! (Sandbox Mock)",
			})
			return
		}

		params := &stripe.PaymentIntentCancelParams{
			CancellationReason: stripe.String(string(stripe.PaymentIntentCancellationReasonAbandoned)),
		}
		pi, err := paymentintent.Cancel(req.PaymentIntentID, params)
		if err != nil {
			respondJSON(w, http.StatusInternalServerError, CancelPaymentIntentResponse{
				Success: false,
				Error:   fmt.Sprintf("Failed to cancel PaymentIntent: %v", err),
			})
			return
		}

		log.Printf("✅ [STRIPE CANCELED] PaymentIntent %s successfully canceled! Status: %s", pi.ID, pi.Status)

		respondJSON(w, http.StatusOK, CancelPaymentIntentResponse{
			Success: true,
			Status:  string(pi.Status),
			Message: "PaymentIntent hold successfully released - Commitment Met!",
		})
	}
}

type CapturePaymentIntentRequest struct {
	PaymentIntentID string `json:"paymentIntentId"`
	AmountCents     int64  `json:"amountCents,omitempty"`
}

type CapturePaymentIntentResponse struct {
	Success bool   `json:"success"`
	Status  string `json:"status"` // SUCCEEDED
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}

// HandleCapturePaymentIntent captures the pre-authorized PaymentIntent when a deadline is missed.
func HandleCapturePaymentIntent(cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req CapturePaymentIntentRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.PaymentIntentID == "" {
			respondJSON(w, http.StatusBadRequest, CapturePaymentIntentResponse{
				Success: false,
				Error:   "Missing paymentIntentId",
			})
			return
		}

		log.Printf("\n⚠️ [DEADLINE MISSED] Capturing PaymentIntent: %s", req.PaymentIntentID)

		if cfg.IsTestMode {
			respondJSON(w, http.StatusOK, CapturePaymentIntentResponse{
				Success: true,
				Status:  "SUCCEEDED",
				Message: "PaymentIntent captured - Stake forfeited (Sandbox Mock)",
			})
			return
		}

		params := &stripe.PaymentIntentCaptureParams{}
		if req.AmountCents > 0 {
			params.AmountToCapture = stripe.Int64(req.AmountCents)
		}

		pi, err := paymentintent.Capture(req.PaymentIntentID, params)
		if err != nil {
			respondJSON(w, http.StatusInternalServerError, CapturePaymentIntentResponse{
				Success: false,
				Error:   fmt.Sprintf("Failed to capture PaymentIntent: %v", err),
			})
			return
		}

		log.Printf("💳 [STRIPE CAPTURED] PaymentIntent %s captured! Status: %s", pi.ID, pi.Status)

		respondJSON(w, http.StatusOK, CapturePaymentIntentResponse{
			Success: true,
			Status:  string(pi.Status),
			Message: "PaymentIntent captured successfully due to missed commitment",
		})
	}
}
