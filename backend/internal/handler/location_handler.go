package handler

import (
	"encoding/json"
	"event-map/internal/models"
	"event-map/internal/repository"
	"net/http"
)

type LocationHandler struct {
	locationRepo *repository.LocationRepository
}

func NewLocationHandler(locationRepo *repository.LocationRepository) *LocationHandler {
	return &LocationHandler{locationRepo: locationRepo}
}

func (h *LocationHandler) CreateLocation(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	var req models.CreateLocationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	if req.Lat == 0 || req.Lon == 0 {
		http.Error(w, "lat и lon обязательны", http.StatusBadRequest)
		return
	}

	if req.Provider == "" {
		req.Provider = "nominatim"
	}

	loc, err := h.locationRepo.Create(r.Context(), req)
	if err != nil {
		http.Error(w, "Ошибка создания локации", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(loc)
}
