package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"tardi-backend/config"

	"github.com/stripe/stripe-go/v78"
	"github.com/stripe/stripe-go/v78/customer"
	"github.com/stripe/stripe-go/v78/paymentintent"
	"github.com/stripe/stripe-go/v78/setupintent"
)

type SetupIntentRequest struct {
	CustomerID string `json:"customerId,omitempty"`
	Email      string `json:"email,omitempty"`
	UserID     string `json:"userId,omitempty"`
}

type SetupIntentResponse struct {
	Success      bool   `json:"success"`
	ClientSecret string `json:"clientSecret"`
	CustomerID   string `json:"customerId"`
	Message      string `json:"message,omitempty"`
	Error        string `json:"error,omitempty"`
}

func HandleCreateSetupIntent(cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req SetupIntentRequest
		if r.Body != nil {
			_ = json.NewDecoder(r.Body).Decode(&req)
		}

		log.Printf("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		log.Printf("📥 [VAULT REQUEST] Incoming POST /api/v1/vault/setup-intent")
		log.Printf("   • Email:      %q", req.Email)
		log.Printf("   • UserID:     %q", req.UserID)
		log.Printf("   • CustomerID: %q", req.CustomerID)
		log.Printf("   • Mode:       %s", func() string {
			if cfg.IsTestMode {
				return "🧪 SANDBOX SIMULATION (Local Mock)"
			}
			return "💳 LIVE STRIPE API (Test/Live Network)"
		}())

		// 1. Mock / Local Sandbox Mode (If no live STRIPE_SECRET_KEY is set)
		if cfg.IsTestMode {
			mockCustID := req.CustomerID
			if mockCustID == "" {
				mockCustID = fmt.Sprintf("cus_mock_%d", time.Now().Unix())
			}
			mockClientSecret := fmt.Sprintf("seti_mock_%d_secret_%d", time.Now().Unix(), time.Now().UnixNano())

			log.Printf("⚠️  [STRIPE NOTICE] STRIPE_SECRET_KEY is not set. Generating mock IDs.")
			log.Printf("   • Mock Customer:    %s", mockCustID)
			log.Printf("   • Mock SetupIntent: %s", mockClientSecret)
			log.Printf("   👉 To see real entries in your Stripe Dashboard, provide STRIPE_SECRET_KEY=sk_test_...")
			log.Printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

			respondJSON(w, http.StatusOK, SetupIntentResponse{
				Success:      true,
				ClientSecret: mockClientSecret,
				CustomerID:   mockCustID,
				Message:      "SetupIntent generated successfully (Sandbox Test Mode)",
			})
			return
		}

		// 2. Production / Live Stripe Execution
		custID := req.CustomerID
		if custID == "" {
			email := req.Email
			if email == "" {
				email = "user@tardi.app"
			}

			log.Printf("🔄 [STRIPE API] Calling customer.New(Email: %q)...", email)
			custParams := &stripe.CustomerParams{
				Email: stripe.String(email),
			}
			custParams.AddMetadata("created_by", "tardi-backend")
			custParams.AddMetadata("app", "Tardi Habit Tracker")
			if req.UserID != "" {
				custParams.AddMetadata("userId", req.UserID)
			}

			c, err := customer.New(custParams)
			if err != nil {
				log.Printf("❌ [STRIPE ERROR] Failed to create customer in Stripe: %v", err)
				log.Printf("   👉 Check that your STRIPE_SECRET_KEY starts with 'sk_test_' and is valid.")
				log.Printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
				respondJSON(w, http.StatusInternalServerError, SetupIntentResponse{
					Success: false,
					Error:   fmt.Sprintf("Failed to create Stripe customer: %v", err),
				})
				return
			}
			custID = c.ID
			log.Printf("✅ [STRIPE SUCCESS] Real Customer Created in Stripe!")
			log.Printf("   • Customer ID: %s", custID)
			log.Printf("   • Email:       %s", c.Email)
			log.Printf("   • Live Link:   https://dashboard.stripe.com/test/customers/%s", custID)
		} else {
			log.Printf("ℹ️  [STRIPE] Reusing existing Customer ID: %s", custID)
		}

		// Create SetupIntent for saving the card / Apple Pay
		log.Printf("🔄 [STRIPE API] Calling setupintent.New(Customer: %s)...", custID)
		siParams := &stripe.SetupIntentParams{
			Customer:           stripe.String(custID),
			PaymentMethodTypes: stripe.StringSlice([]string{"card"}),
		}
		siParams.AddMetadata("created_by", "tardi-backend")
		if req.UserID != "" {
			siParams.AddMetadata("userId", req.UserID)
		}

		si, err := setupintent.New(siParams)
		if err != nil {
			log.Printf("❌ [STRIPE ERROR] Failed to create SetupIntent: %v", err)
			log.Printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
			respondJSON(w, http.StatusInternalServerError, SetupIntentResponse{
				Success: false,
				Error:   fmt.Sprintf("Failed to create SetupIntent: %v", err),
			})
			return
		}

		log.Printf("✅ [STRIPE SUCCESS] Real SetupIntent Created in Stripe!")
		log.Printf("   • SetupIntent ID: %s", si.ID)
		log.Printf("   • Status:         %s", si.Status)
		log.Printf("   • Client Secret:  %s... (truncated)", func() string {
			if len(si.ClientSecret) > 15 {
				return si.ClientSecret[:15]
			}
			return si.ClientSecret
		}())
		log.Printf("   • Live Link:      https://dashboard.stripe.com/test/logs")
		log.Printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

		respondJSON(w, http.StatusOK, SetupIntentResponse{
			Success:      true,
			ClientSecret: si.ClientSecret,
			CustomerID:   custID,
			Message:      "SetupIntent created successfully",
		})
	}
}

type CreatePaymentIntentRequest struct {
	CustomerID        string `json:"customerId,omitempty"`
	Email             string `json:"email,omitempty"`
	UserID            string `json:"userId,omitempty"`
	TaskID            string `json:"taskId,omitempty"`
	TaskTitle         string `json:"taskTitle,omitempty"`
	PledgeAmountCents int64  `json:"pledgeAmountCents"`
}

type CreatePaymentIntentResponse struct {
	Success         bool   `json:"success"`
	ClientSecret    string `json:"clientSecret"`
	CustomerID      string `json:"customerId"`
	PaymentIntentID string `json:"paymentIntentId"`
	Status          string `json:"status"` // requires_capture, requires_payment_method
	Message         string `json:"message,omitempty"`
	Error           string `json:"error,omitempty"`
}

// HandleCreatePreAuthPaymentIntent creates an upfront PaymentIntent with manual capture (Authorization Hold).
// The user's goal is to arrive on time to CANCEL this PaymentIntent before the deadline!
func HandleCreatePreAuthPaymentIntent(cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req CreatePaymentIntentRequest
		if r.Body != nil {
			_ = json.NewDecoder(r.Body).Decode(&req)
		}

		log.Printf("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		log.Printf("📥 [PRE-AUTH INTENT] Incoming POST /api/v1/vault/create-payment-intent")
		log.Printf("   • TaskTitle: %q", req.TaskTitle)
		log.Printf("   • Amount:    $%.2f (%d cents)", float64(req.PledgeAmountCents)/100.0, req.PledgeAmountCents)
		log.Printf("   • Mode:      Manual Capture (Pre-Authorization)")

		// Fallback amount check
		if req.PledgeAmountCents <= 0 {
			req.PledgeAmountCents = 1000 // default $10
		}

		if cfg.IsTestMode {
			mockCustID := req.CustomerID
			if mockCustID == "" {
				mockCustID = fmt.Sprintf("cus_mock_%d", time.Now().Unix())
			}
			mockPI := fmt.Sprintf("pi_preauth_mock_%d", time.Now().Unix())
			mockClientSecret := fmt.Sprintf("%s_secret_%d", mockPI, time.Now().UnixNano())

			log.Printf("⚠️ [SANDBOX PRE-AUTH] Generated Mock PaymentIntent: %s", mockPI)
			log.Printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

			respondJSON(w, http.StatusOK, CreatePaymentIntentResponse{
				Success:         true,
				ClientSecret:    mockClientSecret,
				CustomerID:      mockCustID,
				PaymentIntentID: mockPI,
				Status:          "requires_capture",
				Message:         "Pre-Auth PaymentIntent generated (Manual Capture)",
			})
			return
		}

		// Live Stripe Mode
		custID := req.CustomerID
		if custID == "" {
			email := req.Email
			if email == "" {
				email = "user@tardi.app"
			}
			custParams := &stripe.CustomerParams{Email: stripe.String(email)}
			c, err := customer.New(custParams)
			if err != nil {
				respondJSON(w, http.StatusInternalServerError, CreatePaymentIntentResponse{
					Success: false,
					Error:   fmt.Sprintf("Failed to create Stripe customer: %v", err),
				})
				return
			}
			custID = c.ID
		}

		// Create PaymentIntent with CaptureMethod = 'manual' (Authorization Hold)
		// Reuses the customer's vaulted payment method saved during the initial SetupIntent!
		piParams := &stripe.PaymentIntentParams{
			Amount:             stripe.Int64(req.PledgeAmountCents),
			Currency:           stripe.String(string(stripe.CurrencyUSD)),
			Customer:           stripe.String(custID),
			CaptureMethod:      stripe.String(string(stripe.PaymentIntentCaptureMethodManual)),
			PaymentMethodTypes: stripe.StringSlice([]string{"card"}),
			Description:        stripe.String(fmt.Sprintf("Tardi Commitment Stake: %s", req.TaskTitle)),
		}
		if req.TaskID != "" {
			piParams.AddMetadata("taskId", req.TaskID)
		}
		if req.UserID != "" {
			piParams.AddMetadata("userId", req.UserID)
		}

		pi, err := paymentintent.New(piParams)
		if err != nil {
			respondJSON(w, http.StatusInternalServerError, CreatePaymentIntentResponse{
				Success: false,
				Error:   fmt.Sprintf("Failed to create Pre-Auth PaymentIntent: %v", err),
			})
			return
		}

		log.Printf("✅ [STRIPE PRE-AUTH] Created PaymentIntent ID: %s (Status: %s)", pi.ID, pi.Status)
		log.Printf("   • Reused Customer ID: %s (Vaulted Card on File)", custID)
		log.Printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
		log.Printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

		respondJSON(w, http.StatusOK, CreatePaymentIntentResponse{
			Success:         true,
			ClientSecret:    pi.ClientSecret,
			CustomerID:      custID,
			PaymentIntentID: pi.ID,
			Status:          string(pi.Status),
			Message:         "PaymentIntent created with manual capture hold",
		})
	}
}

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}
