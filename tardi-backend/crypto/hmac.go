package crypto

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
)

// GeneratePledgeSeal computes a cryptographic HMAC-SHA256 signature for a pledged task
func GeneratePledgeSeal(taskID string, userID string, amountCents int64, secretKey string) string {
	mac := hmac.New(sha256.New, []byte(secretKey))
	payload := fmt.Sprintf("taskId:%s|userId:%s|amountCents:%d", taskID, userID, amountCents)
	mac.Write([]byte(payload))
	return hex.EncodeToString(mac.Sum(nil))
}

// VerifyPledgeIntegrity verifies that the stored database seal has not been tampered with
func VerifyPledgeIntegrity(taskID string, userID string, amountCents int64, storedSeal string, secretKey string) bool {
	expectedSeal := GeneratePledgeSeal(taskID, userID, amountCents, secretKey)
	return hmac.Equal([]byte(expectedSeal), []byte(storedSeal))
}
