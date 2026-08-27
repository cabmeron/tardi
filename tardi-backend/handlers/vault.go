package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"tardi-backend/config"
	"tardi-backend/db"

	"github.com/stripe/stripe-go/v78"
	"github.com/stripe/stripe-go/v78/customer"
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

func HandleCreateSetupIntent(store *db.Store, cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req SetupIntentRequest
		if r.Body != nil {
			_ = json.NewDecoder(r.Body).Decode(&req)
		}

		userID := req.UserID
		if userID == "" {
			userID = "user_default"
		}

		log.Printf("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		log.Printf("📥 [VAULT REQUEST] Incoming POST /api/v1/vault/setup-intent")
		log.Printf("   • Email:      %q", req.Email)
		log.Printf("   • UserID:     %q", userID)
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

			// Save to store
			store.SaveUser(&db.UserRecord{
				ID:               userID,
				Email:            req.Email,
				StripeCustomerID: mockCustID,
			})

			log.Printf("⚠️  [STRIPE NOTICE] STRIPE_SECRET_KEY is not set. Generating mock IDs.")
			log.Printf("   • Mock Customer:    %s", mockCustID)
			log.Printf("   • Mock SetupIntent: %s", mockClientSecret)
			log.Printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

			respondJSON(w, http.StatusOK, SetupIntentResponse{
				Success:      true,
				ClientSecret: mockClientSecret,
				CustomerID:   mockCustID,
				Message:      "SetupIntent generated successfully (Sandbox Test Mode)",
			})
			return
		}

		// 2. Production Stripe Execution
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
			if userID != "" {
				custParams.AddMetadata("userId", userID)
			}

			c, err := customer.New(custParams)
			if err != nil {
				log.Printf("❌ [STRIPE ERROR] Failed to create customer in Stripe: %v", err)
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
		if userID != "" {
			siParams.AddMetadata("userId", userID)
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

		// Save to store
		store.SaveUser(&db.UserRecord{
			ID:               userID,
			Email:            req.Email,
			StripeCustomerID: custID,
		})

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

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}
