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
	ID             uuid.UUID  `json:"id" db:"id"`
	Title          string     `json:"title" db:"title"`
	Description    *string    `json:"description" db:"description"`
	CoverURL       *string    `json:"cover_url" db:"cover_url"`
	Lat            float64    `json:"lat" db:"lat"`
	Lon            float64    `json:"lon" db:"lon"`
	CityName       string     `json:"city_name" db:"city_name"`
	StartTime      time.Time  `json:"start_time" db:"start_time"`
	EndTime        *time.Time `json:"end_time" db:"end_time"`
	IsPrivate      bool       `json:"is_private" db:"is_private"`
	Status         string     `json:"status" db:"status"`
	MaxMembers     *int       `json:"max_members" db:"max_members"`
	MembersCount   int        `json:"members_count" db:"members_count"`
	CategoryID     *int       `json:"category_id" db:"category_id"`
	OrganizationID *uuid.UUID `json:"organization_id" db:"organization_id"`
	LocationID     *uuid.UUID `json:"location_id" db:"location_id"`
	CreatedBy      uuid.UUID  `json:"created_by" db:"created_by"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      *time.Time `json:"updated_at" db:"updated_at"`
	UpdatedBy      *uuid.UUID `json:"updated_by" db:"updated_by"`
	DeletedAt      *time.Time `json:"-" db:"deleted_at"`
	DeletedBy      *uuid.UUID `json:"-" db:"deleted_by"`
}

type CreateEventRequest struct {
	Title          string     `json:"title"`
	Description    *string    `json:"description"`
	CoverURL       *string    `json:"cover_url"`
	Lat            float64    `json:"lat"`
	Lon            float64    `json:"lon"`
	CityName       string     `json:"city_name"`
	StartTime      time.Time  `json:"start_time"`
	EndTime        *time.Time `json:"end_time"`
	IsPrivate      bool       `json:"is_private"`
	MaxMembers     *int       `json:"max_members"`
	CategoryID     *int       `json:"category_id"`
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
