package auth

import (
	"errors"
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

const (
	TokenTypeAccess  = "access"
	TokenTypeRefresh = "refresh"

	accessTTL  = 15 * time.Minute
	refreshTTL = 7 * 24 * time.Hour
)

// ErrInvalidToken — общая ошибка для невалидных/протухших токенов.
var ErrInvalidToken = errors.New("invalid token")

var (
	secretOnce  sync.Once
	cachedSecret []byte
)

// Secret возвращает JWT-секрет — читается один раз при старте, валидируется,
// кешируется. Падаем при пустом или коротком секрете — это критическая
// уязвимость (любой сможет подделать токен).
func Secret() []byte {
	secretOnce.Do(func() {
		s := os.Getenv("JWT_SECRET")
		if len(s) < 32 {
			log.Fatalln("FATAL: JWT_SECRET must be at least 32 bytes (got", len(s), ")")
		}
		cachedSecret = []byte(s)
	})
	return cachedSecret
}

// MustInit — вызывается из main() чтобы упасть на старте, а не при первом запросе.
func MustInit() { _ = Secret() }

// generateToken — общий генератор для access/refresh.
func generateToken(userID uuid.UUID, tokenType string, ttl time.Duration) (string, error) {
	claims := jwt.MapClaims{
		"user_id": userID.String(),
		"type":    tokenType,
		"exp":     time.Now().Add(ttl).Unix(),
		"iat":     time.Now().Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(Secret())
}

func GenerateAccessToken(userID uuid.UUID) (string, error) {
	return generateToken(userID, TokenTypeAccess, accessTTL)
}

func GenerateRefreshToken(userID uuid.UUID) (string, error) {
	return generateToken(userID, TokenTypeRefresh, refreshTTL)
}

// ParseToken проверяет подпись, алгоритм и тип токена.
// Защищает от alg=none и HMAC↔RSA confusion атак.
func ParseToken(tokenString, expectedType string) (uuid.UUID, error) {
	token, err := jwt.Parse(tokenString, func(t *jwt.Token) (any, error) {
		// Критично: проверяем что используется именно HMAC, а не RSA/none.
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return Secret(), nil
	})
	if err != nil || !token.Valid {
		return uuid.Nil, ErrInvalidToken
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return uuid.Nil, ErrInvalidToken
	}

	// Проверка типа: refresh нельзя использовать как access и наоборот.
	tokenType, _ := claims["type"].(string)
	if tokenType != expectedType {
		return uuid.Nil, ErrInvalidToken
	}

	userIDStr, _ := claims["user_id"].(string)
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return uuid.Nil, ErrInvalidToken
	}
	return userID, nil
}
