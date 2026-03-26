package repository

import (
	"event-map/internal/models"

	"github.com/jmoiron/sqlx"
)

type UserRepository struct {
	db *sqlx.DB
}

func NewUserRepository(db *sqlx.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(user models.User) error {
	_, err := r.db.Exec("INSERT INTO users (username, role, rating, password) VALUES ($1, $2, $3, $4)", user.Username, user.Role, user.Rating, user.PasswordHash)
	if err != nil {
		return err
	}
	return nil
}

func (r *UserRepository) GetByUsername(username string) (models.User, error) {
	var user models.User
	err := r.db.Get(&user, "SELECT * FROM users WHERE username = $1", username)
	if err != nil {
		return models.User{}, err
	}
	return user, nil
}
