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
	query := "INSERT INTO users (username, role, rating, password, email) VALUES ($1, $2, $3, $4, $5)"
	_, err := r.db.Exec(query, user.Username, user.Role, user.Rating, user.PasswordHash, user.Email)
	if err != nil {
		return err
	}
	return nil
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

	query := "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)"
	err := r.db.Get(&exists, query, email)

	if err != nil {
		return false
	}
	return exists

}
