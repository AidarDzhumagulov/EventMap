package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type PasswordResetRepository struct {
	db *sqlx.DB
}

func NewPasswordResetRepository(db *sqlx.DB) *PasswordResetRepository {
	return &PasswordResetRepository{db: db}
}

func (r *PasswordResetRepository) Insert(ctx context.Context, token string, userID uuid.UUID, expiresAt time.Time) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO password_reset_tokens (token, user_id, expires_at) VALUES ($1, $2, $3)`,
		token, userID, expiresAt,
	)
	return err
}

// Consume — атомарно проверяет токен и помечает used_at.
// Возвращает user_id если успешно, ErrNotFound в остальных случаях.
//
// Не удаляет токен (а помечает used_at) чтобы при повторной попытке
// не было false negative "не найден" — будет понятный фейл "уже использован".
func (r *PasswordResetRepository) Consume(ctx context.Context, token string) (uuid.UUID, error) {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return uuid.Nil, err
	}
	defer func() { _ = tx.Rollback() }()

	var userID uuid.UUID
	var expiresAt time.Time
	var usedAt sql.NullTime
	err = tx.QueryRowxContext(ctx,
		`SELECT user_id, expires_at, used_at FROM password_reset_tokens
		 WHERE token = $1 FOR UPDATE`,
		token,
	).Scan(&userID, &expiresAt, &usedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return uuid.Nil, ErrNotFound
	}
	if err != nil {
		return uuid.Nil, err
	}
	if usedAt.Valid {
		return uuid.Nil, ErrNotFound
	}
	if time.Now().After(expiresAt) {
		return uuid.Nil, ErrNotFound
	}

	if _, err := tx.ExecContext(ctx,
		`UPDATE password_reset_tokens SET used_at = now() WHERE token = $1`, token,
	); err != nil {
		return uuid.Nil, err
	}

	if err := tx.Commit(); err != nil {
		return uuid.Nil, err
	}
	return userID, nil
}

// DeleteForUser — на случай повторного request-reset, чтобы старые токены не накапливались.
func (r *PasswordResetRepository) DeleteForUser(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.ExecContext(ctx,
		`DELETE FROM password_reset_tokens WHERE user_id = $1`, userID,
	)
	return err
}

// CleanupExpired — удаляет протухшие токены. В фон раз в сутки.
func (r *PasswordResetRepository) CleanupExpired(ctx context.Context) (int64, error) {
	res, err := r.db.ExecContext(ctx,
		`DELETE FROM password_reset_tokens WHERE expires_at < now() OR used_at < now() - INTERVAL '7 days'`,
	)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}
