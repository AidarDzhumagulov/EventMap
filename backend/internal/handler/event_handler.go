package handler

import (
	"encoding/json"
	"errors"
	"event-map/internal/middleware"
	"event-map/internal/models"
	"event-map/internal/repository"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/google/uuid"
)

type EventHandler struct {
	eventRepo *repository.EventRepository
}

func NewEventHandler(eventRepo *repository.EventRepository) *EventHandler {
	return &EventHandler{eventRepo: eventRepo}
}

func (h *EventHandler) CreateEvent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req models.CreateEventRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		slog.Error("CreateEvent: decode body", "err", err)
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	slog.Info("CreateEvent: request", "user_id", userID, "title", req.Title, "lat", req.Lat, "lon", req.Lon, "city", req.CityName, "location_id", req.LocationID)

	if req.Title == "" || req.CityName == "" || req.StartTime.IsZero() ||
		req.Lat < -90 || req.Lat > 90 || req.Lon < -180 || req.Lon > 180 {
		http.Error(w, "Обязательные поля: title, city_name, lat, lon, start_time", http.StatusBadRequest)
		return
	}

	event, err := h.eventRepo.Create(req, userID)
	if err != nil {
		slog.Error("CreateEvent: db error", "err", err, "user_id", userID)
		http.Error(w, "Ошибка создания события", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(event)
}

func (h *EventHandler) GetEvents(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Разрешен только GET метод", http.StatusMethodNotAllowed)
		return
	}

	city := r.URL.Query().Get("city")
	status := r.URL.Query().Get("status")
	search := r.URL.Query().Get("search")

	limit := 100
	offset := 0
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 {
		if v > 200 {
			v = 200
		}
		limit = v
	}
	if v, err := strconv.Atoi(r.URL.Query().Get("offset")); err == nil && v >= 0 {
		offset = v
	}

	events, err := h.eventRepo.GetAll(city, status, search, limit, offset)
	if err != nil {
		slog.Error("GetEvents: db error", "err", err, "city", city)
		http.Error(w, "Ошибка получения событий", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(events)
}

// GET /events/feed?city=Бишкек&limit=40
// Стопка событий для свайп-механики. Анти-повтор — события, с которыми
// юзер уже взаимодействовал (лайк/RSVP/скип), не возвращаются.
func (h *EventHandler) GetFeed(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Разрешен только GET метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	city := r.URL.Query().Get("city")
	if city == "" {
		http.Error(w, "city обязателен", http.StatusBadRequest)
		return
	}

	limit := 40
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 {
		if v > 100 {
			v = 100
		}
		limit = v
	}

	events, err := h.eventRepo.GetFeed(userID, city, limit)
	if err != nil {
		slog.Error("GetFeed: db error", "err", err, "user_id", userID, "city", city)
		http.Error(w, "Ошибка получения ленты", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(events)
}

func (h *EventHandler) GetMyEvents(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Разрешен только GET метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	events, err := h.eventRepo.GetByUserID(userID)
	if err != nil {
		slog.Error("GetMyEvents: db error", "err", err, "user_id", userID)
		http.Error(w, "Ошибка получения событий", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(events)
}

func (h *EventHandler) UpdateEvent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		http.Error(w, "Разрешен только PUT метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	idStr := r.URL.Query().Get("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		http.Error(w, "Неверный ID события", http.StatusBadRequest)
		return
	}

	var req models.UpdateEventRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		slog.Error("UpdateEvent: decode body", "err", err)
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	if req.Title == "" {
		http.Error(w, "Название обязательно", http.StatusBadRequest)
		return
	}

	event, err := h.eventRepo.Update(id, req, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			http.Error(w, "Событие не найдено или нет прав", http.StatusForbidden)
			return
		}
		slog.Error("UpdateEvent: db error", "err", err, "id", id)
		http.Error(w, "Ошибка обновления события", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(event)
}

func (h *EventHandler) DeleteEvent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "Разрешен только DELETE метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	idStr := r.URL.Query().Get("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		http.Error(w, "Неверный ID события", http.StatusBadRequest)
		return
	}

	if err := h.eventRepo.Delete(id, userID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			http.Error(w, "Событие не найдено или нет прав", http.StatusForbidden)
			return
		}
		slog.Error("DeleteEvent: db error", "err", err, "id", id)
		http.Error(w, "Ошибка удаления события", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *EventHandler) GetEvent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Разрешен только GET метод", http.StatusMethodNotAllowed)
		return
	}

	idStr := r.URL.Query().Get("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		http.Error(w, "Неверный ID события", http.StatusBadRequest)
		return
	}

	event, err := h.eventRepo.GetByID(id)
	if err != nil {
		slog.Error("GetEvent: db error", "err", err, "id", id)
		http.Error(w, "Событие не найдено", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(event)
}

func (h *EventHandler) GetNearby(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Разрешен только GET метод", http.StatusMethodNotAllowed)
		return
	}

	lat, errLat := strconv.ParseFloat(r.URL.Query().Get("lat"), 64)
	lon, errLon := strconv.ParseFloat(r.URL.Query().Get("lon"), 64)
	if errLat != nil || errLon != nil {
		http.Error(w, "Укажите lat и lon", http.StatusBadRequest)
		return
	}

	radius := 5000.0
	if v, err := strconv.ParseFloat(r.URL.Query().Get("radius"), 64); err == nil && v > 0 {
		radius = v
	}

	limit := 50
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 {
		if v > 200 {
			v = 200
		}
		limit = v
	}

	events, err := h.eventRepo.GetNearby(lat, lon, radius, limit)
	if err != nil {
		slog.Error("GetNearby: db error", "err", err, "lat", lat, "lon", lon, "radius", radius)
		http.Error(w, "Ошибка получения событий", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(events)
}
