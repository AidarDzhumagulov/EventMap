package handler

import (
	"encoding/json"
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

	event, err := h.eventRepo.GetByID(eventID)
	if err != nil {
		http.Error(w, "Событие не найдено", http.StatusNotFound)
		return
	}

	// Проверяем лимит только если пользователь хочет занять место (status="go")
	// и ещё не имеет статус "go" (иначе смена "go"→"think" блокировалась бы при полном событии)
	if event.MaxMembers != nil && status == "go" {
		currentStatus, _ := h.memberRepo.GetStatus(eventID, userID)
		if currentStatus != "go" {
			count, err := h.memberRepo.CountMembers(eventID)
			if err != nil {
				http.Error(w, "Ошибка проверки мест", http.StatusInternalServerError)
				return
			}
			if count >= *event.MaxMembers {
				http.Error(w, "Мест нет", http.StatusConflict)
				return
			}
		}
	}

	member, err := h.memberRepo.Join(eventID, userID, status)
	if err != nil {
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

	status, err := h.memberRepo.GetStatus(eventID, userID)
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

	members, err := h.memberRepo.GetMembers(eventID)
	if err != nil {
		http.Error(w, "Ошибка получения участников", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(members)
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

	if err := h.memberRepo.Leave(eventID, userID); err != nil {
		http.Error(w, "Ошибка отмены участия", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
