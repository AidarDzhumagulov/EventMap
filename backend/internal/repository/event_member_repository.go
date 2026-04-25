package repository

import (
	"event-map/internal/models"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type EventMemberRepository struct {
	db *sqlx.DB
}

func NewEventMemberRepository(db *sqlx.DB) *EventMemberRepository {
	return &EventMemberRepository{db: db}
}

func (r *EventMemberRepository) Join(eventID, userID uuid.UUID, status string) (models.EventMember, error) {
	var member models.EventMember
	query := `
		INSERT INTO event_members (event_id, user_id, status)
		VALUES ($1, $2, $3)
		ON CONFLICT (event_id, user_id) DO UPDATE SET status = $3
		RETURNING *`
	err := r.db.Get(&member, query, eventID, userID, status)
	if err != nil {
		return models.EventMember{}, err
	}
	return member, nil
}

func (r *EventMemberRepository) Leave(eventID, userID uuid.UUID) error {
	_, err := r.db.Exec(
		"DELETE FROM event_members WHERE event_id = $1 AND user_id = $2",
		eventID, userID,
	)
	return err
}

func (r *EventMemberRepository) IsMember(eventID, userID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.Get(&exists,
		"SELECT EXISTS(SELECT 1 FROM event_members WHERE event_id = $1 AND user_id = $2)",
		eventID, userID,
	)
	return exists, err
}

func (r *EventMemberRepository) GetStatus(eventID, userID uuid.UUID) (string, error) {
	var status string
	err := r.db.Get(&status,
		"SELECT status FROM event_members WHERE event_id = $1 AND user_id = $2",
		eventID, userID,
	)
	return status, err
}

func (r *EventMemberRepository) CountMembers(eventID uuid.UUID) (int, error) {
	var count int
	err := r.db.Get(&count,
		"SELECT COUNT(*) FROM event_members WHERE event_id = $1",
		eventID,
	)
	return count, err
}

func (r *EventMemberRepository) GetMembers(eventID uuid.UUID) ([]models.EventMemberUser, error) {
	members := make([]models.EventMemberUser, 0)
	query := `
		SELECT em.user_id, u.username, em.status
		FROM event_members em
		JOIN users u ON u.id = em.user_id
		WHERE em.event_id = $1
		ORDER BY em.status, u.username`
	err := r.db.Select(&members, query, eventID)
	return members, err
}
