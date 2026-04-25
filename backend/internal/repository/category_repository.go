package repository

import (
	"event-map/internal/models"

	"github.com/jmoiron/sqlx"
)

type CategoryRepository struct {
	db *sqlx.DB
}

func NewCategoryRepository(db *sqlx.DB) *CategoryRepository {
	return &CategoryRepository{db: db}
}

func (r *CategoryRepository) GetAllWithCategories() ([]models.CategoryTypeWithCategories, error) {
	var types []models.CategoryType
	err := r.db.Select(&types, "SELECT id, alias, name_ru FROM category_types ORDER BY id")
	if err != nil {
		return nil, err
	}

	var categories []models.Category
	err = r.db.Select(&categories, "SELECT id, alias, name_ru, category_type_id FROM categories ORDER BY id")
	if err != nil {
		return nil, err
	}

	// Группируем категории по category_type_id
	catMap := make(map[int16][]models.Category)
	for _, cat := range categories {
		catMap[cat.CategoryTypeId] = append(catMap[cat.CategoryTypeId], cat)
	}

	result := make([]models.CategoryTypeWithCategories, 0, len(types))
	for _, t := range types {
		result = append(result, models.CategoryTypeWithCategories{
			ID:         t.ID,
			Alias:      t.Alias,
			NameRu:     t.NameRu,
			Categories: catMap[t.ID],
		})
	}

	return result, nil
}
