package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type EmailVerificationRepository struct {
	db *sqlx.DB
}

func NewEmailVerificationRepository(db *sqlx.DB) *EmailVerificationRepository {
	return &EmailVerificationRepository{db: db}
}

func (r *EmailVerificationRepository) Insert(ctx context.Context, token string, userID uuid.UUID, expiresAt time.Time) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO email_verification_tokens (token, user_id, expires_at) VALUES ($1, $2, $3)`,
		token, userID, expiresAt,
	)
	return err
}

// Consume — атомарно проверяет токен, помечает email_verified=true и удаляет токен.
// Возвращает ErrNotFound если токен не существует / истёк.
func (r *EmailVerificationRepository) Consume(ctx context.Context, token string) (uuid.UUID, error) {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return uuid.Nil, err
	}
	defer func() { _ = tx.Rollback() }()

	var userID uuid.UUID
	var expiresAt time.Time
	err = tx.QueryRowxContext(ctx,
		`SELECT user_id, expires_at FROM email_verification_tokens WHERE token = $1`,
		token,
	).Scan(&userID, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return uuid.Nil, ErrNotFound
	}
	if err != nil {
		return uuid.Nil, err
	}
	if time.Now().After(expiresAt) {
		return uuid.Nil, ErrNotFound
	}

	if _, err := tx.ExecContext(ctx,
		`UPDATE users SET email_verified = true WHERE id = $1`, userID,
	); err != nil {
		return uuid.Nil, err
	}

	// Удаляем все токены этого юзера — лишние больше не нужны.
	if _, err := tx.ExecContext(ctx,
		`DELETE FROM email_verification_tokens WHERE user_id = $1`, userID,
	); err != nil {
		return uuid.Nil, err
	}

	if err := tx.Commit(); err != nil {
		return uuid.Nil, err
	}
	return userID, nil
}

// DeleteForUser — удаляет все токены юзера (например при resend-verification).
func (r *EmailVerificationRepository) DeleteForUser(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.ExecContext(ctx,
		`DELETE FROM email_verification_tokens WHERE user_id = $1`, userID,
	)
	return err
}

// CleanupExpired — удаляет протухшие. Запускать в фоне раз в сутки.
func (r *EmailVerificationRepository) CleanupExpired(ctx context.Context) (int64, error) {
	res, err := r.db.ExecContext(ctx,
		`DELETE FROM email_verification_tokens WHERE expires_at < now()`,
	)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}
