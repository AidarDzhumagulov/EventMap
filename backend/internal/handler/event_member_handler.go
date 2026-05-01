package handler

import (
	"event-map/internal/middleware"
	"event-map/internal/service"
	"net/http"
)

type EventMemberHandler struct {
	rsvp *service.RsvpService
}

func NewEventMemberHandler(rsvp *service.RsvpService) *EventMemberHandler {
	return &EventMemberHandler{rsvp: rsvp}
}

// POST /events/join?id=<event_id>&status=go|think|decline
func (h *EventMemberHandler) Join(w http.ResponseWriter, r *http.Request) {
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

	member, err := h.rsvp.Join(r.Context(), eventID, userID, r.URL.Query().Get("status"))
	if err != nil {
		writeServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusCreated, member)
}

// GET /events/my-status?id=<event_id> — статус текущего юзера на событии.
// 204 если юзер не записан.
func (h *EventMemberHandler) GetMyStatus(w http.ResponseWriter, r *http.Request) {
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

	status, err := h.rsvp.GetMyStatus(r.Context(), eventID, userID)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	if status == "" {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": status})
}

// GET /events/members?id=<event_id> — список участников.
func (h *EventMemberHandler) GetMembers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Разрешен только GET метод", http.StatusMethodNotAllowed)
		return
	}

	eventID, ok := parseUUIDQuery(w, r, "id")
	if !ok {
		return
	}

	members, err := h.rsvp.GetMembers(r.Context(), eventID)
	if err != nil {
		writeServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, members)
}

// POST /events/join-by-code?code=XXXXXX — для приватных событий.
func (h *EventMemberHandler) JoinByCode(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	member, err := h.rsvp.JoinByCode(r.Context(), r.URL.Query().Get("code"), userID)
	if err != nil {
		writeServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusCreated, member)
}

func (h *EventMemberHandler) Leave(w http.ResponseWriter, r *http.Request) {
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

	if err := h.rsvp.Leave(r.Context(), eventID, userID); err != nil {
		writeServiceError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
