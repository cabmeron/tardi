package handlers

import (
	"encoding/json"
	"fmt"
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
			// Create a new Stripe Customer
			custParams := &stripe.CustomerParams{
				Email: stripe.String(req.Email),
			}
			if req.UserID != "" {
				custParams.AddMetadata("userId", req.UserID)
			}
			c, err := customer.New(custParams)
			if err != nil {
				respondJSON(w, http.StatusInternalServerError, SetupIntentResponse{
					Success: false,
					Error:   fmt.Sprintf("Failed to create Stripe customer: %v", err),
				})
				return
			}
			custID = c.ID
		}

		// Create SetupIntent for saving the card / Apple Pay
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
