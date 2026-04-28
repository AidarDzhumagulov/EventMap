package handler

import (
	"context"
	"encoding/json"
	"errors"
	"event-map/internal/auth"
	"event-map/internal/middleware"
	"event-map/internal/models"
	"event-map/internal/repository"
	"log/slog"
	"net/http"
	"strings"

	"github.com/google/uuid"
)

type Handler struct {
	userRepo  *repository.UserRepository
	tokenRepo *repository.RefreshTokenRepository
}

type tokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

func NewHandler(userRepo *repository.UserRepository, tokenRepo *repository.RefreshTokenRepository) *Handler {
	return &Handler{
		userRepo:  userRepo,
		tokenRepo: tokenRepo,
	}
}

func (h *Handler) RegisterUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	var registerUser models.RegisterUser
	if err := json.NewDecoder(r.Body).Decode(&registerUser); err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	registerUser.Email = strings.TrimSpace(strings.ToLower(registerUser.Email))
	registerUser.Username = strings.TrimSpace(registerUser.Username)

	if registerUser.Email == "" || registerUser.Username == "" || registerUser.Password == "" {
		http.Error(w, "email, username и password обязательны", http.StatusBadRequest)
		return
	}
	if len(registerUser.Password) < 8 {
		http.Error(w, "Пароль должен быть не короче 8 символов", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	if h.userRepo.IsExist(ctx, registerUser.Email) {
		http.Error(w, "Email already exist", http.StatusBadRequest)
		return
	}
	if h.userRepo.IsUsernameExist(ctx, registerUser.Username) {
		http.Error(w, "Username already exist", http.StatusBadRequest)
		return
	}

	hash, err := auth.HashPassword(registerUser.Password)
	if err != nil {
		slog.Error("RegisterUser: hash error", "err", err)
		http.Error(w, "Ошибка при хэшировании пароля", http.StatusInternalServerError)
		return
	}

	newUser := models.User{
		Email:        registerUser.Email,
		Username:     registerUser.Username,
		Role:         "user",
		Rating:       0,
		PasswordHash: hash,
	}

	created, err := h.userRepo.Create(ctx, newUser)
	if err != nil {
		slog.Error("RegisterUser: db error", "err", err)
		http.Error(w, "Ошибка при записи в БД", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(created)
}

// issueTokenPair — общая часть для Login и при первой генерации токенов.
// Создаёт новую family (= новая сессия) и записывает refresh в БД.
func (h *Handler) issueTokenPair(ctx context.Context, userID uuid.UUID) (tokenResponse, error) {
	familyID := uuid.New()
	jti := uuid.New()

	accessToken, err := auth.GenerateAccessToken(userID)
	if err != nil {
		return tokenResponse{}, err
	}
	refreshToken, expiresAt, err := auth.GenerateRefreshToken(userID, jti, familyID)
	if err != nil {
		return tokenResponse{}, err
	}
	if err := h.tokenRepo.Insert(ctx, jti, familyID, userID, expiresAt); err != nil {
		return tokenResponse{}, err
	}
	return tokenResponse{AccessToken: accessToken, RefreshToken: refreshToken}, nil
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	var req models.LoginUser
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	ctx := r.Context()

	user, err := h.userRepo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		// Не палим существование email-а — единое сообщение для обоих случаев.
		http.Error(w, "Неверный email или пароль", http.StatusUnauthorized)
		return
	}

	needsRehash, err := auth.VerifyPassword(user.PasswordHash, req.Password)
	if err != nil {
		http.Error(w, "Неверный email или пароль", http.StatusUnauthorized)
		return
	}

	// Lazy migration: пароль был в legacy-формате — пересохраняем чистым bcrypt.
	if needsRehash {
		if newHash, err := auth.HashPassword(req.Password); err == nil {
			if err := h.userRepo.UpdatePassword(ctx, user.ID, newHash); err != nil {
				slog.Warn("Login: password rehash failed (non-critical)", "err", err, "user_id", user.ID)
			}
		}
	}

	tokens, err := h.issueTokenPair(ctx, user.ID)
	if err != nil {
		slog.Error("Login: issue tokens", "err", err, "user_id", user.ID)
		http.Error(w, "Ошибка при генерации токенов", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(tokens)
}

func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Разрешен только GET метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	user, err := h.userRepo.GetByID(r.Context(), userID)
	if err != nil {
		http.Error(w, "Пользователь не найден", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(user)
}

// PATCH /me/update — обновление профиля текущего пользователя.
func (h *Handler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPatch {
		http.Error(w, "Разрешен только PATCH метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req models.UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	req.Username = strings.TrimSpace(req.Username)
	if req.Username == "" {
		http.Error(w, "username обязателен", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	if h.userRepo.IsUsernameTakenByOther(ctx, req.Username, userID) {
		http.Error(w, "Имя пользователя уже занято", http.StatusConflict)
		return
	}

	user, err := h.userRepo.Update(ctx, userID, req.Username, req.AvatarURL)
	if err != nil {
		http.Error(w, "Ошибка обновления профиля", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(user)
}

// Refresh — token rotation с reuse-detection.
//
//  1. Парсим токен, проверяем подпись/алгоритм/тип/expiry.
//  2. Атомарно: проверяем БД-запись, помечаем used, выдаём новый.
//  3. Если токен уже used (reuse) — отзываем всю family (атака детектирована),
//     юзер должен залогиниться заново.
func (h *Handler) Refresh(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	authHeader := r.Header.Get("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		http.Error(w, "Refresh token required", http.StatusUnauthorized)
		return
	}
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")

	claims, err := auth.ParseRefreshToken(tokenString)
	if err != nil {
		http.Error(w, "Invalid refresh token", http.StatusUnauthorized)
		return
	}

	ctx := r.Context()
	newJTI := uuid.New()

	// Сначала генерим новый refresh — нужен expiresAt для записи в БД.
	newRefreshToken, newExpiresAt, err := auth.GenerateRefreshToken(claims.UserID, newJTI, claims.FamilyID)
	if err != nil {
		http.Error(w, "Ошибка при генерации refresh_token", http.StatusInternalServerError)
		return
	}

	// Атомарно: проверяем старый, помечаем used, записываем новый.
	err = h.tokenRepo.Rotate(ctx, claims.JTI, claims.FamilyID, claims.UserID, newJTI, newExpiresAt)
	if err != nil {
		switch {
		case errors.Is(err, repository.ErrTokenReused):
			// Атака — кто-то использует уже отработанный токен.
			// Кастомный header → клиент покажет специальный месседж юзеру.
			slog.Warn("Refresh: token reuse detected — family revoked",
				"user_id", claims.UserID, "family_id", claims.FamilyID)
			w.Header().Set("X-Auth-Error", "token_reuse")
			http.Error(w, "Token reuse detected, please login again", http.StatusUnauthorized)
		case errors.Is(err, repository.ErrTokenRevoked),
			errors.Is(err, repository.ErrTokenExpired),
			errors.Is(err, repository.ErrTokenNotFound):
			http.Error(w, "Invalid refresh token", http.StatusUnauthorized)
		default:
			slog.Error("Refresh: db error", "err", err)
			http.Error(w, "Ошибка при ротации токенов", http.StatusInternalServerError)
		}
		return
	}

	accessToken, err := auth.GenerateAccessToken(claims.UserID)
	if err != nil {
		http.Error(w, "Ошибка при генерации access_token", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(tokenResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefreshToken,
	})
}

// POST /logout — отзывает текущую сессию (одну family).
// Тело: refresh_token в Authorization header.
// Идемпотентно — повторный logout не упадёт.
func (h *Handler) Logout(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	authHeader := r.Header.Get("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		http.Error(w, "Refresh token required", http.StatusUnauthorized)
		return
	}
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")

	claims, err := auth.ParseRefreshToken(tokenString)
	if err != nil {
		// Токен невалиден — сессия уже всё равно мёртвая. Возвращаем 204.
		w.WriteHeader(http.StatusNoContent)
		return
	}

	if err := h.tokenRepo.RevokeFamily(r.Context(), claims.FamilyID); err != nil {
		slog.Error("Logout: db error", "err", err)
		http.Error(w, "Ошибка при выходе", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// POST /logout-all — отзывает все сессии текущего юзера (все устройства).
// Требует валидный access-token (стандартный middleware AuthLogging).
func (h *Handler) LogoutAll(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	if err := h.tokenRepo.RevokeAllForUser(r.Context(), userID); err != nil {
		slog.Error("LogoutAll: db error", "err", err, "user_id", userID)
		http.Error(w, "Ошибка при выходе", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
