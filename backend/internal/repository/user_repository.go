package repository

import (
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

func (r *UserRepository) Create(user models.User) (models.User, error) {
	var created models.User
	query := `INSERT INTO users (username, role, rating, password, email)
	          VALUES ($1, $2, $3, $4, $5)
	          RETURNING id, email, username, role, rating, avatar_url`
	err := r.db.Get(&created, query, user.Username, user.Role, user.Rating, user.PasswordHash, user.Email)
	return created, err
}

func (r *UserRepository) GetByID(id uuid.UUID) (models.User, error) {
	var user models.User
	err := r.db.Get(&user, `
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

func (r *UserRepository) GetUserByEmail(email string) (models.User, error) {
	var user models.User
	query := "SELECT * FROM users WHERE email = $1"
	err := r.db.Get(&user, query, email)
	if err != nil {
		return models.User{}, err
	}
	return user, nil
}

func (r *UserRepository) IsExist(email string) bool {
	var exists bool
	err := r.db.Get(&exists, "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)", email)
	if err != nil {
		return false
	}
	return exists
}

func (r *UserRepository) IsUsernameExist(username string) bool {
	var exists bool
	err := r.db.Get(&exists, "SELECT EXISTS(SELECT 1 FROM users WHERE username = $1)", username)
	if err != nil {
		return false
	}
	return exists
}

func (r *UserRepository) IsUsernameTakenByOther(username string, userID uuid.UUID) bool {
	var exists bool
	err := r.db.Get(&exists,
		"SELECT EXISTS(SELECT 1 FROM users WHERE username = $1 AND id != $2)",
		username, userID,
	)
	if err != nil {
		return false
	}
	return exists
}

func (r *UserRepository) Update(id uuid.UUID, username string, avatarURL *string) (models.User, error) {
	var user models.User
	err := r.db.Get(&user,
		"UPDATE users SET username = $1, avatar_url = COALESCE($2, avatar_url) WHERE id = $3 RETURNING id, email, username, role, rating, avatar_url",
		username, avatarURL, id,
	)
	return user, err
}
