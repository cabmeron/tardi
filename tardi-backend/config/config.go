package config

import (
	"bufio"
	"log"
	"os"
	"strings"
)

type Config struct {
	Port             string
	StripeSecretKey  string
	PledgeHMACSecret string
	DatabaseURL      string
	IsTestMode       bool
}

// loadEnvFile automatically parses .env file if present
func loadEnvFile(filenames ...string) {
	for _, filename := range filenames {
		file, err := os.Open(filename)
		if err != nil {
			continue
		}
		defer file.Close()

		log.Printf("📄 Loaded environment variables from %s", filename)
		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}

			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				key := strings.TrimSpace(parts[0])
				val := strings.TrimSpace(parts[1])
				val = strings.Trim(val, `"'`)
				if os.Getenv(key) == "" {
					os.Setenv(key, val)
				}
			}
		}
	}
}

func Load() *Config {
	loadEnvFile(".env", "../.env")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	stripeKey := os.Getenv("STRIPE_SECRET_KEY")
	isTestMode := false
	if stripeKey == "" {
		log.Println("⚠️  STRIPE_SECRET_KEY not set. Running in local test/mock mode.")
		isTestMode = true
	} else {
		masked := stripeKey
		if len(stripeKey) > 12 {
			masked = stripeKey[:7] + "..." + stripeKey[len(stripeKey)-4:]
		}
		log.Printf("🔑 STRIPE_SECRET_KEY detected: %s (length: %d chars)", masked, len(stripeKey))
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
