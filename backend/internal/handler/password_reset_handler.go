package handler

import (
	"encoding/json"
	"event-map/internal/service"
	"net/http"
)

type PasswordResetHandler struct {
	auth *service.AuthService
}

func NewPasswordResetHandler(auth *service.AuthService) *PasswordResetHandler {
	return &PasswordResetHandler{auth: auth}
}

// POST /password/request-reset {email}
//
// Безопасность: всегда 204 (анти-enumeration), даже если email не найден.
// Service сам решает что палить, что нет.
func (h *PasswordResetHandler) RequestReset(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Email string `json:"email"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	if err := h.auth.RequestPasswordReset(r.Context(), req.Email); err != nil {
		writeServiceError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// POST /password/reset {token, password}
func (h *PasswordResetHandler) Reset(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Token    string `json:"token"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	if err := h.auth.ResetPassword(r.Context(), req.Token, req.Password); err != nil {
		writeServiceError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
