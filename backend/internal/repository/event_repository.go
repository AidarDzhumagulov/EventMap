package repository

import (
	"context"
	"crypto/rand"
	"database/sql"
	"errors"
	"event-map/internal/models"
	"math/big"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

const inviteCodeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

func generateInviteCode() string {
	code := make([]byte, 6)
	for i := range code {
		n, _ := rand.Int(rand.Reader, big.NewInt(int64(len(inviteCodeChars))))
		code[i] = inviteCodeChars[n.Int64()]
	}
	return string(code)
}

// escapeLikePattern экранирует специальные символы LIKE/ILIKE.
// Без этого юзер может прислать "100%" и получить "найти всё что содержит 100"
// вместо буквального поиска "100%". Также защищает от ReDoS-подобных паттернов.
func escapeLikePattern(s string) string {
	r := strings.NewReplacer(
		`\`, `\\`,
		`%`, `\%`,
		`_`, `\_`,
	)
	return r.Replace(s)
}

var ErrNotFound = errors.New("not found")

// базовый SELECT — явный список колонок чтобы исключить geom (PostGIS тип, несовместим с sqlx scan).
//
// Performance: members_count считается через JOIN с GROUP BY-подзапросом, а не
// корреллированный subquery на каждое событие. На странице с N событиями это
// 1 hash-aggregate вместо N COUNT-ов. Без триггеров и денормализации.
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
	       e.invite_code,
	       COALESCE(mc.cnt, 0)::int AS members_count
	FROM events e
	LEFT JOIN locations l ON l.id = e.location_id
	LEFT JOIN categories c ON c.id = e.category_id
	LEFT JOIN (
	    SELECT event_id, COUNT(*) AS cnt
	    FROM event_members
	    WHERE status = 'go'
	    GROUP BY event_id
	) mc ON mc.event_id = e.id`

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

func (r *EventRepository) Create(ctx context.Context, req models.CreateEventRequest, userID uuid.UUID) (models.Event, error) {
	var inviteCode *string
	if req.IsPrivate {
		code := generateInviteCode()
		inviteCode = &code
	}

	query := `
		INSERT INTO events (
			title, description, cover_url, lat, lon, city_name,
			start_time, end_time, is_private, max_members, category_id, location_id, created_by,
			invite_code, geom
		) VALUES (
			$1, $2, $3, $4, $5, $6,
			$7, $8, $9, $10, $11, $12, $13,
			$14, ST_SetSRID(ST_MakePoint($5, $4), 4326)
		) RETURNING id`

	var id string
	err := r.db.QueryRowxContext(ctx, query,
		req.Title, req.Description, req.CoverURL, req.Lat, req.Lon, req.CityName,
		req.StartTime, req.EndTime, req.IsPrivate, req.MaxMembers, req.CategoryID, req.LocationID, userID,
		inviteCode,
	).Scan(&id)
	if err != nil {
		return models.Event{}, err
	}
	eventID, _ := uuid.Parse(id)
	return r.GetByID(ctx, eventID)
}

func (r *EventRepository) GetByInviteCode(ctx context.Context, code string) (models.Event, error) {
	var event models.Event
	query := eventSelect + ` WHERE e.invite_code = $1 AND e.deleted_at IS NULL`
	err := r.db.GetContext(ctx, &event, query, code)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return models.Event{}, ErrNotFound
		}
		return models.Event{}, err
	}
	return computeStatus(event), nil
}

func (r *EventRepository) GetNearby(ctx context.Context, lat, lon, radiusMeters float64, limit int) ([]models.Event, error) {
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
	err := r.db.SelectContext(ctx, &events, query, lat, lon, radiusMeters, limit)
	if err != nil {
		return nil, err
	}
	return computeStatuses(events), nil
}

func (r *EventRepository) GetAll(ctx context.Context, cityName string, status string, search string, limit int, offset int) ([]models.Event, error) {
	var events []models.Event

	// Экранируем LIKE-метасимволы — иначе "100%" в search означает "что угодно".
	safeSearch := escapeLikePattern(search)

	query := eventSelect + `
		WHERE e.deleted_at IS NULL
		  AND ($1 = '' OR e.city_name = $1)
		  AND ($2 = '' OR e.status = $2)
		  AND ($3 = '' OR e.title ILIKE '%' || $3 || '%' ESCAPE '\')
		ORDER BY e.start_time ASC
		LIMIT $4 OFFSET $5`

	err := r.db.SelectContext(ctx, &events, query, cityName, status, safeSearch, limit, offset)
	if err != nil {
		return nil, err
	}
	return computeStatuses(events), nil
}

func (r *EventRepository) GetByUserID(ctx context.Context, userID uuid.UUID) ([]models.Event, error) {
	var events []models.Event
	query := eventSelect + `
		WHERE e.deleted_at IS NULL AND e.created_by = $1
		ORDER BY e.start_time DESC`
	err := r.db.SelectContext(ctx, &events, query, userID)
	if err != nil {
		return nil, err
	}
	return computeStatuses(events), nil
}

func (r *EventRepository) GetByID(ctx context.Context, id uuid.UUID) (models.Event, error) {
	var event models.Event
	query := eventSelect + ` WHERE e.id = $1 AND e.deleted_at IS NULL`
	err := r.db.GetContext(ctx, &event, query, id)
	if err != nil {
		return models.Event{}, err
	}
	return computeStatus(event), nil
}

// GetFeed — стопка событий для свайп-ленты (Tinder-механика).
// Фильтры:
//  1. город совпадает;
//  2. событие ещё не закончилось;
//  3. публичное (приватные не должны утекать в общую ленту);
//  4. юзер ещё не взаимодействовал — нет в saved_events / event_members / event_swipes;
//  5. не он сам создатель.
//
// Сортировка ORDER BY RANDOM() для разнообразия. На больших таблицах
// можно будет заменить на TABLESAMPLE — пока MVP, города < 10k событий.
func (r *EventRepository) GetFeed(ctx context.Context, userID uuid.UUID, cityName string, limit int) ([]models.Event, error) {
	events := make([]models.Event, 0)
	query := eventSelect + `
		WHERE e.deleted_at IS NULL
		  AND e.is_private = false
		  AND e.city_name = $1
		  AND e.created_by <> $2
		  AND (e.end_time IS NULL OR e.end_time >= NOW())
		  AND e.start_time >= NOW() - INTERVAL '6 hours'
		  AND NOT EXISTS (
		      SELECT 1 FROM saved_events s
		      WHERE s.event_id = e.id AND s.user_id = $2
		  )
		  AND NOT EXISTS (
		      SELECT 1 FROM event_members m
		      WHERE m.event_id = e.id AND m.user_id = $2
		  )
		  AND NOT EXISTS (
		      SELECT 1 FROM event_swipes sw
		      WHERE sw.event_id = e.id AND sw.user_id = $2
		  )
		ORDER BY RANDOM()
		LIMIT $3`

	err := r.db.SelectContext(ctx, &events, query, cityName, userID, limit)
	if err != nil {
		return nil, err
	}
	return computeStatuses(events), nil
}

func (r *EventRepository) Update(ctx context.Context, id uuid.UUID, req models.UpdateEventRequest, userID uuid.UUID) (models.Event, error) {
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
		RETURNING id`

	var updatedID string
	err := r.db.QueryRowxContext(ctx, query,
		req.Title, req.Description, req.CoverURL, req.StartTime, req.EndTime,
		req.IsPrivate, req.MaxMembers, req.CategoryID,
		userID, id,
	).Scan(&updatedID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return models.Event{}, ErrNotFound
		}
		return models.Event{}, err
	}
	eventID, _ := uuid.Parse(updatedID)
	return r.GetByID(ctx, eventID)
}

func (r *EventRepository) Delete(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	result, err := r.db.ExecContext(ctx,
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
