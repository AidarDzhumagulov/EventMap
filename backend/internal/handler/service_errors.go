package handler

import (
	"errors"
	"event-map/internal/service"
	"log/slog"
	"net/http"
)

// writeServiceError маппит доменные ошибки service-слоя на HTTP-ответы.
// Это единственное место где знают про HTTP-коды для service-ошибок —
// service слой остаётся без HTTP-зависимостей.
func writeServiceError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, service.ErrInvalidInput):
		http.Error(w, err.Error(), http.StatusBadRequest)

	case errors.Is(err, service.ErrEmailTaken):
		http.Error(w, "Email already exist", http.StatusBadRequest)

	case errors.Is(err, service.ErrUsernameTaken):
		http.Error(w, "Username already exist", http.StatusBadRequest)

	case errors.Is(err, service.ErrInvalidCredentials):
		http.Error(w, "Неверный email или пароль", http.StatusUnauthorized)

	case errors.Is(err, service.ErrInvalidToken):
		http.Error(w, "Invalid or expired token", http.StatusUnauthorized)

	case errors.Is(err, service.ErrTokenReuseDetected):
		// Кастомный header → клиент покажет специальный месседж юзеру.
		w.Header().Set("X-Auth-Error", "token_reuse")
		http.Error(w, "Token reuse detected, please login again", http.StatusUnauthorized)

	default:
		// Это уже неожиданная ошибка — service её не предусматривает.
		slog.Error("unhandled service error", "err", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}
