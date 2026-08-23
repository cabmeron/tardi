package worker

import (
	"fmt"
	"log"
	"time"

	"tardi-backend/config"
	"tardi-backend/db"

	"github.com/stripe/stripe-go/v78"
	"github.com/stripe/stripe-go/v78/paymentintent"
)

// StartDeadlineWorker continuously audits deadlines with ZERO grace period
func StartDeadlineWorker(store *db.Store, cfg *config.Config) {
	ticker := time.NewTicker(5 * time.Second) // Audits every 5 seconds for instant enforcement

	go func() {
		log.Println("⚡ Strict Real-Time Deadline Worker started (Zero Grace Period)")
		for range ticker.C {
			AuditAndEnforceDeadlines(store, cfg)
		}
	}()
}

// AuditAndEnforceDeadlines scans for any pending task whose deadline has passed
func AuditAndEnforceDeadlines(store *db.Store, cfg *config.Config) {
	// Zero grace period: the exact second t > deadlineUTC, penalty executes!
	expiredEvaluations := store.FindExpiredPendingEvaluations(0 * time.Second)

	for _, eval := range expiredEvaluations {
		task, ok := store.GetTask(eval.TaskID)
		if !ok {
			continue
		}

		user, _ := store.GetUser(eval.UserID)
		stripeCustID := ""
		if user != nil {
			stripeCustID = user.StripeCustomerID
		}
		if stripeCustID == "" {
			stripeCustID = fmt.Sprintf("cus_default_%s", eval.UserID)
		}

		// 1. Instantly lock evaluation to PROCESSING
		eval.Status = "PROCESSING"
		store.SaveEvaluation(eval)

		log.Printf("🚨 DEADLINE BREACHED: Task '%s' ($%.2f Stake) missed by user %s! Executing penalty charge...",
			task.TaskTitle, float64(eval.AmountCents)/100.0, eval.UserID)

		// 2. Mock / Sandbox Execution
		if cfg.IsTestMode {
			mockPI := fmt.Sprintf("pi_strict_%d", time.Now().UnixNano())
			now := time.Now().UTC()
			eval.Status = "FORFEITED"
			eval.StripePaymentIntentID = mockPI
			eval.SettledAt = &now
			store.SaveEvaluation(eval)

			log.Printf("💸 PENALTY COLLECTED: $%.2f charged to %s (PaymentIntent: %s)",
				float64(eval.AmountCents)/100.0, stripeCustID, mockPI)
			continue
		}

		// 3. Live Stripe Off-Session Execution
		params := &stripe.PaymentIntentParams{
			Amount:      stripe.Int64(eval.AmountCents),
			Currency:    stripe.String(string(stripe.CurrencyUSD)),
			Customer:    stripe.String(stripeCustID),
			Confirm:     stripe.Bool(true),
			OffSession:  stripe.Bool(true),
			Description: stripe.String(fmt.Sprintf("Tardi Penalty: Missed deadline for %s", task.TaskTitle)),
		}
		params.SetIdempotencyKey(fmt.Sprintf("forfeit_%s_%s", eval.TaskID, eval.DeadlineDate))

		pi, err := paymentintent.New(params)
		now := time.Now().UTC()

		if err != nil {
			log.Printf("⚠️ Penalty charge failed for user %s: %v", eval.UserID, err)
			eval.Status = "PAYMENT_FAILED"
			eval.DeclineCode = err.Error()
			eval.SettledAt = &now
			store.SaveEvaluation(eval)

			// Lock account for debt
			if user != nil {
				user.IsLockedForDebt = true
				user.OutstandingDebtAmount += eval.AmountCents
				user.FailedTaskTitle = task.TaskTitle
				store.SaveUser(user)
			}
			continue
		}

		// Success: Forfeited and charged
		eval.Status = "FORFEITED"
		eval.StripePaymentIntentID = pi.ID
		eval.SettledAt = &now
		store.SaveEvaluation(eval)

		log.Printf("💸 PENALTY SETTLED: $%.2f captured via Stripe (%s)", float64(eval.AmountCents)/100.0, pi.ID)
	}
}
