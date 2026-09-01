package main

import (
	"fmt"
	"log"
	"net/http"

	"tardi-backend/config"
	"tardi-backend/handlers"
	"tardi-backend/middleware"
	"tardi-backend/scheduler"

	"github.com/stripe/stripe-go/v78"
)

func main() {
	cfg := config.Load()

	// Initialize Stripe API Key if provided
	if cfg.StripeSecretKey != "" {
		stripe.Key = cfg.StripeSecretKey
		log.Println("💳 Stripe SDK initialized in Live/Test mode")
	} else {
		log.Println("🧪 Running in Sandbox Simulation mode (No Stripe key required)")
	}

	// Initialize and start the Redis Deadline Scheduler Service
	sched := scheduler.NewService(cfg)
	sched.Start()
	defer sched.Stop()

	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"healthy","service":"tardi-backend","version":"1.0.0"}`))
	})

	// Scheduler Health & Status Endpoints
	mux.HandleFunc("GET /api/v1/scheduler/health", handlers.HandleSchedulerHealth(sched))
	mux.HandleFunc("GET /api/v1/scheduler/status", handlers.HandleSchedulerStatus(sched))
	mux.HandleFunc("POST /api/v1/scheduler/schedule", handlers.HandleScheduleTask(sched))
	mux.HandleFunc("POST /api/v1/scheduler/cancel", handlers.HandleCancelTask(sched))

	// API v1 Routes
	mux.HandleFunc("POST /api/v1/vault/setup-intent", handlers.HandleCreateSetupIntent(cfg))
	mux.HandleFunc("POST /api/v1/vault/create-payment-intent", handlers.HandleCreatePreAuthPaymentIntent(cfg))
	mux.HandleFunc("POST /api/v1/vault/cancel-payment-intent", handlers.HandleCancelPaymentIntent(cfg))
	mux.HandleFunc("POST /api/v1/vault/capture-payment-intent", handlers.HandleCapturePaymentIntent(cfg))
	mux.HandleFunc("POST /api/v1/tasks/seal", handlers.HandleSealTask(cfg))
	mux.HandleFunc("POST /api/v1/evaluations/forfeit", handlers.HandleForfeit(cfg))
	mux.HandleFunc("GET /api/v1/user/account-status", handlers.HandleAccountStatus(cfg))
	mux.HandleFunc("POST /api/v1/user/settle-debt", handlers.HandleSettleDebt(cfg))

	// Apply Middlewares
	handler := middleware.CORS(middleware.Logger(mux))

	fmt.Printf("\n🚀 Tardi Go Backend running on http://localhost:%s\n", cfg.Port)
	fmt.Printf("📦 Main Health endpoint:      http://localhost:%s/health\n", cfg.Port)
	fmt.Printf("⏱️ Scheduler Status endpoint: http://localhost:%s/api/v1/scheduler/status\n\n", cfg.Port)

	log.Fatal(http.ListenAndServe(":"+cfg.Port, handler))
}
