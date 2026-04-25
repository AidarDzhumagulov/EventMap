package handler

import (
	"encoding/json"
	"event-map/core"
	"fmt"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
)

type UploadHandler struct {
	storage *core.Storage
}

func NewUploadHandler(storage *core.Storage) *UploadHandler {
	return &UploadHandler{storage: storage}
}

var allowedTypes = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
}

// POST /upload?type=avatar|cover — загружает файл в R2, возвращает {"url": "..."}
func (h *UploadHandler) Upload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Разрешен только POST метод", http.StatusMethodNotAllowed)
		return
	}

	if err := r.ParseMultipartForm(10 << 20); err != nil { // 10 MB
		http.Error(w, "Файл слишком большой (макс. 10MB)", http.StatusBadRequest)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Поле 'file' обязательно", http.StatusBadRequest)
		return
	}
	defer file.Close()

	contentType := header.Header.Get("Content-Type")
	ext, ok := allowedTypes[contentType]
	if !ok {
		// Попробуем определить по расширению
		ext = strings.ToLower(filepath.Ext(header.Filename))
		if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".webp" {
			http.Error(w, "Разрешены только JPEG, PNG, WebP", http.StatusBadRequest)
			return
		}
		if ext == ".jpeg" {
			ext = ".jpg"
		}
		contentType = "image/jpeg"
		if ext == ".png" {
			contentType = "image/png"
		}
		if ext == ".webp" {
			contentType = "image/webp"
		}
	}

	uploadType := r.URL.Query().Get("type")
	if uploadType != "avatar" && uploadType != "cover" {
		uploadType = "avatar"
	}

	key := fmt.Sprintf("%s/%s%s", uploadType, uuid.New().String(), ext)

	url, err := h.storage.Upload(r.Context(), key, file, contentType)
	if err != nil {
		http.Error(w, "Ошибка загрузки файла", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"url": url})
}
