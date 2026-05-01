package service

import (
	"context"
	"errors"
	"event-map/internal/models"
	"event-map/internal/repository"
	"fmt"

	"github.com/google/uuid"
)

// Event-доменные ошибки.
var (
	ErrEventNotFound = errors.New("event not found")
	// ErrEventNotOwned возвращается когда юзер пытается изменить чужое событие.
	// HTTP-код для неё — 403 Forbidden, чтобы не палить существование чужих событий.
	ErrEventNotOwned = errors.New("event not owned by user")
)

const (
	maxEventsPerPage    = 200
	maxFeedSize         = 100
	defaultFeedSize     = 40
	maxNearbyResults    = 200
	defaultRadiusMeters = 5000.0
)

type EventService struct {
	events *repository.EventRepository
	swipes *repository.EventSwipeRepository
	saved  *repository.SavedEventRepository
}

func NewEventService(
	events *repository.EventRepository,
	swipes *repository.EventSwipeRepository,
	saved *repository.SavedEventRepository,
) *EventService {
	return &EventService{events: events, swipes: swipes, saved: saved}
}

// CreateEvent — валидирует и создаёт событие. userID = создатель.
func (s *EventService) CreateEvent(ctx context.Context, req models.CreateEventRequest, userID uuid.UUID) (models.Event, error) {
	if req.Title == "" || req.CityName == "" || req.StartTime.IsZero() {
		return models.Event{}, fmt.Errorf("%w: title, city_name, start_time обязательны", ErrInvalidInput)
	}
	if req.Lat < -90 || req.Lat > 90 || req.Lon < -180 || req.Lon > 180 {
		return models.Event{}, fmt.Errorf("%w: невалидные координаты", ErrInvalidInput)
	}

	event, err := s.events.Create(ctx, req, userID)
	if err != nil {
		return models.Event{}, fmt.Errorf("create event: %w", err)
	}
	return event, nil
}

// UpdateEvent — обновление. Только владелец события может менять.
// Repo уже проверяет created_by = userID в WHERE — service оборачивает sql.ErrNoRows
// в ErrEventNotOwned (для семантичных HTTP-ответов).
func (s *EventService) UpdateEvent(ctx context.Context, id uuid.UUID, req models.UpdateEventRequest, userID uuid.UUID) (models.Event, error) {
	if req.Title == "" {
		return models.Event{}, fmt.Errorf("%w: title обязателен", ErrInvalidInput)
	}

	event, err := s.events.Update(ctx, id, req, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return models.Event{}, ErrEventNotOwned
		}
		return models.Event{}, fmt.Errorf("update event: %w", err)
	}
	return event, nil
}

// DeleteEvent — soft delete. Только владелец.
func (s *EventService) DeleteEvent(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	if err := s.events.Delete(ctx, id, userID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return ErrEventNotOwned
		}
		return fmt.Errorf("delete event: %w", err)
	}
	return nil
}

// GetEvent — получение по ID.
func (s *EventService) GetEvent(ctx context.Context, id uuid.UUID) (models.Event, error) {
	event, err := s.events.GetByID(ctx, id)
	if err != nil {
		// Для GetByID любая ошибка обычно означает "не найден" (включая sql.ErrNoRows
		// и логические ошибки). Repo не выделяет sentinel здесь — оборачиваем сами.
		return models.Event{}, ErrEventNotFound
	}
	return event, nil
}

// EventListParams — параметры списочных запросов с лимитами.
type EventListParams struct {
	City   string
	Status string
	Search string
	Limit  int
	Offset int
}

// GetEvents — список событий с фильтрами. Лимиты безопасности зашиваем здесь.
func (s *EventService) GetEvents(ctx context.Context, p EventListParams) ([]models.Event, error) {
	limit := p.Limit
	if limit <= 0 {
		limit = 100
	}
	limit = min(limit, maxEventsPerPage)
	offset := max(p.Offset, 0)

	events, err := s.events.GetAll(ctx, p.City, p.Status, p.Search, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("get events: %w", err)
	}
	return events, nil
}

// GetMyEvents — события созданные юзером.
func (s *EventService) GetMyEvents(ctx context.Context, userID uuid.UUID) ([]models.Event, error) {
	events, err := s.events.GetByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get my events: %w", err)
	}
	return events, nil
}

// GetFeed — стопка для свайп-ленты. city обязателен.
func (s *EventService) GetFeed(ctx context.Context, userID uuid.UUID, city string, limit int) ([]models.Event, error) {
	if city == "" {
		return nil, fmt.Errorf("%w: city обязателен", ErrInvalidInput)
	}
	if limit <= 0 {
		limit = defaultFeedSize
	}
	limit = min(limit, maxFeedSize)

	events, err := s.events.GetFeed(ctx, userID, city, limit)
	if err != nil {
		return nil, fmt.Errorf("get feed: %w", err)
	}
	return events, nil
}

// GetNearby — гео-поиск.
func (s *EventService) GetNearby(ctx context.Context, lat, lon, radiusMeters float64, limit int) ([]models.Event, error) {
	if lat < -90 || lat > 90 || lon < -180 || lon > 180 {
		return nil, fmt.Errorf("%w: невалидные координаты", ErrInvalidInput)
	}
	if radiusMeters <= 0 {
		radiusMeters = defaultRadiusMeters
	}
	if limit <= 0 {
		limit = 50
	}
	limit = min(limit, maxNearbyResults)

	events, err := s.events.GetNearby(ctx, lat, lon, radiusMeters, limit)
	if err != nil {
		return nil, fmt.Errorf("get nearby: %w", err)
	}
	return events, nil
}

// SkipEvent — пометить событие как скипнутое (анти-повтор в свайп-ленте).
// Идемпотентно.
func (s *EventService) SkipEvent(ctx context.Context, userID, eventID uuid.UUID) error {
	if err := s.swipes.MarkSkipped(ctx, userID, eventID); err != nil {
		return fmt.Errorf("mark skipped: %w", err)
	}
	return nil
}

// SaveEvent — сохранить в избранное. Идемпотентно.
func (s *EventService) SaveEvent(ctx context.Context, userID, eventID uuid.UUID) error {
	if err := s.saved.Save(ctx, eventID, userID); err != nil {
		return fmt.Errorf("save event: %w", err)
	}
	return nil
}

// UnsaveEvent — убрать из избранного. Идемпотентно.
func (s *EventService) UnsaveEvent(ctx context.Context, userID, eventID uuid.UUID) error {
	if err := s.saved.Unsave(ctx, eventID, userID); err != nil {
		return fmt.Errorf("unsave event: %w", err)
	}
	return nil
}

// IsEventSaved — проверка одного события. Используется для UI индикатора.
func (s *EventService) IsEventSaved(ctx context.Context, userID, eventID uuid.UUID) (bool, error) {
	saved, err := s.saved.IsSaved(ctx, eventID, userID)
	if err != nil {
		return false, fmt.Errorf("is saved: %w", err)
	}
	return saved, nil
}

// GetSavedEvents — список сохранённых событий юзера.
func (s *EventService) GetSavedEvents(ctx context.Context, userID uuid.UUID) ([]models.Event, error) {
	events, err := s.saved.GetSavedByUser(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get saved events: %w", err)
	}
	return events, nil
}
