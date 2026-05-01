package handler

import (
	"event-map/internal/middleware"
	"event-map/internal/service"
	"net/http"
)

type SavedEventHandler struct {
	events *service.EventService
}

func NewSavedEventHandler(events *service.EventService) *SavedEventHandler {
	return &SavedEventHandler{events: events}
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

	eventID, ok := parseUUIDQuery(w, r, "id")
	if !ok {
		return
	}

	if err := h.events.SaveEvent(r.Context(), userID, eventID); err != nil {
		writeServiceError(w, err)
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

	eventID, ok := parseUUIDQuery(w, r, "id")
	if !ok {
		return
	}

	if err := h.events.UnsaveEvent(r.Context(), userID, eventID); err != nil {
		writeServiceError(w, err)
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

	eventID, ok := parseUUIDQuery(w, r, "id")
	if !ok {
		return
	}

	saved, err := h.events.IsEventSaved(r.Context(), userID, eventID)
	if err != nil {
		writeServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]bool{"saved": saved})
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

	events, err := h.events.GetSavedEvents(r.Context(), userID)
	if err != nil {
		writeServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, events)
}
