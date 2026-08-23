package config

import (
	"log"
	"os"
)

type Config struct {
	Port             string
	StripeSecretKey  string
	PledgeHMACSecret string
	DatabaseURL      string
	IsTestMode       bool
}

func Load() *Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	stripeKey := os.Getenv("STRIPE_SECRET_KEY")
	isTestMode := false
	if stripeKey == "" {
		log.Println("⚠️  STRIPE_SECRET_KEY not set. Running in local test/mock mode.")
		isTestMode = true
	}

	hmacSecret := os.Getenv("PLEDGE_HMAC_SECRET")
	if hmacSecret == "" {
		hmacSecret = "tardi_dev_hmac_secret_key_32_bytes_long!!"
	}

	return &Config{
		Port:             port,
		StripeSecretKey:  stripeKey,
		PledgeHMACSecret: hmacSecret,
		DatabaseURL:      os.Getenv("DATABASE_URL"),
		IsTestMode:       isTestMode,
	}
}
