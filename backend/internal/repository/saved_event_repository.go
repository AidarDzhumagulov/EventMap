package repository

import (
	"event-map/internal/models"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type SavedEventRepository struct {
	db *sqlx.DB
}

func NewSavedEventRepository(db *sqlx.DB) *SavedEventRepository {
	return &SavedEventRepository{db: db}
}

func (r *SavedEventRepository) Save(eventID, userID uuid.UUID) error {
	_, err := r.db.Exec(
		`INSERT INTO saved_events (event_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		eventID, userID,
	)
	return err
}

func (r *SavedEventRepository) Unsave(eventID, userID uuid.UUID) error {
	_, err := r.db.Exec(
		`DELETE FROM saved_events WHERE event_id = $1 AND user_id = $2`,
		eventID, userID,
	)
	return err
}

func (r *SavedEventRepository) IsSaved(eventID, userID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.Get(&exists,
		`SELECT EXISTS(SELECT 1 FROM saved_events WHERE event_id = $1 AND user_id = $2)`,
		eventID, userID,
	)
	return exists, err
}

func (r *SavedEventRepository) GetSavedByUser(userID uuid.UUID) ([]models.Event, error) {
	events := make([]models.Event, 0)
	err := r.db.Select(&events, `
		SELECT e.* FROM events e
		JOIN saved_events s ON s.event_id = e.id
		WHERE s.user_id = $1 AND e.deleted_at IS NULL
		ORDER BY s.saved_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	return events, nil
}
