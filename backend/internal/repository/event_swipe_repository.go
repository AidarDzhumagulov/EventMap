package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type EventSwipeRepository struct {
	db *sqlx.DB
}

func NewEventSwipeRepository(db *sqlx.DB) *EventSwipeRepository {
	return &EventSwipeRepository{db: db}
}

// MarkSkipped записывает скип события юзером.
// Идемпотентно: повторный скип того же события не падает.
func (r *EventSwipeRepository) MarkSkipped(ctx context.Context, userID, eventID uuid.UUID) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO event_swipes (user_id, event_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		userID, eventID,
	)
	return err
}
