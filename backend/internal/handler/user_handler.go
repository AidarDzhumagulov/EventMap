package handler

import (
	"encoding/json"
	"event-map/internal/middleware"
	"event-map/internal/models"
	"event-map/internal/repository"
	"event-map/internal/service"
	"net/http"
	"strings"
)

// Handler — тонкий HTTP-слой над AuthService.
// Парсит запрос → вызывает service → маппит ошибки на HTTP-коды.
type Handler struct {
	userRepo *repository.UserRepository
	auth     *service.AuthService
}

type tokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

func NewHandler(userRepo *repository.UserRepository, auth *service.AuthService) *Handler {
	return &Handler{userRepo: userRepo, auth: auth}
}

func (h *Handler) RegisterUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	var req models.RegisterUser
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	user, err := h.auth.Register(r.Context(), req.Email, req.Username, req.Password)
	if err != nil {
		writeServiceError(w, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(user)
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	var req models.LoginUser
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	tokens, err := h.auth.Login(r.Context(), req.Email, req.Password)
	if err != nil {
		writeServiceError(w, err)
		return
	}

	writeTokens(w, tokens)
}

func (h *Handler) Refresh(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	tokenString, ok := bearerToken(r)
	if !ok {
		http.Error(w, "Refresh token required", http.StatusUnauthorized)
		return
	}

	tokens, err := h.auth.Refresh(r.Context(), tokenString)
	if err != nil {
		writeServiceError(w, err)
		return
	}

	writeTokens(w, tokens)
}

// POST /logout — отзывает текущую сессию по refresh-токену.
// Идемпотентно: невалидный токен → 204 (сессия и так мёртвая).
func (h *Handler) Logout(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	tokenString, ok := bearerToken(r)
	if !ok {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	if err := h.auth.Logout(r.Context(), tokenString); err != nil {
		writeServiceError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// POST /logout-all — отзывает все сессии текущего юзера.
func (h *Handler) LogoutAll(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	if err := h.auth.LogoutAll(r.Context(), userID); err != nil {
		writeServiceError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Разрешен только GET метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	user, err := h.userRepo.GetByID(r.Context(), userID)
	if err != nil {
		http.Error(w, "Пользователь не найден", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(user)
}

// PATCH /me/update — обновление профиля текущего пользователя.
func (h *Handler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPatch {
		http.Error(w, "Разрешен только PATCH метод", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req models.UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Неверный формат JSON", http.StatusBadRequest)
		return
	}

	req.Username = strings.TrimSpace(req.Username)
	if req.Username == "" {
		http.Error(w, "username обязателен", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	if h.userRepo.IsUsernameTakenByOther(ctx, req.Username, userID) {
		http.Error(w, "Имя пользователя уже занято", http.StatusConflict)
		return
	}

	user, err := h.userRepo.Update(ctx, userID, req.Username, req.AvatarURL)
	if err != nil {
		http.Error(w, "Ошибка обновления профиля", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(user)
}

// bearerToken извлекает токен из заголовка `Authorization: Bearer <...>`.
// ok=false если заголовок отсутствует или формат неверный.
func bearerToken(r *http.Request) (string, bool) {
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "Bearer ") {
		return "", false
	}
	t := strings.TrimPrefix(auth, "Bearer ")
	return t, t != ""
}

func writeTokens(w http.ResponseWriter, tokens service.TokenPair) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(tokenResponse{
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
	})
}
