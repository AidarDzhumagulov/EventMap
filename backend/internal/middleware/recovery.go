package middleware

import (
	"log/slog"
	"net/http"
	"runtime/debug"
)

// Recovery — последний рубеж: ловит panic в любом handler'е,
// логирует stack trace и отвечает 500. Без этого паника в одном
// handler'е роняет весь сервер → 503 для всех клиентов.
func Recovery(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				slog.Error("panic recovered",
					"err", rec,
					"method", r.Method,
					"path", r.URL.Path,
					"stack", string(debug.Stack()),
				)
				// Если ответ ещё не начали писать — отдаём 500.
				// Если начали — браузер увидит обрезанный ответ, тут уже ничего не поделаешь.
				http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			}
		}()
		next(w, r)
	}
}
