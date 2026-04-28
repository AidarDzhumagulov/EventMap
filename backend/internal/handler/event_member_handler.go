package handler

import (
	"encoding/json"
	"errors"
	"event-map/internal/middleware"
	"event-map/internal/repository"
	"net/http"

	"github.com/google/uuid"
)

var validStatuses = map[string]bool{"go": true, "think": true, "decline": true}

type EventMemberHandler struct {
	memberRepo *repository.EventMemberRepository
	eventRepo  *repository.EventRepository
}

func NewEventMemberHandler(
	memberRepo *repository.EventMemberRepository,
	eventRepo *repository.EventRepository,
) *EventMemberHandler {
	return &EventMemberHandler{memberRepo: memberRepo, eventRepo: eventRepo}
}

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

	eventIDStr := r.URL.Query().Get("id")
	eventID, err := uuid.Parse(eventIDStr)
	if err != nil {
		http.Error(w, "Неверный ID события", http.StatusBadRequest)
		return
	}

	status := r.URL.Query().Get("status")
	if status == "" {
		status = "go"
	}
	if !validStatuses[status] {
		http.Error(w, "Статус должен быть: go, think, decline", http.StatusBadRequest)
		return
	}

	member, err := h.memberRepo.JoinAtomic(r.Context(), eventID, userID, status)
	if err != nil {
		if errors.Is(err, repository.ErrEventFull) {
			http.Error(w, "Мест нет", http.StatusConflict)
			return
		}
		http.Error(w, "Ошибка записи на событие", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(member)
}

// GET /events/my-status?id=<event_id> — возвращает статус текущего пользователя
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

	eventID, err := uuid.Parse(r.URL.Query().Get("id"))
	if err != nil {
		http.Error(w, "Неверный ID события", http.StatusBadRequest)
		return
	}

	status, err := h.memberRepo.GetStatus(r.Context(), eventID, userID)
	if err != nil {
		// Пользователь не записан — 204 No Content
		w.WriteHeader(http.StatusNoContent)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": status})
}

// GET /events/members?id=<event_id> — список участников события
func (h *EventMemberHandler) GetMembers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Разрешен только GET метод", http.StatusMethodNotAllowed)
		return
	}

	eventID, err := uuid.Parse(r.URL.Query().Get("id"))
	if err != nil {
		http.Error(w, "Неверный ID события", http.StatusBadRequest)
		return
	}

	members, err := h.memberRepo.GetMembers(r.Context(), eventID)
	if err != nil {
		http.Error(w, "Ошибка получения участников", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(members)
}

// POST /events/join-by-code?code=XXXXXX — вступить в закрытое событие по коду
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

	code := r.URL.Query().Get("code")
	if code == "" {
		http.Error(w, "Укажите код приглашения", http.StatusBadRequest)
		return
	}

	event, err := h.eventRepo.GetByInviteCode(r.Context(), code)
	if err != nil {
		http.Error(w, "Неверный код приглашения", http.StatusNotFound)
		return
	}

	member, err := h.memberRepo.JoinAtomic(r.Context(), event.ID, userID, "go")
	if err != nil {
		if errors.Is(err, repository.ErrEventFull) {
			http.Error(w, "Мест нет", http.StatusConflict)
			return
		}
		http.Error(w, "Ошибка записи на событие", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(member)
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

	eventIDStr := r.URL.Query().Get("id")
	eventID, err := uuid.Parse(eventIDStr)
	if err != nil {
		http.Error(w, "Неверный ID события", http.StatusBadRequest)
		return
	}

	if err := h.memberRepo.Leave(r.Context(), eventID, userID); err != nil {
		http.Error(w, "Ошибка отмены участия", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
