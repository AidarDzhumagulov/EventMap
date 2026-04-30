package handler

import (
	"encoding/json"
	"event-map/internal/middleware"
	"event-map/internal/service"
	"net/http"
)

type EmailVerificationHandler struct {
	auth *service.AuthService
}

func NewEmailVerificationHandler(auth *service.AuthService) *EmailVerificationHandler {
	return &EmailVerificationHandler{auth: auth}
}

// POST /email/verify {token}
func (h *EmailVerificationHandler) Verify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	if err := h.auth.VerifyEmail(r.Context(), req.Token); err != nil {
		writeServiceError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// POST /email/resend-verification — повторная отправка письма.
// Требует валидный access-токен.
func (h *EmailVerificationHandler) Resend(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	if err := h.auth.ResendVerification(r.Context(), userID); err != nil {
		writeServiceError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
