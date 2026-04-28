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

	AccessTTL  = 15 * time.Minute
	RefreshTTL = 7 * 24 * time.Hour
)

// ErrInvalidToken — общая ошибка для невалидных/протухших токенов.
var ErrInvalidToken = errors.New("invalid token")

var (
	secretOnce   sync.Once
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

// RefreshClaims — данные, которые мы достаём из refresh-токена для rotation.
type RefreshClaims struct {
	UserID   uuid.UUID
	JTI      uuid.UUID // ID самого токена (для проверки в БД)
	FamilyID uuid.UUID // ID цепочки — все токены одного login имеют одинаковый
}

// GenerateAccessToken — короткоживущий токен для запросов.
// Не записывается в БД, валидируется только подписью.
func GenerateAccessToken(userID uuid.UUID) (string, error) {
	claims := jwt.MapClaims{
		"user_id": userID.String(),
		"type":    TokenTypeAccess,
		"exp":     time.Now().Add(AccessTTL).Unix(),
		"iat":     time.Now().Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(Secret())
}

// GenerateRefreshToken — долгоживущий токен.
// jti и family_id используются для rotation/reuse-detection через таблицу refresh_tokens.
func GenerateRefreshToken(userID, jti, familyID uuid.UUID) (string, time.Time, error) {
	expiresAt := time.Now().Add(RefreshTTL)
	claims := jwt.MapClaims{
		"user_id":   userID.String(),
		"type":      TokenTypeRefresh,
		"jti":       jti.String(),
		"family_id": familyID.String(),
		"exp":       expiresAt.Unix(),
		"iat":       time.Now().Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(Secret())
	return signed, expiresAt, err
}

// ParseAccessToken — проверяет подпись/алгоритм и возвращает user_id.
// Доступ валидируется только криптографически — БД не дёргаем (для скорости).
func ParseAccessToken(tokenString string) (uuid.UUID, error) {
	claims, err := parseClaims(tokenString)
	if err != nil {
		return uuid.Nil, err
	}
	if t, _ := claims["type"].(string); t != TokenTypeAccess {
		return uuid.Nil, ErrInvalidToken
	}
	return parseUUIDClaim(claims, "user_id")
}

// ParseRefreshToken — проверяет подпись/алгоритм и возвращает claims для проверки в БД.
// Полная валидация (revoked, used, expires) делается на уровне репозитория.
func ParseRefreshToken(tokenString string) (RefreshClaims, error) {
	claims, err := parseClaims(tokenString)
	if err != nil {
		return RefreshClaims{}, err
	}
	if t, _ := claims["type"].(string); t != TokenTypeRefresh {
		return RefreshClaims{}, ErrInvalidToken
	}

	userID, err := parseUUIDClaim(claims, "user_id")
	if err != nil {
		return RefreshClaims{}, err
	}
	jti, err := parseUUIDClaim(claims, "jti")
	if err != nil {
		return RefreshClaims{}, err
	}
	familyID, err := parseUUIDClaim(claims, "family_id")
	if err != nil {
		return RefreshClaims{}, err
	}
	return RefreshClaims{UserID: userID, JTI: jti, FamilyID: familyID}, nil
}

// parseClaims — общая часть: проверка алгоритма (защита от alg=none / RSA confusion).
func parseClaims(tokenString string) (jwt.MapClaims, error) {
	token, err := jwt.Parse(tokenString, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return Secret(), nil
	})
	if err != nil || !token.Valid {
		return nil, ErrInvalidToken
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, ErrInvalidToken
	}
	return claims, nil
}

func parseUUIDClaim(claims jwt.MapClaims, key string) (uuid.UUID, error) {
	s, _ := claims[key].(string)
	id, err := uuid.Parse(s)
	if err != nil {
		return uuid.Nil, ErrInvalidToken
	}
	return id, nil
}
