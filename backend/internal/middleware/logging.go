package middleware

import (
	"log/slog"
	"net/http"
	"time"
)

type responseWriter struct {
	http.ResponseWriter
	status int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.status = code
	rw.ResponseWriter.WriteHeader(code)
}

func LoggingMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &responseWriter{ResponseWriter: w, status: http.StatusOK}
		next(rw, r)
		slog.Info("request",
			"request_id", GetRequestID(r.Context()),
			"method", r.Method,
			"path", r.URL.Path,
			"query", r.URL.RawQuery,
			"status", rw.status,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	}
}

// AuthLogging — стек для защищённых роутов.
// Порядок снаружи внутрь: RequestID → Recovery → Logging → Auth → handler.
func AuthLogging(next http.HandlerFunc) http.HandlerFunc {
	return RequestID(Recovery(LoggingMiddleware(AuthMiddleware(next))))
}

// PublicLogging — стек для незащищённых роутов.
func PublicLogging(next http.HandlerFunc) http.HandlerFunc {
	return RequestID(Recovery(LoggingMiddleware(next)))
}
