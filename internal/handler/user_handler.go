package handler

import (
	"encoding/json"
	"event-map/internal/models"
	"event-map/internal/repository"
	"net/http"

	"github.com/google/uuid"
)

type Handler struct {
	userRepo *repository.UserRepository
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

	var newUser models.User

	err := json.NewDecoder(r.Body).Decode(&newUser)

	if err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	newUser.ID = uuid.New()

	newUser.Rating = 0.0

	err = h.userRepo.Create(newUser)

	if err != nil {
		http.Error(w, "Ошибка при записи в БД", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	w.WriteHeader(http.StatusCreated)

	json.NewEncoder(w).Encode(newUser)

}
