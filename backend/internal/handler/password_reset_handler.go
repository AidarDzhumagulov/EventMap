package handler

import (
	"encoding/json"
	"errors"
	"event-map/internal/auth"
	"event-map/internal/email"
	"event-map/internal/repository"
	"log/slog"
	"net/http"
	"strings"
	"time"
)

const passwordResetTokenTTL = 1 * time.Hour

type PasswordResetHandler struct {
	userRepo  *repository.UserRepository
	resetRepo *repository.PasswordResetRepository
	tokenRepo *repository.RefreshTokenRepository
	mailer    email.Mailer
}

func NewPasswordResetHandler(
	userRepo *repository.UserRepository,
	resetRepo *repository.PasswordResetRepository,
	tokenRepo *repository.RefreshTokenRepository,
	mailer email.Mailer,
) *PasswordResetHandler {
	return &PasswordResetHandler{
		userRepo:  userRepo,
		resetRepo: resetRepo,
		tokenRepo: tokenRepo,
		mailer:    mailer,
	}
}

// POST /password/request-reset {email}
//
// Безопасность: всегда возвращаем 204 — независимо от существования email.
// Иначе атакующий через таймиги/коды ответов узнал бы какие email зареганы
// (account enumeration).
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
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	if req.Email == "" {
		http.Error(w, "email обязателен", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	user, err := h.userRepo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		// Email не найден — отвечаем 204, не палим существование.
		w.WriteHeader(http.StatusNoContent)
		return
	}

	// Удаляем старые токены — у юзера будет один валидный.
	if err := h.resetRepo.DeleteForUser(ctx, user.ID); err != nil {
		slog.Error("password reset: cleanup old tokens", "err", err, "user_id", user.ID)
	}

	token, err := auth.RandomToken()
	if err != nil {
		slog.Error("password reset: generate token", "err", err)
		// Не палим клиенту ошибку — отвечаем 204 чтобы не выдать enumeration через timing.
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if err := h.resetRepo.Insert(ctx, token, user.ID, time.Now().Add(passwordResetTokenTTL)); err != nil {
		slog.Error("password reset: insert token", "err", err, "user_id", user.ID)
		w.WriteHeader(http.StatusNoContent)
		return
	}

	msg := email.PasswordResetEmail(user.Email, user.Username, token)
	if err := h.mailer.Send(ctx, msg); err != nil {
		slog.Error("password reset: send email", "err", err, "user_id", user.ID)
		// Уже не откатываем токен — юзер при повторном request-reset получит новый.
	}

	w.WriteHeader(http.StatusNoContent)
}

// POST /password/reset {token, password}
//
// Проверяет токен, ставит новый пароль, отзывает все refresh-сессии юзера
// (на других устройствах придётся залогиниться заново — это ожидаемое поведение
// при сбросе пароля).
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
	if req.Token == "" {
		http.Error(w, "Токен обязателен", http.StatusBadRequest)
		return
	}
	if len(req.Password) < 8 {
		http.Error(w, "Пароль должен быть не короче 8 символов", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	userID, err := h.resetRepo.Consume(ctx, req.Token)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			http.Error(w, "Ссылка недействительна или истекла", http.StatusBadRequest)
			return
		}
		slog.Error("password reset: consume", "err", err)
		http.Error(w, "Ошибка проверки токена", http.StatusInternalServerError)
		return
	}

	hash, err := auth.HashPassword(req.Password)
	if err != nil {
		slog.Error("password reset: hash", "err", err)
		http.Error(w, "Ошибка хэширования", http.StatusInternalServerError)
		return
	}
	if err := h.userRepo.UpdatePassword(ctx, userID, hash); err != nil {
		slog.Error("password reset: update password", "err", err, "user_id", userID)
		http.Error(w, "Ошибка обновления пароля", http.StatusInternalServerError)
		return
	}

	// Безопасность: отзываем все refresh-сессии. Если злоумышленник был залогинен —
	// его access-токен ещё работает 15 минут, но refresh уже мёртвый.
	if err := h.tokenRepo.RevokeAllForUser(ctx, userID); err != nil {
		slog.Warn("password reset: revoke sessions failed", "err", err, "user_id", userID)
	}

	w.WriteHeader(http.StatusNoContent)
}
