package middleware

import (
	"context"
	"net/http"
	"os"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type contextKey string

const userIDKey contextKey = "user_id"

// GetUserID извлекает user_id из контекста запроса
func GetUserID(r *http.Request) (uuid.UUID, bool) {
	val := r.Context().Value(userIDKey)
	if val == nil {
		return uuid.UUID{}, false
	}
	str, ok := val.(string)
	if !ok {
		return uuid.UUID{}, false
	}
	id, err := uuid.Parse(str)
	if err != nil {
		return uuid.UUID{}, false
	}
	return id, true
}

func AuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")

		secret := []byte(os.Getenv("JWT_SECRET"))
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			return secret, nil
		})

		if err != nil || !token.Valid {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)

		if !ok {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		userID := claims["user_id"]

		ctx := context.WithValue(r.Context(), userIDKey, userID)
		r = r.WithContext(ctx)
		next(w, r)
	}
}
