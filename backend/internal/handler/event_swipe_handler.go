package handler

import (
	"event-map/internal/middleware"
	"event-map/internal/repository"
	"log/slog"
	"net/http"

	"github.com/google/uuid"
)

type EventSwipeHandler struct {
	swipeRepo *repository.EventSwipeRepository
}

func NewEventSwipeHandler(swipeRepo *repository.EventSwipeRepository) *EventSwipeHandler {
	return &EventSwipeHandler{swipeRepo: swipeRepo}
}

// POST /events/skip?id=<event_id>
// Записывает скип события юзером — анти-повтор в свайп-ленте.
func (h *EventSwipeHandler) Skip(w http.ResponseWriter, r *http.Request) {
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

	if err := h.swipeRepo.MarkSkipped(userID, eventID); err != nil {
		slog.Error("Skip: db error", "err", err, "user_id", userID, "event_id", eventID)
		http.Error(w, "Ошибка записи скипа", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
}
