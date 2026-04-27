package repository

import (
	"database/sql"
	"errors"
	"event-map/internal/models"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

var ErrNotFound = errors.New("not found")

// базовый SELECT — явный список колонок чтобы исключить geom (PostGIS тип, несовместим с sqlx scan)
const eventSelect = `
	SELECT e.id, e.title, e.description, e.cover_url,
	       e.lat, e.lon, e.city_name,
	       e.start_time, e.end_time, e.is_private, e.status,
	       e.max_members, e.category_id, e.organization_id, e.location_id,
	       e.created_by, e.created_at, e.updated_at, e.updated_by,
	       e.deleted_at, e.deleted_by,
	       l.address AS location_address,
	       c.name_ru AS category_name,
	       c.alias   AS category_alias,
	       (SELECT COUNT(*) FROM event_members WHERE event_id = e.id AND status = 'go')::int AS members_count
	FROM events e
	LEFT JOIN locations l ON l.id = e.location_id
	LEFT JOIN categories c ON c.id = e.category_id`

// computeStatus вычисляет актуальный статус события по времени
func computeStatus(e models.Event) models.Event {
	now := time.Now()
	switch {
	case now.Before(e.StartTime):
		e.Status = "upcoming"
	case e.EndTime == nil || now.Before(*e.EndTime):
		e.Status = "ongoing"
	default:
		e.Status = "finished"
	}
	return e
}

func computeStatuses(events []models.Event) []models.Event {
	for i, e := range events {
		events[i] = computeStatus(e)
	}
	return events
}

type EventRepository struct {
	db *sqlx.DB
}

func NewEventRepository(db *sqlx.DB) *EventRepository {
	return &EventRepository{db: db}
}

func (r *EventRepository) Create(req models.CreateEventRequest, userID uuid.UUID) (models.Event, error) {
	query := `
		INSERT INTO events (
			title, description, cover_url, lat, lon, city_name,
			start_time, end_time, is_private, max_members, category_id, location_id, created_by,
			geom
		) VALUES (
			$1, $2, $3, $4, $5, $6,
			$7, $8, $9, $10, $11, $12, $13,
			ST_SetSRID(ST_MakePoint($5, $4), 4326)
		) RETURNING id`

	var id string
	err := r.db.QueryRowx(query,
		req.Title, req.Description, req.CoverURL, req.Lat, req.Lon, req.CityName,
		req.StartTime, req.EndTime, req.IsPrivate, req.MaxMembers, req.CategoryID, req.LocationID, userID,
	).Scan(&id)
	if err != nil {
		return models.Event{}, err
	}
	eventID, _ := uuid.Parse(id)
	return r.GetByID(eventID)
}

func (r *EventRepository) GetNearby(lat, lon, radiusMeters float64, limit int) ([]models.Event, error) {
	var events []models.Event
	query := eventSelect + `
		WHERE e.deleted_at IS NULL
		  AND ST_DWithin(
		        e.geom::geography,
		        ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
		        $3
		      )
		ORDER BY e.geom <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)
		LIMIT $4`
	err := r.db.Select(&events, query, lat, lon, radiusMeters, limit)
	if err != nil {
		return nil, err
	}
	return computeStatuses(events), nil
}

func (r *EventRepository) GetAll(cityName string, status string, search string, limit int, offset int) ([]models.Event, error) {
	var events []models.Event

	query := eventSelect + `
		WHERE e.deleted_at IS NULL
		  AND ($1 = '' OR e.city_name = $1)
		  AND ($2 = '' OR e.status = $2)
		  AND ($3 = '' OR e.title ILIKE '%' || $3 || '%')
		ORDER BY e.start_time ASC
		LIMIT $4 OFFSET $5`

	err := r.db.Select(&events, query, cityName, status, search, limit, offset)
	if err != nil {
		return nil, err
	}
	return computeStatuses(events), nil
}

func (r *EventRepository) GetByUserID(userID uuid.UUID) ([]models.Event, error) {
	var events []models.Event
	query := eventSelect + `
		WHERE e.deleted_at IS NULL AND e.created_by = $1
		ORDER BY e.start_time DESC`
	err := r.db.Select(&events, query, userID)
	if err != nil {
		return nil, err
	}
	return computeStatuses(events), nil
}

func (r *EventRepository) GetByID(id uuid.UUID) (models.Event, error) {
	var event models.Event
	query := eventSelect + ` WHERE e.id = $1 AND e.deleted_at IS NULL`
	err := r.db.Get(&event, query, id)
	if err != nil {
		return models.Event{}, err
	}
	return computeStatus(event), nil
}

func (r *EventRepository) Update(id uuid.UUID, req models.UpdateEventRequest, userID uuid.UUID) (models.Event, error) {
	var event models.Event
	query := `
		UPDATE events SET
			title = $1,
			description = $2,
			cover_url = COALESCE($3, cover_url),
			start_time = $4,
			end_time = $5,
			is_private = $6,
			max_members = $7,
			category_id = $8,
			updated_at = now(),
			updated_by = $9
		WHERE id = $10 AND created_by = $9 AND deleted_at IS NULL
		RETURNING *`

	err := r.db.Get(&event, query,
		req.Title, req.Description, req.CoverURL, req.StartTime, req.EndTime,
		req.IsPrivate, req.MaxMembers, req.CategoryID,
		userID, id,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return models.Event{}, ErrNotFound
		}
		return models.Event{}, err
	}
	return computeStatus(event), nil
}

func (r *EventRepository) Delete(id uuid.UUID, userID uuid.UUID) error {
	result, err := r.db.Exec(
		`UPDATE events SET deleted_at = now(), deleted_by = $1
		 WHERE id = $2 AND created_by = $1 AND deleted_at IS NULL`,
		userID, id,
	)
	if err != nil {
		return err
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}
