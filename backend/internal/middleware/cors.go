package middleware

import (
	"net/http"
	"os"
	"strings"
)

// CORS — простой middleware без внешних зависимостей.
//
// Allowed origins берутся из ENV CORS_ORIGINS (через запятую).
// Если переменная не задана — режим dev: разрешён "*" (mobile к этому пофигу).
// На прод обязательно задавать список явно: CORS_ORIGINS=https://app.example.com,https://admin.example.com
//
// Учитываем preflight (OPTIONS) — браузер дёргает его перед PUT/DELETE/PATCH/POST с Authorization.
func CORS(next http.Handler) http.Handler {
	origins := parseOrigins()

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")

		if origin != "" && allowed(origin, origins) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Request-ID")
			w.Header().Set("Access-Control-Expose-Headers", "X-Request-ID, X-Auth-Error")
			w.Header().Set("Access-Control-Max-Age", "86400") // кешируем preflight на сутки
		}

		// Preflight — отвечаем 204 без вызова handler.
		if r.Method == http.MethodOptions && r.Header.Get("Access-Control-Request-Method") != "" {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func parseOrigins() []string {
	raw := os.Getenv("CORS_ORIGINS")
	if raw == "" {
		// Dev-режим: разрешаем всё. Prod должен явно задавать список.
		return []string{"*"}
	}
	parts := strings.Split(raw, ",")
	result := make([]string, 0, len(parts))
	for _, p := range parts {
		if p = strings.TrimSpace(p); p != "" {
			result = append(result, p)
		}
	}
	return result
}

func allowed(origin string, allowedList []string) bool {
	for _, a := range allowedList {
		if a == "*" || a == origin {
			return true
		}
	}
	return false
}
