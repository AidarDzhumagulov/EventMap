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
			"method", r.Method,
			"path", r.URL.Path,
			"query", r.URL.RawQuery,
			"status", rw.status,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	}
}

func AuthLogging(next http.HandlerFunc) http.HandlerFunc {
	return Recovery(LoggingMiddleware(AuthMiddleware(next)))
}

// PublicLogging — для незащищённых роутов. Тоже под Recovery.
func PublicLogging(next http.HandlerFunc) http.HandlerFunc {
	return Recovery(LoggingMiddleware(next))
}
