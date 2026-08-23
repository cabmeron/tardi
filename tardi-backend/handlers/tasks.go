package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"tardi-backend/config"
	"tardi-backend/crypto"
	"tardi-backend/db"
)

type SealTaskRequest struct {
	TaskID                 string `json:"taskId"`
	UserID                 string `json:"userId"`
	LocationName           string `json:"locationName"`
	TaskTitle              string `json:"taskTitle"`
	PledgeAmountCents      int64  `json:"pledgeAmountCents"`
	DeadlineUTC            string `json:"deadlineUtc,omitempty"`
	PublicKeyBase64        string `json:"publicKeyBase64,omitempty"`
	SecureEnclaveSignature string `json:"secureEnclaveSignature,omitempty"`
}

type SealTaskResponse struct {
	Success           bool   `json:"success"`
	TaskID            string `json:"taskId"`
	PledgeAmountCents int64  `json:"pledgeAmountCents"`
	HMACSeal          string `json:"hmacSeal"`
	Status            string `json:"status"`
	Message           string `json:"message,omitempty"`
	Error             string `json:"error,omitempty"`
}

// Allowed discrete stake tiers
var AllowedPledges = map[int64]bool{
	0:     true, // Free / Casual
	500:   true, // $5.00
	1000:  true, // $10.00 (Popular)
	2500:  true, // $25.00
	5000:  true, // $50.00
	10000: true, // $100.00 (Hard Max)
}

func HandleSealTask(store *db.Store, cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req SealTaskRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			respondJSON(w, http.StatusBadRequest, SealTaskResponse{
				Success: false,
				Error:   "Invalid JSON payload",
			})
			return
		}

		if req.TaskID == "" {
			respondJSON(w, http.StatusBadRequest, SealTaskResponse{
				Success: false,
				Error:   "Missing taskId",
			})
			return
		}

		// Defense 1: Hard Ceiling check
		if req.PledgeAmountCents > 10000 {
			respondJSON(w, http.StatusBadRequest, SealTaskResponse{
				Success: false,
				Error:   "Security Violation: Pledge amount exceeds hard maximum ceiling of $100.00",
			})
			return
		}

		// Defense 2: Allowed Whitelist check
		if !AllowedPledges[req.PledgeAmountCents] {
			respondJSON(w, http.StatusBadRequest, SealTaskResponse{
				Success: false,
				Error:   fmt.Sprintf("Invalid pledge tier %d. Must be one of [$0, $5, $10, $25, $50, $100]", req.PledgeAmountCents),
			})
			return
		}

		// Defense 3: Apple Secure Enclave Signature Check (If client provided hardware signature)
		if req.SecureEnclaveSignature != "" && req.PublicKeyBase64 != "" {
			valid, err := crypto.VerifyAppleSecureEnclaveSignature(
				req.PublicKeyBase64,
				req.TaskID,
				req.PledgeAmountCents,
				req.DeadlineUTC,
				req.SecureEnclaveSignature,
			)
			if err != nil || !valid {
				respondJSON(w, http.StatusForbidden, SealTaskResponse{
					Success: false,
					Error:   "Apple Secure Enclave hardware signature verification failed",
				})
				return
			}
		}

		// Defense 4: Compute Server-Side HMAC Seal
		seal := crypto.GeneratePledgeSeal(req.TaskID, req.UserID, req.PledgeAmountCents, cfg.PledgeHMACSecret)

		now := time.Now().UTC()
		// Save task in store
		store.SaveTask(&db.TaskRecord{
			ID:                req.TaskID,
			UserID:            req.UserID,
			LocationName:      req.LocationName,
			TaskTitle:         req.TaskTitle,
			PledgeAmountCents: req.PledgeAmountCents,
			HMACSeal:          seal,
			IsActive:          true,
			CreatedAt:         now,
		})

		// If a deadline timestamp was provided, schedule the evaluation slot
		if req.DeadlineUTC != "" {
			if parsedDeadline, err := time.Parse(time.RFC3339, req.DeadlineUTC); err == nil {
				store.SaveEvaluation(&db.EvaluationRecord{
					ID:           fmt.Sprintf("eval_%d", now.UnixNano()),
					TaskID:       req.TaskID,
					UserID:       req.UserID,
					DeadlineDate: parsedDeadline.Format("2006-01-02"),
					DeadlineUTC:  parsedDeadline,
					Status:       "PENDING",
					AmountCents:  req.PledgeAmountCents,
					CreatedAt:    now,
				})
			}
		}

		respondJSON(w, http.StatusOK, SealTaskResponse{
			Success:           true,
			TaskID:            req.TaskID,
			PledgeAmountCents: req.PledgeAmountCents,
			HMACSeal:          seal,
			Status:            "ARMED",
			Message:           "Task cryptographically sealed and armed successfully",
		})
	}
}
