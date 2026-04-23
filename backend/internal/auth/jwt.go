package auth

import (
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

var secretKey = os.Getenv("JWT_SECRET")

func GenerateAccessToken(UserID uuid.UUID) (string, error) {

	expiresAt := time.Now().Add(15 * time.Minute).Unix()

	claims := jwt.MapClaims{
		"user_id": UserID,
		"exp":     expiresAt,
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	return token.SignedString([]byte(secretKey))

}

func GenerateRefreshToken(UserID uuid.UUID) (string, error) {

	expiresAt := time.Now().Add(12 * time.Hour).Unix()

	claims := jwt.MapClaims{
		"user_id": UserID,
		"exp":     expiresAt,
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	return token.SignedString([]byte(secretKey))
}
