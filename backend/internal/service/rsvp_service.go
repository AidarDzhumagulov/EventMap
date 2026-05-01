package service

import (
	"context"
	"errors"
	"event-map/internal/models"
	"event-map/internal/repository"
	"fmt"

	"github.com/google/uuid"
)

// RSVP-доменные ошибки.
var (
	ErrEventFull     = errors.New("event is full")
	ErrInvalidCode   = errors.New("invalid invite code")
	ErrInvalidStatus = errors.New("invalid status")
)

// validRsvpStatuses — допустимые статусы участия.
// 'go' = иду, 'think' = думаю, 'decline' = не пойду.
var validRsvpStatuses = map[string]bool{
	"go":      true,
	"think":   true,
	"decline": true,
}

type RsvpService struct {
	members *repository.EventMemberRepository
	events  *repository.EventRepository
}

func NewRsvpService(
	members *repository.EventMemberRepository,
	events *repository.EventRepository,
) *RsvpService {
	return &RsvpService{members: members, events: events}
}

// Join — записаться на событие. Атомарно проверяет лимит мест.
// Default status = "go" если не передан.
func (s *RsvpService) Join(ctx context.Context, eventID, userID uuid.UUID, status string) (models.EventMember, error) {
	if status == "" {
		status = "go"
	}
	if !validRsvpStatuses[status] {
		return models.EventMember{}, fmt.Errorf("%w: статус должен быть go, think, decline", ErrInvalidStatus)
	}

	member, err := s.members.JoinAtomic(ctx, eventID, userID, status)
	if err != nil {
		if errors.Is(err, repository.ErrEventFull) {
			return models.EventMember{}, ErrEventFull
		}
		return models.EventMember{}, fmt.Errorf("join atomic: %w", err)
	}
	return member, nil
}

// JoinByCode — для приватных событий по invite-коду.
func (s *RsvpService) JoinByCode(ctx context.Context, code string, userID uuid.UUID) (models.EventMember, error) {
	if code == "" {
		return models.EventMember{}, fmt.Errorf("%w: код обязателен", ErrInvalidInput)
	}

	event, err := s.events.GetByInviteCode(ctx, code)
	if err != nil {
		return models.EventMember{}, ErrInvalidCode
	}

	member, err := s.members.JoinAtomic(ctx, event.ID, userID, "go")
	if err != nil {
		if errors.Is(err, repository.ErrEventFull) {
			return models.EventMember{}, ErrEventFull
		}
		return models.EventMember{}, fmt.Errorf("join by code: %w", err)
	}
	return member, nil
}

// Leave — отменить участие.
func (s *RsvpService) Leave(ctx context.Context, eventID, userID uuid.UUID) error {
	if err := s.members.Leave(ctx, eventID, userID); err != nil {
		return fmt.Errorf("leave: %w", err)
	}
	return nil
}

// GetMyStatus — статус текущего юзера на событии.
// Возвращает пустую строку (без ошибки) если юзер не записан.
func (s *RsvpService) GetMyStatus(ctx context.Context, eventID, userID uuid.UUID) (string, error) {
	status, err := s.members.GetStatus(ctx, eventID, userID)
	if err != nil {
		// Не записан — это не ошибка с точки зрения domain.
		return "", nil
	}
	return status, nil
}

// GetMembers — список всех участников события.
func (s *RsvpService) GetMembers(ctx context.Context, eventID uuid.UUID) ([]models.EventMemberUser, error) {
	members, err := s.members.GetMembers(ctx, eventID)
	if err != nil {
		return nil, fmt.Errorf("get members: %w", err)
	}
	return members, nil
}
