package handler

import (
	"encoding/json"
	"event-map/internal/middleware"
	"event-map/internal/repository"
	"net/http"

	"github.com/google/uuid"
)

type SavedEventHandler struct {
	savedRepo *repository.SavedEventRepository
}

func NewSavedEventHandler(savedRepo *repository.SavedEventRepository) *SavedEventHandler {
	return &SavedEventHandler{savedRepo: savedRepo}
}

// POST /events/save?id=<event_id>
func (h *SavedEventHandler) Save(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	eventID, err := uuid.Parse(r.URL.Query().Get("id"))
	if err != nil {
		http.Error(w, "Неверный ID события", http.StatusBadRequest)
		return
	}

	if err := h.savedRepo.Save(eventID, userID); err != nil {
		http.Error(w, "Ошибка сохранения", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
}

// DELETE /events/save?id=<event_id>
func (h *SavedEventHandler) Unsave(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "Разрешен только DELETE метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	eventID, err := uuid.Parse(r.URL.Query().Get("id"))
	if err != nil {
		http.Error(w, "Неверный ID события", http.StatusBadRequest)
		return
	}

	if err := h.savedRepo.Unsave(eventID, userID); err != nil {
		http.Error(w, "Ошибка удаления", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// GET /events/is-saved?id=<event_id>
func (h *SavedEventHandler) IsSaved(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Разрешен только GET метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	eventID, err := uuid.Parse(r.URL.Query().Get("id"))
	if err != nil {
		http.Error(w, "Неверный ID события", http.StatusBadRequest)
		return
	}

	saved, err := h.savedRepo.IsSaved(eventID, userID)
	if err != nil {
		http.Error(w, "Ошибка проверки", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"saved": saved})
}

// GET /events/saved
func (h *SavedEventHandler) GetSaved(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Разрешен только GET метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	events, err := h.savedRepo.GetSavedByUser(userID)
	if err != nil {
		http.Error(w, "Ошибка получения сохранённых событий", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(events)
}
