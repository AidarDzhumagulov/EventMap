package middleware

import (
	"context"
	"net/http"

	"github.com/google/uuid"
)

const requestIDKey contextKey = "request_id"
const requestIDHeader = "X-Request-ID"

// RequestID — генерит / прокидывает X-Request-ID для трассировки.
// Если клиент прислал свой — уважаем (полезно когда мобилка хочет связать
// свои логи с серверными). Иначе генерим UUID.
//
// ID кладётся в r.Context() — доступен через GetRequestID(ctx) везде,
// и возвращается в response header чтобы клиент тоже его видел.
func RequestID(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		rid := r.Header.Get(requestIDHeader)
		if rid == "" {
			rid = uuid.NewString()
		}
		w.Header().Set(requestIDHeader, rid)
		ctx := context.WithValue(r.Context(), requestIDKey, rid)
		next(w, r.WithContext(ctx))
	}
}

// GetRequestID — извлекает request_id из контекста. Пустая строка если нет.
func GetRequestID(ctx context.Context) string {
	if v, ok := ctx.Value(requestIDKey).(string); ok {
		return v
	}
	return ""
}
