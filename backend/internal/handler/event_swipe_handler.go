package handler

import (
	"event-map/internal/middleware"
	"event-map/internal/service"
	"net/http"
)

type EventSwipeHandler struct {
	events *service.EventService
}

func NewEventSwipeHandler(events *service.EventService) *EventSwipeHandler {
	return &EventSwipeHandler{events: events}
}

// POST /events/skip?id=<event_id>
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

	eventID, ok := parseUUIDQuery(w, r, "id")
	if !ok {
		return
	}

	if err := h.events.SkipEvent(r.Context(), userID, eventID); err != nil {
		writeServiceError(w, err)
		return
	}

	w.WriteHeader(http.StatusCreated)
}
