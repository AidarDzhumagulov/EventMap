package handler

import (
	"encoding/json"
	"errors"
	"event-map/internal/auth"
	"event-map/internal/middleware"
	"event-map/internal/models"
	"event-map/internal/repository"
	"log/slog"
	"net/http"
	"strings"
)

type Handler struct {
	userRepo *repository.UserRepository
}

type tokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

func NewHandler(userRepo *repository.UserRepository) *Handler {
	return &Handler{
		userRepo: userRepo,
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

	accessToken, err := auth.GenerateAccessToken(user.ID)
	if err != nil {
		http.Error(w, "Ошибка при генерации access_token", http.StatusInternalServerError)
		return
	}
	refreshToken, err := auth.GenerateRefreshToken(user.ID)
	if err != nil {
		http.Error(w, "Ошибка при генерации refresh_token", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(tokenResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	})
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

	// Критично: проверяем именно refresh-токен. Иначе access-токен можно
	// использовать как refresh — и при утечке access юзера компрометация
	// бесконечная.
	userID, err := auth.ParseToken(tokenString, auth.TokenTypeRefresh)
	if err != nil {
		if errors.Is(err, auth.ErrInvalidToken) {
			http.Error(w, "Invalid refresh token", http.StatusUnauthorized)
			return
		}
		http.Error(w, "Invalid refresh token", http.StatusUnauthorized)
		return
	}

	accessToken, err := auth.GenerateAccessToken(userID)
	if err != nil {
		http.Error(w, "Ошибка при генерации access_token", http.StatusInternalServerError)
		return
	}
	refreshToken, err := auth.GenerateRefreshToken(userID)
	if err != nil {
		http.Error(w, "Ошибка при генерации refresh_token", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(tokenResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	})
}
