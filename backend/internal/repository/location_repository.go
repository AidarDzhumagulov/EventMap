package repository

import (
	"context"
	"event-map/internal/models"

	"github.com/jmoiron/sqlx"
)

type LocationRepository struct {
	db *sqlx.DB
}

func NewLocationRepository(db *sqlx.DB) *LocationRepository {
	return &LocationRepository{db: db}
}

func (r *LocationRepository) Create(ctx context.Context, req models.CreateLocationRequest) (models.Location, error) {
	var loc models.Location
	err := r.db.GetContext(ctx, &loc, `
		INSERT INTO locations (lat, lon, address, name, provider, external_id)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING *`,
		req.Lat, req.Lon, req.Address, req.Name, req.Provider, req.ExternalID,
	)
	return loc, err
}
