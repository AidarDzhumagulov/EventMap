package models

import (
	"time"

	"github.com/google/uuid"
)

type RegisterUser struct {
	Email    string `json:"email"`
	Username string `json:"username"`
	Role     string `json:"role"`
	Password string `json:"password"`
}

type User struct {
	ID           uuid.UUID `json:"id" db:"id"`
	Email        string    `json:"email" db:"email"`
	Username     string    `json:"username" db:"username"`
	Role         string    `json:"role" db:"role"`
	Rating       float32   `json:"rating" db:"rating"`
	AvatarURL    *string   `json:"avatar_url" db:"avatar_url"`
	PasswordHash string    `json:"-" db:"password"`
}

type LoginUser struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type Event struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	Title           string     `json:"title" db:"title"`
	Description     *string    `json:"description" db:"description"`
	CoverURL        *string    `json:"cover_url" db:"cover_url"`
	Lat             float64    `json:"lat" db:"lat"`
	Lon             float64    `json:"lon" db:"lon"`
	CityName        string     `json:"city_name" db:"city_name"`
	StartTime       time.Time  `json:"start_time" db:"start_time"`
	EndTime         *time.Time `json:"end_time" db:"end_time"`
	IsPrivate       bool       `json:"is_private" db:"is_private"`
	Status          string     `json:"status" db:"status"`
	MaxMembers      *int       `json:"max_members" db:"max_members"`
	MembersCount    int        `json:"members_count" db:"members_count"`
	CategoryID      *int       `json:"category_id" db:"category_id"`
	OrganizationID  *uuid.UUID `json:"organization_id" db:"organization_id"`
	LocationID      *uuid.UUID `json:"location_id" db:"location_id"`
	CreatedBy       uuid.UUID  `json:"created_by" db:"created_by"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       *time.Time `json:"updated_at" db:"updated_at"`
	UpdatedBy       *uuid.UUID `json:"updated_by" db:"updated_by"`
	DeletedAt       *time.Time `json:"-" db:"deleted_at"`
	DeletedBy       *uuid.UUID `json:"-" db:"deleted_by"`
	LocationAddress *string    `json:"location_address" db:"location_address"`
	CategoryName    *string    `json:"category_name" db:"category_name"`
	CategoryAlias   *string    `json:"category_alias" db:"category_alias"`
	InviteCode      *string    `json:"invite_code,omitempty" db:"invite_code"`
}

type CreateEventRequest struct {
	Title       string     `json:"title"`
	Description *string    `json:"description"`
	CoverURL    *string    `json:"cover_url"`
	Lat         float64    `json:"lat"`
	Lon         float64    `json:"lon"`
	CityName    string     `json:"city_name"`
	StartTime   time.Time  `json:"start_time"`
	EndTime     *time.Time `json:"end_time"`
	IsPrivate   bool       `json:"is_private"`
	MaxMembers  *int       `json:"max_members"`
	CategoryID  *int       `json:"category_id"`
	LocationID  *uuid.UUID `json:"location_id"`
}

type UpdateEventRequest struct {
	Title       string     `json:"title"`
	Description *string    `json:"description"`
	CoverURL    *string    `json:"cover_url"`
	StartTime   time.Time  `json:"start_time"`
	EndTime     *time.Time `json:"end_time"`
	IsPrivate   bool       `json:"is_private"`
	MaxMembers  *int       `json:"max_members"`
	CategoryID  *int       `json:"category_id"`
}

type EventMember struct {
	EventID uuid.UUID `json:"event_id" db:"event_id"`
	UserID  uuid.UUID `json:"user_id" db:"user_id"`
	Status  string    `json:"status" db:"status"`
}

type EventMemberUser struct {
	UserID   uuid.UUID `json:"user_id" db:"user_id"`
	Username string    `json:"username" db:"username"`
	Status   string    `json:"status" db:"status"`
}

type UpdateProfileRequest struct {
	Username  string  `json:"username"`
	AvatarURL *string `json:"avatar_url"`
}

type CategoryType struct {
	ID     int16  `json:"id" db:"id"`
	Alias  string `json:"alias" db:"alias"`
	NameRu string `json:"name_ru" db:"name_ru"`
}

type Category struct {
	ID             int16  `json:"id" db:"id"`
	Alias          string `json:"alias" db:"alias"`
	NameRu         string `json:"name_ru" db:"name_ru"`
	CategoryTypeId int16  `json:"category_type_id" db:"category_type_id"`
}

type CategoryTypeWithCategories struct {
	ID         int16      `json:"id" db:"id"`
	Alias      string     `json:"alias" db:"alias"`
	NameRu     string     `json:"name_ru" db:"name_ru"`
	Categories []Category `json:"categories"`
}

type Location struct {
	ID         uuid.UUID `json:"id" db:"id"`
	Lat        float64   `json:"lat" db:"lat"`
	Lon        float64   `json:"lon" db:"lon"`
	Address    *string   `json:"address" db:"address"`
	Name       *string   `json:"name" db:"name"`
	Provider   string    `json:"provider" db:"provider"`
	ExternalID *string   `json:"external_id" db:"external_id"`
}

type CreateLocationRequest struct {
	Lat        float64 `json:"lat"`
	Lon        float64 `json:"lon"`
	Address    *string `json:"address"`
	Name       *string `json:"name"`
	Provider   string  `json:"provider"`
	ExternalID *string `json:"external_id"`
}

type Organization struct {
	ID          uuid.UUID `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description *string   `json:"description" db:"description"`
	IsVerified  bool      `json:"is_verified" db:"is_verified"`
	BillingInfo *string   `json:"billing_info,omitempty" db:"billing_info"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	CreatedBy   uuid.UUID `json:"created_by" db:"created_by"`
}

type CreateOrganizationRequest struct {
	Name        string  `json:"name"`
	Description *string `json:"description"`
}

type UpdateOrganizationRequest struct {
	Name        string  `json:"name"`
	Description *string `json:"description"`
}

type BusinessMember struct {
	UserID         uuid.UUID `json:"user_id" db:"user_id"`
	OrganizationID uuid.UUID `json:"organization_id" db:"organization_id"`
	Role           string    `json:"role" db:"role"`
	JoinedAt       time.Time `json:"joined_at" db:"joined_at"`
}

type BusinessMemberUser struct {
	UserID    uuid.UUID `json:"user_id" db:"user_id"`
	Username  string    `json:"username" db:"username"`
	AvatarURL *string   `json:"avatar_url" db:"avatar_url"`
	Role      string    `json:"role" db:"role"`
	JoinedAt  time.Time `json:"joined_at" db:"joined_at"`
}

type AddMemberRequest struct {
	UserID uuid.UUID `json:"user_id"`
	Role   string    `json:"role"`
}
