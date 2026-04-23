package handler

import (
	"encoding/json"
	"event-map/internal/auth"
	"event-map/internal/models"
	"event-map/internal/repository"
	"net/http"
	"os"

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

	err := json.NewDecoder(r.Body).Decode(&registerUser)

	if err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	isExists := h.userRepo.IsExist(registerUser.Email)

	if isExists {
		http.Error(w, "Email already exist", http.StatusBadRequest)
		return
	}

	salt := os.Getenv("SALT")

	password := []byte(registerUser.Password + salt)

	hash, err := bcrypt.GenerateFromPassword(password, bcrypt.DefaultCost)

	if err != nil {
		http.Error(w, "Ошибка при хэшировании пароля", http.StatusBadRequest)
		return
	}

	newUser.PasswordHash = string(hash)

	newUser.ID = uuid.New()

	newUser.Rating = 0.0

	newUser.Username = registerUser.Username

	newUser.Email = registerUser.Email

	newUser.Role = registerUser.Role

	err = h.userRepo.Create(newUser)

	if err != nil {
		http.Error(w, "Ошибка при записи в БД", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	w.WriteHeader(http.StatusCreated)

	json.NewEncoder(w).Encode(newUser)

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

	password := []byte(LoginUser.Password + salt)

	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), password)

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
