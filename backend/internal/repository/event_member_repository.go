package repository

import (
	"errors"
	"event-map/internal/models"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

// ErrEventFull — событие уже заполнено, новый участник не помещается.
// Возвращается атомарной операцией JoinAtomic.
var ErrEventFull = errors.New("event is full")

type EventMemberRepository struct {
	db *sqlx.DB
}

func NewEventMemberRepository(db *sqlx.DB) *EventMemberRepository {
	return &EventMemberRepository{db: db}
}

// JoinAtomic — атомарная запись на событие с проверкой лимита мест.
// Решает race condition: между check max_members и INSERT не может вклиниться
// другой клиент. SELECT ... FOR UPDATE блокирует строку events до COMMIT.
//
// Возвращает ErrEventFull если status='go' и max_members уже забит
// (и юзер ещё не имеет статус 'go' — смена своего же 'go' → 'go' проходит).
func (r *EventMemberRepository) JoinAtomic(eventID, userID uuid.UUID, status string) (models.EventMember, error) {
	tx, err := r.db.Beginx()
	if err != nil {
		return models.EventMember{}, err
	}
	defer func() { _ = tx.Rollback() }()

	// Лочим строку events до конца транзакции — параллельные Join будут ждать.
	var maxMembers *int
	err = tx.Get(&maxMembers,
		"SELECT max_members FROM events WHERE id = $1 AND deleted_at IS NULL FOR UPDATE",
		eventID,
	)
	if err != nil {
		return models.EventMember{}, err
	}

	// Проверяем лимит только если хотим занять место и ещё не занимали.
	if status == "go" && maxMembers != nil {
		var currentStatus string
		_ = tx.Get(&currentStatus,
			"SELECT status FROM event_members WHERE event_id = $1 AND user_id = $2",
			eventID, userID,
		)
		if currentStatus != "go" {
			var count int
			if err := tx.Get(&count,
				"SELECT COUNT(*) FROM event_members WHERE event_id = $1 AND status = 'go'",
				eventID,
			); err != nil {
				return models.EventMember{}, err
			}
			if count >= *maxMembers {
				return models.EventMember{}, ErrEventFull
			}
		}
	}

	var member models.EventMember
	err = tx.Get(&member, `
		INSERT INTO event_members (event_id, user_id, status)
		VALUES ($1, $2, $3)
		ON CONFLICT (event_id, user_id) DO UPDATE SET status = $3
		RETURNING *`,
		eventID, userID, status,
	)
	if err != nil {
		return models.EventMember{}, err
	}

	if err := tx.Commit(); err != nil {
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
		"SELECT COUNT(*) FROM event_members WHERE event_id = $1 AND status = 'go'",
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
