package main

import (
	"fmt"
	"log"
	"net/http"

	"tardi-backend/config"
	"tardi-backend/db"
	"tardi-backend/handlers"
	"tardi-backend/middleware"
	"tardi-backend/worker"

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

	mux := http.NewServeMux()

	// Initialize In-Memory Store & Background Worker
	store := db.NewStore()
	worker.StartDeadlineWorker(store, cfg)

	// Health check
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"healthy","service":"tardi-backend","version":"1.0.0"}`))
	})

	// API v1 Routes
	mux.HandleFunc("POST /api/v1/vault/setup-intent", handlers.HandleCreateSetupIntent(store, cfg))
	mux.HandleFunc("POST /api/v1/tasks/seal", handlers.HandleSealTask(store, cfg))
	mux.HandleFunc("POST /api/v1/evaluations/forfeit", handlers.HandleForfeit(store, cfg))
	mux.HandleFunc("GET /api/v1/user/account-status", handlers.HandleAccountStatus(store, cfg))
	mux.HandleFunc("POST /api/v1/user/settle-debt", handlers.HandleSettleDebt(store, cfg))

	// Apply Middlewares
	handler := middleware.CORS(middleware.Logger(mux))

	fmt.Printf("\n🚀 Tardi Go Backend running on http://localhost:%s\n", cfg.Port)
	fmt.Printf("📦 Health endpoint: http://localhost:%s/health\n\n", cfg.Port)

	log.Fatal(http.ListenAndServe(":"+cfg.Port, handler))
}
