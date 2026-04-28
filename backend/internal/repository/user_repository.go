package repository

import (
	"context"
	"event-map/internal/models"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type UserRepository struct {
	db *sqlx.DB
}

func NewUserRepository(db *sqlx.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(ctx context.Context, user models.User) (models.User, error) {
	var created models.User
	query := `INSERT INTO users (username, role, rating, password, email)
	          VALUES ($1, $2, $3, $4, $5)
	          RETURNING id, email, username, role, rating, avatar_url`
	err := r.db.GetContext(ctx, &created, query, user.Username, user.Role, user.Rating, user.PasswordHash, user.Email)
	return created, err
}

func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (models.User, error) {
	var user models.User
	err := r.db.GetContext(ctx, &user, `
		SELECT u.id, u.email, u.username, u.role, u.avatar_url,
		    COALESCE((
		        SELECT COUNT(em.user_id)::float
		        FROM events e
		        JOIN event_members em ON em.event_id = e.id AND em.status = 'go'
		        WHERE e.created_by = u.id
		          AND e.deleted_at IS NULL
		          AND now() > COALESCE(e.end_time, e.start_time + INTERVAL '2 hours')
		    ), 0) AS rating
		FROM users u
		WHERE u.id = $1`, id)
	return user, err
}

func (r *UserRepository) GetUserByEmail(ctx context.Context, email string) (models.User, error) {
	var user models.User
	err := r.db.GetContext(ctx, &user, "SELECT * FROM users WHERE email = $1", email)
	if err != nil {
		return models.User{}, err
	}
	return user, nil
}

func (r *UserRepository) IsExist(ctx context.Context, email string) bool {
	var exists bool
	err := r.db.GetContext(ctx, &exists, "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)", email)
	if err != nil {
		return false
	}
	return exists
}

func (r *UserRepository) IsUsernameExist(ctx context.Context, username string) bool {
	var exists bool
	err := r.db.GetContext(ctx, &exists, "SELECT EXISTS(SELECT 1 FROM users WHERE username = $1)", username)
	if err != nil {
		return false
	}
	return exists
}

func (r *UserRepository) IsUsernameTakenByOther(ctx context.Context, username string, userID uuid.UUID) bool {
	var exists bool
	err := r.db.GetContext(ctx, &exists,
		"SELECT EXISTS(SELECT 1 FROM users WHERE username = $1 AND id != $2)",
		username, userID,
	)
	if err != nil {
		return false
	}
	return exists
}

func (r *UserRepository) Update(ctx context.Context, id uuid.UUID, username string, avatarURL *string) (models.User, error) {
	var user models.User
	err := r.db.GetContext(ctx, &user,
		"UPDATE users SET username = $1, avatar_url = COALESCE($2, avatar_url) WHERE id = $3 RETURNING id, email, username, role, rating, avatar_url",
		username, avatarURL, id,
	)
	return user, err
}

// UpdatePassword — для lazy миграции старых SHA256+bcrypt хэшей на чистый bcrypt
// при первом успешном логине, и для смены пароля юзером.
func (r *UserRepository) UpdatePassword(ctx context.Context, id uuid.UUID, newHash string) error {
	_, err := r.db.ExecContext(ctx, "UPDATE users SET password = $1 WHERE id = $2", newHash, id)
	return err
}
