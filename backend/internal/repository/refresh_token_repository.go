package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

// Sentinel-ошибки для разных причин невалидности refresh-токена.
var (
	ErrTokenNotFound = errors.New("refresh token not found")
	ErrTokenRevoked  = errors.New("refresh token revoked")
	ErrTokenExpired  = errors.New("refresh token expired")
	ErrTokenReused   = errors.New("refresh token reuse detected")
)

type RefreshToken struct {
	JTI       uuid.UUID    `db:"jti"`
	FamilyID  uuid.UUID    `db:"family_id"`
	UserID    uuid.UUID    `db:"user_id"`
	IssuedAt  time.Time    `db:"issued_at"`
	ExpiresAt time.Time    `db:"expires_at"`
	UsedAt    sql.NullTime `db:"used_at"`
	RevokedAt sql.NullTime `db:"revoked_at"`
}

type RefreshTokenRepository struct {
	db *sqlx.DB
}

func NewRefreshTokenRepository(db *sqlx.DB) *RefreshTokenRepository {
	return &RefreshTokenRepository{db: db}
}

// Insert — записываем новый refresh-токен (на login или на rotation).
func (r *RefreshTokenRepository) Insert(ctx context.Context, jti, familyID, userID uuid.UUID, expiresAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO refresh_tokens (jti, family_id, user_id, expires_at)
		VALUES ($1, $2, $3, $4)`,
		jti, familyID, userID, expiresAt,
	)
	return err
}

// Rotate — атомарно проверяет старый токен и создаёт новый.
//
// Возвращает:
//   - ErrTokenNotFound: токен с таким jti отсутствует (подделка либо уже почищен)
//   - ErrTokenRevoked:  семья была отозвана (через logout или reuse-detection)
//   - ErrTokenExpired:  истёк срок жизни
//   - ErrTokenReused:   токен уже использован — это атака, отзываем всю family
//
// При reuse транзакция помечает revoked_at для всей family — все их рефреши
// мёртвые. Юзер должен залогиниться заново.
func (r *RefreshTokenRepository) Rotate(
	ctx context.Context,
	oldJTI, oldFamilyID, oldUserID uuid.UUID,
	newJTI uuid.UUID,
	newExpiresAt time.Time,
) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	// Лочим строку, чтобы параллельный refresh не подсунул race condition.
	var token RefreshToken
	err = tx.GetContext(ctx, &token,
		`SELECT * FROM refresh_tokens WHERE jti = $1 FOR UPDATE`,
		oldJTI,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrTokenNotFound
	}
	if err != nil {
		return err
	}

	// Защита от подмены user_id в JWT (если злоумышленник как-то подделал).
	if token.UserID != oldUserID || token.FamilyID != oldFamilyID {
		return ErrTokenNotFound
	}

	if token.RevokedAt.Valid {
		return ErrTokenRevoked
	}
	if time.Now().After(token.ExpiresAt) {
		return ErrTokenExpired
	}

	if token.UsedAt.Valid {
		// Reuse-detection: токен уже использован, кто-то пробует ещё раз.
		// Отзываем всю family — рефреши и юзера, и атакующего становятся мёртвыми.
		if _, err := tx.ExecContext(ctx,
			`UPDATE refresh_tokens SET revoked_at = now()
			 WHERE family_id = $1 AND revoked_at IS NULL`,
			token.FamilyID,
		); err != nil {
			return err
		}
		if err := tx.Commit(); err != nil {
			return err
		}
		return ErrTokenReused
	}

	// Помечаем старый использованным и записываем новый в ту же family.
	if _, err := tx.ExecContext(ctx,
		`UPDATE refresh_tokens SET used_at = now() WHERE jti = $1`,
		oldJTI,
	); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO refresh_tokens (jti, family_id, user_id, expires_at)
		VALUES ($1, $2, $3, $4)`,
		newJTI, token.FamilyID, token.UserID, newExpiresAt,
	); err != nil {
		return err
	}

	return tx.Commit()
}

// RevokeFamily — отзывает все токены одной сессии (logout с одного устройства).
func (r *RefreshTokenRepository) RevokeFamily(ctx context.Context, familyID uuid.UUID) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE refresh_tokens SET revoked_at = now()
		 WHERE family_id = $1 AND revoked_at IS NULL`,
		familyID,
	)
	return err
}

// RevokeAllForUser — отзывает все сессии юзера (logout со всех устройств).
func (r *RefreshTokenRepository) RevokeAllForUser(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE refresh_tokens SET revoked_at = now()
		 WHERE user_id = $1 AND revoked_at IS NULL`,
		userID,
	)
	return err
}

// CleanupExpired — удаляет протухшие токены. Запускать раз в сутки фоновым джобом.
// Без этого таблица растёт бесконечно.
func (r *RefreshTokenRepository) CleanupExpired(ctx context.Context) (int64, error) {
	res, err := r.db.ExecContext(ctx,
		`DELETE FROM refresh_tokens WHERE expires_at < now() - INTERVAL '7 days'`,
	)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}
