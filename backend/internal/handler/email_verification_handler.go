package handler

import (
	"context"
	"encoding/json"
	"errors"
	"event-map/internal/auth"
	"event-map/internal/email"
	"event-map/internal/middleware"
	"event-map/internal/repository"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
)

const verificationTokenTTL = 24 * time.Hour

type EmailVerificationHandler struct {
	userRepo *repository.UserRepository
	tokens   *repository.EmailVerificationRepository
	mailer   email.Mailer
}

func NewEmailVerificationHandler(
	userRepo *repository.UserRepository,
	tokens *repository.EmailVerificationRepository,
	mailer email.Mailer,
) *EmailVerificationHandler {
	return &EmailVerificationHandler{
		userRepo: userRepo,
		tokens:   tokens,
		mailer:   mailer,
	}
}

// SendVerificationEmail — внутренний helper: создаёт токен и отправляет письмо.
// Используется из RegisterUser и из ResendVerification.
func (h *EmailVerificationHandler) SendVerificationEmail(
	ctx context.Context, userID uuid.UUID, emailAddr, username string,
) error {
	token, err := auth.RandomToken()
	if err != nil {
		return err
	}
	if err := h.tokens.Insert(ctx, token, userID, time.Now().Add(verificationTokenTTL)); err != nil {
		return err
	}

	msg := email.VerificationEmail(emailAddr, username, token)
	if err := h.mailer.Send(ctx, msg); err != nil {
		// Не ломаем регистрацию — токен уже в БД, юзер сможет запросить resend.
		slog.Error("send verification email", "err", err, "user_id", userID)
		return err
	}
	return nil
}

// POST /email/verify {token}
// Подтверждает email. Идемпотентно — повторный вызов с тем же токеном вернёт 404.
func (h *EmailVerificationHandler) Verify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Token == "" {
		http.Error(w, "Неверный токен", http.StatusBadRequest)
		return
	}

	_, err := h.tokens.Consume(r.Context(), req.Token)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			http.Error(w, "Ссылка недействительна или истекла", http.StatusBadRequest)
			return
		}
		slog.Error("verify email: db error", "err", err)
		http.Error(w, "Ошибка проверки токена", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// POST /email/resend-verification — повторная отправка письма.
// Требует валидный access-токен (юзер должен быть залогинен).
// Защита от спама — через rate limiter в main.go.
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

	ctx := r.Context()
	user, err := h.userRepo.GetByID(ctx, userID)
	if err != nil {
		http.Error(w, "Пользователь не найден", http.StatusNotFound)
		return
	}

	// Если уже подтверждён — нет смысла слать письмо.
	if user.EmailVerified {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	// Удаляем старые токены — у юзера будет один валидный.
	if err := h.tokens.DeleteForUser(ctx, userID); err != nil {
		slog.Error("resend: delete old tokens", "err", err, "user_id", userID)
	}

	if err := h.SendVerificationEmail(ctx, userID, user.Email, user.Username); err != nil {
		http.Error(w, "Не удалось отправить письмо", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
