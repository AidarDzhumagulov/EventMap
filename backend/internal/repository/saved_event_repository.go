package repository

import (
	"context"
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

func (r *SavedEventRepository) Save(ctx context.Context, eventID, userID uuid.UUID) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO saved_events (event_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		eventID, userID,
	)
	return err
}

func (r *SavedEventRepository) Unsave(ctx context.Context, eventID, userID uuid.UUID) error {
	_, err := r.db.ExecContext(ctx,
		`DELETE FROM saved_events WHERE event_id = $1 AND user_id = $2`,
		eventID, userID,
	)
	return err
}

func (r *SavedEventRepository) IsSaved(ctx context.Context, eventID, userID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.GetContext(ctx, &exists,
		`SELECT EXISTS(SELECT 1 FROM saved_events WHERE event_id = $1 AND user_id = $2)`,
		eventID, userID,
	)
	return exists, err
}

func (r *SavedEventRepository) GetSavedByUser(ctx context.Context, userID uuid.UUID) ([]models.Event, error) {
	events := make([]models.Event, 0)
	query := eventSelect + `
		JOIN saved_events s ON s.event_id = e.id
		WHERE s.user_id = $1 AND e.deleted_at IS NULL
		ORDER BY s.saved_at DESC`
	err := r.db.SelectContext(ctx, &events, query, userID)
	if err != nil {
		return nil, err
	}
	return computeStatuses(events), nil
}
