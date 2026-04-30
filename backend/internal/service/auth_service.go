// Package service — бизнес-логика в чистом виде, без HTTP.
//
// Зачем: handler'ы становятся тонкими (только парсинг запроса, делегирование
// в service, формирование ответа), service содержит правила; repository
// только SQL. Это позволяет:
//   - Юнит-тестировать бизнес-логику без поднятия HTTP-сервера
//   - Переиспользовать логику из gRPC / CLI / cron-job без копи-пасты
//   - Легко мокать зависимости в тестах
package service

import (
	"context"
	"errors"
	"event-map/internal/auth"
	"event-map/internal/email"
	"event-map/internal/models"
	"event-map/internal/repository"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"
)

const (
	verificationTokenTTL  = 24 * time.Hour
	passwordResetTokenTTL = 1 * time.Hour
	minPasswordLength     = 8
)

// Sentinel-ошибки бизнес-уровня. Handler маппит их на HTTP-статусы.
var (
	ErrInvalidInput       = errors.New("invalid input")
	ErrEmailTaken         = errors.New("email already taken")
	ErrUsernameTaken      = errors.New("username already taken")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrInvalidToken       = errors.New("invalid or expired token")
	ErrTokenReuseDetected = errors.New("token reuse detected")
)

// AuthService — публичный API для всех auth-операций.
//
// Не зависит от http.Request — принимает context и доменные параметры.
// Это делает его тестируемым в изоляции.
type AuthService struct {
	users         *repository.UserRepository
	tokens        *repository.RefreshTokenRepository
	emailVerify   *repository.EmailVerificationRepository
	passwordReset *repository.PasswordResetRepository
	mailer        email.Mailer
}

func NewAuthService(
	users *repository.UserRepository,
	tokens *repository.RefreshTokenRepository,
	emailVerify *repository.EmailVerificationRepository,
	passwordReset *repository.PasswordResetRepository,
	mailer email.Mailer,
) *AuthService {
	return &AuthService{
		users:         users,
		tokens:        tokens,
		emailVerify:   emailVerify,
		passwordReset: passwordReset,
		mailer:        mailer,
	}
}

// TokenPair — результат логина / refresh.
type TokenPair struct {
	AccessToken  string
	RefreshToken string
}

// Register создаёт юзера, отправляет письмо подтверждения.
// Email и username нормализуются (trim/lower) внутри.
func (s *AuthService) Register(ctx context.Context, emailAddr, username, password string) (models.User, error) {
	emailAddr = strings.TrimSpace(strings.ToLower(emailAddr))
	username = strings.TrimSpace(username)

	if emailAddr == "" || username == "" || password == "" {
		return models.User{}, fmt.Errorf("%w: email, username и password обязательны", ErrInvalidInput)
	}
	if len(password) < minPasswordLength {
		return models.User{}, fmt.Errorf("%w: пароль должен быть не короче %d символов", ErrInvalidInput, minPasswordLength)
	}

	if s.users.IsExist(ctx, emailAddr) {
		return models.User{}, ErrEmailTaken
	}
	if s.users.IsUsernameExist(ctx, username) {
		return models.User{}, ErrUsernameTaken
	}

	hash, err := auth.HashPassword(password)
	if err != nil {
		return models.User{}, fmt.Errorf("hash password: %w", err)
	}

	created, err := s.users.Create(ctx, models.User{
		Email:         emailAddr,
		EmailVerified: false,
		Username:      username,
		Role:          "user",
		Rating:        0,
		PasswordHash:  hash,
	})
	if err != nil {
		return models.User{}, fmt.Errorf("create user: %w", err)
	}

	// Письмо отправляем не блокируя регистрацию — юзер сможет запросить resend.
	if err := s.sendVerificationEmail(ctx, created.ID, created.Email, created.Username); err != nil {
		slog.Warn("Register: send verification failed (non-blocking)", "err", err, "user_id", created.ID)
	}

	return created, nil
}

// Login проверяет пароль (с lazy-migration старых хэшей) и выдаёт токены.
// Не палит существование email — на оба случая (неверный email, неверный пароль)
// возвращает один ErrInvalidCredentials.
func (s *AuthService) Login(ctx context.Context, emailAddr, password string) (TokenPair, error) {
	emailAddr = strings.TrimSpace(strings.ToLower(emailAddr))

	user, err := s.users.GetUserByEmail(ctx, emailAddr)
	if err != nil {
		return TokenPair{}, ErrInvalidCredentials
	}

	needsRehash, err := auth.VerifyPassword(user.PasswordHash, password)
	if err != nil {
		return TokenPair{}, ErrInvalidCredentials
	}

	// Lazy migration: пароль был в legacy-формате — пересохраняем чистым bcrypt.
	if needsRehash {
		if newHash, err := auth.HashPassword(password); err == nil {
			if err := s.users.UpdatePassword(ctx, user.ID, newHash); err != nil {
				slog.Warn("Login: rehash failed (non-critical)", "err", err, "user_id", user.ID)
			}
		}
	}

	return s.issueTokenPair(ctx, user.ID)
}

// Refresh — token rotation с reuse-detection.
func (s *AuthService) Refresh(ctx context.Context, refreshToken string) (TokenPair, error) {
	claims, err := auth.ParseRefreshToken(refreshToken)
	if err != nil {
		return TokenPair{}, ErrInvalidToken
	}

	newJTI := uuid.New()
	newRefreshToken, newExpiresAt, err := auth.GenerateRefreshToken(claims.UserID, newJTI, claims.FamilyID)
	if err != nil {
		return TokenPair{}, fmt.Errorf("generate refresh: %w", err)
	}

	err = s.tokens.Rotate(ctx, claims.JTI, claims.FamilyID, claims.UserID, newJTI, newExpiresAt)
	if err != nil {
		switch {
		case errors.Is(err, repository.ErrTokenReused):
			slog.Warn("Refresh: token reuse detected — family revoked",
				"user_id", claims.UserID, "family_id", claims.FamilyID)
			return TokenPair{}, ErrTokenReuseDetected
		case errors.Is(err, repository.ErrTokenRevoked),
			errors.Is(err, repository.ErrTokenExpired),
			errors.Is(err, repository.ErrTokenNotFound):
			return TokenPair{}, ErrInvalidToken
		default:
			return TokenPair{}, fmt.Errorf("rotate: %w", err)
		}
	}

	accessToken, err := auth.GenerateAccessToken(claims.UserID)
	if err != nil {
		return TokenPair{}, fmt.Errorf("generate access: %w", err)
	}
	return TokenPair{AccessToken: accessToken, RefreshToken: newRefreshToken}, nil
}

// Logout отзывает текущую сессию (одну family) по refresh-токену.
// Идемпотентно — невалидный токен не возвращает ошибку.
func (s *AuthService) Logout(ctx context.Context, refreshToken string) error {
	claims, err := auth.ParseRefreshToken(refreshToken)
	if err != nil {
		// Токен уже невалиден — сессия и так мёртвая, считаем успехом.
		return nil
	}
	return s.tokens.RevokeFamily(ctx, claims.FamilyID)
}

// LogoutAll отзывает все сессии юзера.
func (s *AuthService) LogoutAll(ctx context.Context, userID uuid.UUID) error {
	return s.tokens.RevokeAllForUser(ctx, userID)
}

// VerifyEmail подтверждает email по токену из письма.
func (s *AuthService) VerifyEmail(ctx context.Context, token string) error {
	if token == "" {
		return ErrInvalidInput
	}
	if _, err := s.emailVerify.Consume(ctx, token); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return ErrInvalidToken
		}
		return fmt.Errorf("consume verification: %w", err)
	}
	return nil
}

// ResendVerification отправляет повторное письмо подтверждения.
// Если email уже подтверждён — no-op (без ошибки).
func (s *AuthService) ResendVerification(ctx context.Context, userID uuid.UUID) error {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return fmt.Errorf("get user: %w", err)
	}
	if user.EmailVerified {
		return nil
	}

	if err := s.emailVerify.DeleteForUser(ctx, userID); err != nil {
		slog.Warn("ResendVerification: cleanup old tokens", "err", err, "user_id", userID)
	}

	return s.sendVerificationEmail(ctx, userID, user.Email, user.Username)
}

// RequestPasswordReset отправляет ссылку для сброса пароля.
// Всегда возвращает nil (анти-enumeration), даже если email не найден.
// Реальные ошибки логируются.
func (s *AuthService) RequestPasswordReset(ctx context.Context, emailAddr string) error {
	emailAddr = strings.TrimSpace(strings.ToLower(emailAddr))
	if emailAddr == "" {
		return ErrInvalidInput
	}

	user, err := s.users.GetUserByEmail(ctx, emailAddr)
	if err != nil {
		// Email не найден — не палим существование.
		return nil
	}

	if err := s.passwordReset.DeleteForUser(ctx, user.ID); err != nil {
		slog.Error("password reset: cleanup old tokens", "err", err, "user_id", user.ID)
	}

	token, err := auth.RandomToken()
	if err != nil {
		slog.Error("password reset: generate token", "err", err)
		return nil
	}
	if err := s.passwordReset.Insert(ctx, token, user.ID, time.Now().Add(passwordResetTokenTTL)); err != nil {
		slog.Error("password reset: insert token", "err", err, "user_id", user.ID)
		return nil
	}

	msg := email.PasswordResetEmail(user.Email, user.Username, token)
	if err := s.mailer.Send(ctx, msg); err != nil {
		slog.Error("password reset: send email", "err", err, "user_id", user.ID)
	}
	return nil
}

// ResetPassword меняет пароль по токену из письма + отзывает все сессии.
func (s *AuthService) ResetPassword(ctx context.Context, token, newPassword string) error {
	if token == "" {
		return ErrInvalidInput
	}
	if len(newPassword) < minPasswordLength {
		return fmt.Errorf("%w: пароль должен быть не короче %d символов", ErrInvalidInput, minPasswordLength)
	}

	userID, err := s.passwordReset.Consume(ctx, token)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return ErrInvalidToken
		}
		return fmt.Errorf("consume reset token: %w", err)
	}

	hash, err := auth.HashPassword(newPassword)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}
	if err := s.users.UpdatePassword(ctx, userID, hash); err != nil {
		return fmt.Errorf("update password: %w", err)
	}

	// Безопасность: отзываем все refresh-сессии. Если злоумышленник был залогинен —
	// его access-токен ещё работает 15 минут, но refresh уже мёртвый.
	if err := s.tokens.RevokeAllForUser(ctx, userID); err != nil {
		slog.Warn("password reset: revoke sessions failed", "err", err, "user_id", userID)
	}
	return nil
}

// issueTokenPair — приватный helper: создаёт новую family и записывает refresh.
func (s *AuthService) issueTokenPair(ctx context.Context, userID uuid.UUID) (TokenPair, error) {
	familyID := uuid.New()
	jti := uuid.New()

	accessToken, err := auth.GenerateAccessToken(userID)
	if err != nil {
		return TokenPair{}, fmt.Errorf("generate access: %w", err)
	}
	refreshToken, expiresAt, err := auth.GenerateRefreshToken(userID, jti, familyID)
	if err != nil {
		return TokenPair{}, fmt.Errorf("generate refresh: %w", err)
	}
	if err := s.tokens.Insert(ctx, jti, familyID, userID, expiresAt); err != nil {
		return TokenPair{}, fmt.Errorf("insert refresh: %w", err)
	}
	return TokenPair{AccessToken: accessToken, RefreshToken: refreshToken}, nil
}

// sendVerificationEmail — приватный helper: создаёт токен, отправляет письмо.
func (s *AuthService) sendVerificationEmail(ctx context.Context, userID uuid.UUID, emailAddr, username string) error {
	token, err := auth.RandomToken()
	if err != nil {
		return fmt.Errorf("generate token: %w", err)
	}
	if err := s.emailVerify.Insert(ctx, token, userID, time.Now().Add(verificationTokenTTL)); err != nil {
		return fmt.Errorf("insert token: %w", err)
	}

	msg := email.VerificationEmail(emailAddr, username, token)
	if err := s.mailer.Send(ctx, msg); err != nil {
		return fmt.Errorf("send: %w", err)
	}
	return nil
}
