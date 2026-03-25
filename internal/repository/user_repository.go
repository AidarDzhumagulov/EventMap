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
	_, err := r.db.Exec("INSERT INTO users (username, role, rating) VALUES ($1, $2, $3)", user.Username, user.Role, user.Rating)
	if err != nil {
		return err
	}
	return nil
}
