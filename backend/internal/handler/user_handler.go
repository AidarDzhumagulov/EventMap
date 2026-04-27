package handler

import (
	"crypto/sha256"
	"encoding/json"
	"event-map/internal/auth"
	"event-map/internal/middleware"
	"event-map/internal/models"
	"event-map/internal/repository"
	"log/slog"
	"net/http"
	"os"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
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
	var newUser models.User

	if err := json.NewDecoder(r.Body).Decode(&registerUser); err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	if registerUser.Email == "" || registerUser.Username == "" || registerUser.Password == "" {
		http.Error(w, "email, username и password обязательны", http.StatusBadRequest)
		return
	}

	if h.userRepo.IsExist(registerUser.Email) {
		http.Error(w, "Email already exist", http.StatusBadRequest)
		return
	}

	if h.userRepo.IsUsernameExist(registerUser.Username) {
		http.Error(w, "Username already exist", http.StatusBadRequest)
		return
	}

	salt := os.Getenv("SALT")

	digest := sha256.Sum256([]byte(registerUser.Password + salt))
	hash, err := bcrypt.GenerateFromPassword(digest[:], bcrypt.DefaultCost)

	if err != nil {
		http.Error(w, "Ошибка при хэшировании пароля", http.StatusBadRequest)
		return
	}

	newUser.PasswordHash = string(hash)
	newUser.Rating = 0.0
	newUser.Username = registerUser.Username
	newUser.Email = registerUser.Email
	newUser.Role = "user"

	created, err := h.userRepo.Create(newUser)
	if err != nil {
		slog.Error("RegisterUser: db error", "err", err)
		http.Error(w, "Ошибка при записи в БД", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(created)

}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	var LoginUser models.LoginUser

	err := json.NewDecoder(r.Body).Decode(&LoginUser)

	if err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	user, err := h.userRepo.GetUserByEmail(LoginUser.Email)
	if err != nil {
		http.Error(w, "Такого пользователя не существует", http.StatusUnauthorized)
		return
	}

	salt := os.Getenv("SALT")

	digest := sha256.Sum256([]byte(LoginUser.Password + salt))
	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), digest[:])

	if err != nil {
		http.Error(w, "Не верный пароль", http.StatusUnauthorized)
		return
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
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(tokenResponse{
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

	user, err := h.userRepo.GetByID(userID)
	if err != nil {
		http.Error(w, "Пользователь не найден", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(user)
}

// PATCH /me/update — обновление профиля текущего пользователя
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

	if req.Username == "" {
		http.Error(w, "username обязателен", http.StatusBadRequest)
		return
	}

	if h.userRepo.IsUsernameTakenByOther(req.Username, userID) {
		http.Error(w, "Имя пользователя уже занято", http.StatusConflict)
		return
	}

	user, err := h.userRepo.Update(userID, req.Username, req.AvatarURL)
	if err != nil {
		http.Error(w, "Ошибка обновления профиля", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

func (h *Handler) Refresh(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	authHeader := r.Header.Get("Authorization")
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	if tokenString == "" {
		http.Error(w, "Refresh token required", http.StatusUnauthorized)
		return
	}

	secretKey := os.Getenv("JWT_SECRET")
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		return []byte(secretKey), nil
	})
	if err != nil || !token.Valid {
		http.Error(w, "Invalid refresh token", http.StatusUnauthorized)
		return
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		http.Error(w, "Invalid token claims", http.StatusUnauthorized)
		return
	}

	userIDStr, ok := claims["user_id"].(string)
	if !ok {
		http.Error(w, "Invalid token claims", http.StatusUnauthorized)
		return
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		http.Error(w, "Invalid user id", http.StatusUnauthorized)
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
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(tokenResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	})
}
