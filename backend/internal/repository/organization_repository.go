package repository

import (
	"database/sql"
	"errors"
	"event-map/internal/models"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type OrganizationRepository struct {
	db *sqlx.DB
}

func NewOrganizationRepository(db *sqlx.DB) *OrganizationRepository {
	return &OrganizationRepository{db: db}
}

func (r *OrganizationRepository) Create(req models.CreateOrganizationRequest, userID uuid.UUID) (models.Organization, error) {
	tx, err := r.db.Beginx()
	if err != nil {
		return models.Organization{}, err
	}
	defer tx.Rollback()

	var org models.Organization
	err = tx.Get(&org, `
		INSERT INTO organizations (name, description, created_by)
		VALUES ($1, $2, $3)
		RETURNING id, name, description, is_verified, billing_info, created_at, created_by`,
		req.Name, req.Description, userID)
	if err != nil {
		return models.Organization{}, err
	}

	_, err = tx.Exec(
		`INSERT INTO business_members (user_id, organization_id, role) VALUES ($1, $2, 'owner')`,
		userID, org.ID)
	if err != nil {
		return models.Organization{}, err
	}

	return org, tx.Commit()
}

func (r *OrganizationRepository) IsOrgAdmin(orgID, userID uuid.UUID) bool {
	var exists bool
	r.db.Get(&exists,
		`SELECT EXISTS(SELECT 1 FROM business_members
		 WHERE organization_id = $1 AND user_id = $2 AND role IN ('owner', 'admin'))`,
		orgID, userID)
	return exists
}

func (r *OrganizationRepository) GetByID(id uuid.UUID) (models.Organization, error) {
	var org models.Organization
	err := r.db.Get(&org,
		`SELECT id, name, description, is_verified, billing_info, created_at, created_by
		 FROM organizations WHERE id = $1`, id)
	if errors.Is(err, sql.ErrNoRows) {
		return models.Organization{}, ErrNotFound
	}
	return org, err
}

func (r *OrganizationRepository) GetByUser(userID uuid.UUID) ([]models.Organization, error) {
	var orgs []models.Organization
	query := `
		SELECT o.id, o.name, o.description, o.is_verified, o.billing_info, o.created_at, o.created_by
		FROM organizations o
		JOIN business_members bm ON bm.organization_id = o.id
		WHERE bm.user_id = $1
		ORDER BY o.created_at DESC`
	err := r.db.Select(&orgs, query, userID)
	return orgs, err
}

func (r *OrganizationRepository) Update(id uuid.UUID, req models.UpdateOrganizationRequest, userID uuid.UUID) (models.Organization, error) {
	var org models.Organization
	query := `
		UPDATE organizations SET name = $1, description = $2
		WHERE id = $3 AND created_by = $4
		RETURNING id, name, description, is_verified, billing_info, created_at, created_by`
	err := r.db.Get(&org, query, req.Name, req.Description, id, userID)
	if errors.Is(err, sql.ErrNoRows) {
		return models.Organization{}, ErrNotFound
	}
	return org, err
}

func (r *OrganizationRepository) Delete(id uuid.UUID, userID uuid.UUID) error {
	result, err := r.db.Exec(
		`DELETE FROM organizations WHERE id = $1 AND created_by = $2`, id, userID)
	if err != nil {
		return err
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *OrganizationRepository) AddMember(orgID uuid.UUID, req models.AddMemberRequest) error {
	_, err := r.db.Exec(
		`INSERT INTO business_members (user_id, organization_id, role)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (user_id, organization_id) DO UPDATE SET role = EXCLUDED.role`,
		req.UserID, orgID, req.Role)
	return err
}

func (r *OrganizationRepository) RemoveMember(orgID, userID uuid.UUID) error {
	result, err := r.db.Exec(
		`DELETE FROM business_members WHERE organization_id = $1 AND user_id = $2`, orgID, userID)
	if err != nil {
		return err
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *OrganizationRepository) GetMembers(orgID uuid.UUID) ([]models.BusinessMemberUser, error) {
	var members []models.BusinessMemberUser
	query := `
		SELECT u.id AS user_id, u.username, u.avatar_url, bm.role, bm.joined_at
		FROM business_members bm
		JOIN users u ON u.id = bm.user_id
		WHERE bm.organization_id = $1
		ORDER BY bm.joined_at ASC`
	err := r.db.Select(&members, query, orgID)
	return members, err
}
