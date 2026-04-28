package middleware

import (
	"context"
	"event-map/internal/auth"
	"net/http"
	"strings"

	"github.com/google/uuid"
)

type contextKey string

const userIDKey contextKey = "user_id"

// GetUserID извлекает user_id из контекста запроса.
func GetUserID(r *http.Request) (uuid.UUID, bool) {
	val, ok := r.Context().Value(userIDKey).(uuid.UUID)
	if !ok || val == uuid.Nil {
		return uuid.UUID{}, false
	}
	return val, true
}

func AuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if !strings.HasPrefix(authHeader, "Bearer ") {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		userID, err := auth.ParseAccessToken(tokenString)
		if err != nil {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), userIDKey, userID)
		next(w, r.WithContext(ctx))
	}
}
