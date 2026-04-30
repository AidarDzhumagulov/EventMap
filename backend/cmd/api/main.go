package main

import (
	"context"
	"errors"
	"event-map/core"
	"event-map/internal/auth"
	"event-map/internal/email"
	"event-map/internal/handler"
	"event-map/internal/middleware"
	"event-map/internal/repository"
	"fmt"
	"log"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/joho/godotenv"
)

func main() {
	if err := run(); err != nil {
		slog.Error("server exited with error", "err", err)
		os.Exit(1)
	}
}

// run — основной runtime приложения. Вынесен из main() чтобы defer'ы
// (db.Close, bgCancel, и т.п.) гарантированно отработали перед os.Exit.
func run() error {
	if err := godotenv.Load(); err != nil {
		log.Println("godotenv: .env не найден, используем переменные окружения")
	}

	// LOG_FORMAT=json для прода (структурированные логи для Loki/CloudWatch/etc).
	// По умолчанию text — человекочитаемый формат для dev.
	logLevel := slog.LevelDebug
	if os.Getenv("LOG_LEVEL") == "info" {
		logLevel = slog.LevelInfo
	}
	opts := &slog.HandlerOptions{Level: logLevel}
	var logHandler slog.Handler = slog.NewTextHandler(os.Stdout, opts)
	if os.Getenv("LOG_FORMAT") == "json" {
		logHandler = slog.NewJSONHandler(os.Stdout, opts)
	}
	slog.SetDefault(slog.New(logHandler))

	// Падаем сразу если JWT_SECRET не задан или короткий — чтобы не выкатить
	// прод с дырой "любой может подделать токен".
	auth.MustInit()

	poolSize, _ := strconv.Atoi(os.Getenv("DB_POOL_SIZE"))
	maxOverflow, _ := strconv.Atoi(os.Getenv("DB_MAX_OVERFLOW"))
	poolRecycle, _ := strconv.Atoi(os.Getenv("DB_POOL_RECYCLE"))
	poolTimeout, _ := strconv.Atoi(os.Getenv("DB_POOL_TIMEOUT"))

	// Sane defaults — если env не задан, не получим pool size = 0.
	if poolSize <= 0 {
		poolSize = 10
	}
	if maxOverflow < 0 {
		maxOverflow = 5
	}
	if poolRecycle <= 0 {
		poolRecycle = 3600
	}
	if poolTimeout <= 0 {
		poolTimeout = 300
	}

	db, err := core.NewDB(core.DBConfig{
		Host:         os.Getenv("DB_HOST"),
		Port:         os.Getenv("DB_PORT"),
		Name:         os.Getenv("DB_NAME"),
		User:         os.Getenv("DB_USER"),
		Password:     os.Getenv("DB_PASSWORD"),
		MaxOpenConns: poolSize + maxOverflow,
		MaxIdleConns: poolSize,
		MaxLifetime:  time.Duration(poolRecycle) * time.Second,
		MaxIdleTime:  time.Duration(poolTimeout) * time.Second,
	})
	if err != nil {
		return fmt.Errorf("connect to DB: %w", err)
	}
	defer func() { _ = db.Close() }()

	mux := http.NewServeMux()
	authMW := middleware.AuthLogging
	pub := middleware.PublicLogging

	// Rate limiter для /login и /register — защита от брутфорса и спама.
	// 0.2 rps = 1 запрос в 5 сек; burst 5 = можно 5 запросов подряд, потом ждать.
	authLimiter := middleware.NewIPLimiter(0.2, 5)

	// Healthchecks. Разделены чтобы k8s/LB могли понимать состояние:
	//   /live  — процесс жив (всегда 200, не дёргает БД)
	//   /ready — готов принимать трафик (503 если БД недоступна)
	// Оставлен alias /ping для обратной совместимости с существующими probe'ами.
	mux.HandleFunc("/live", liveHandler)
	mux.HandleFunc("/ready", readyHandler(db))
	mux.HandleFunc("/ping", readyHandler(db))

	storage := core.NewStorage()

	mailer := email.New()

	userRepo := repository.NewUserRepository(db)
	tokenRepo := repository.NewRefreshTokenRepository(db)
	emailVerifyRepo := repository.NewEmailVerificationRepository(db)
	passwordResetRepo := repository.NewPasswordResetRepository(db)

	verificationHandler := handler.NewEmailVerificationHandler(userRepo, emailVerifyRepo, mailer)
	passwordResetHandler := handler.NewPasswordResetHandler(userRepo, passwordResetRepo, tokenRepo, mailer)
	h := handler.NewHandler(userRepo, tokenRepo, verificationHandler)
	uploadHandler := handler.NewUploadHandler(storage)

	mux.HandleFunc("/upload", authMW(uploadHandler.Upload))
	mux.HandleFunc("/register", pub(authLimiter.Middleware(h.RegisterUser)))
	mux.HandleFunc("/login", pub(authLimiter.Middleware(h.Login)))
	mux.HandleFunc("/refresh", pub(authLimiter.Middleware(h.Refresh)))
	mux.HandleFunc("/logout", pub(h.Logout))
	mux.HandleFunc("/logout-all", authMW(h.LogoutAll))
	mux.HandleFunc("/me", authMW(h.Me))
	mux.HandleFunc("/me/update", authMW(h.UpdateMe))

	// Email verification — verify публичный (по токену из письма),
	// resend под auth (юзер должен быть залогинен).
	mux.HandleFunc("/email/verify", pub(authLimiter.Middleware(verificationHandler.Verify)))
	mux.HandleFunc("/email/resend-verification", authMW(authLimiter.Middleware(verificationHandler.Resend)))

	// Password reset — оба публичные (юзер залочен из аккаунта). С rate limit.
	mux.HandleFunc("/password/request-reset", pub(authLimiter.Middleware(passwordResetHandler.RequestReset)))
	mux.HandleFunc("/password/reset", pub(authLimiter.Middleware(passwordResetHandler.Reset)))

	categoryRepo := repository.NewCategoryRepository(db)
	categoryHandler := handler.NewCategoryHandler(categoryRepo)
	mux.HandleFunc("/categories", pub(categoryHandler.GetCategories))

	locationRepo := repository.NewLocationRepository(db)
	locationHandler := handler.NewLocationHandler(locationRepo)
	mux.HandleFunc("/locations/create", authMW(locationHandler.CreateLocation))

	eventRepo := repository.NewEventRepository(db)
	eventHandler := handler.NewEventHandler(eventRepo)
	mux.HandleFunc("/events", authMW(eventHandler.GetEvents))
	mux.HandleFunc("/events/create", authMW(eventHandler.CreateEvent))
	mux.HandleFunc("/events/detail", authMW(eventHandler.GetEvent))
	mux.HandleFunc("/events/feed", authMW(eventHandler.GetFeed))
	mux.HandleFunc("/events/my", authMW(eventHandler.GetMyEvents))
	mux.HandleFunc("/events/nearby", authMW(eventHandler.GetNearby))
	mux.HandleFunc("/events/update", authMW(eventHandler.UpdateEvent))
	mux.HandleFunc("/events/delete", authMW(eventHandler.DeleteEvent))

	swipeRepo := repository.NewEventSwipeRepository(db)
	swipeHandler := handler.NewEventSwipeHandler(swipeRepo)
	mux.HandleFunc("/events/skip", authMW(swipeHandler.Skip))

	memberRepo := repository.NewEventMemberRepository(db)
	memberHandler := handler.NewEventMemberHandler(memberRepo, eventRepo)
	mux.HandleFunc("/events/join", authMW(memberHandler.Join))
	mux.HandleFunc("/events/join-by-code", authMW(memberHandler.JoinByCode))
	mux.HandleFunc("/events/leave", authMW(memberHandler.Leave))
	mux.HandleFunc("/events/my-status", authMW(memberHandler.GetMyStatus))
	mux.HandleFunc("/events/members", authMW(memberHandler.GetMembers))

	savedRepo := repository.NewSavedEventRepository(db)
	savedHandler := handler.NewSavedEventHandler(savedRepo)
	mux.HandleFunc("/events/save", authMW(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			savedHandler.Save(w, r)
		case http.MethodDelete:
			savedHandler.Unsave(w, r)
		default:
			http.Error(w, "Метод не поддерживается", http.StatusMethodNotAllowed)
		}
	}))
	mux.HandleFunc("/events/saved", authMW(savedHandler.GetSaved))
	mux.HandleFunc("/events/is-saved", authMW(savedHandler.IsSaved))

	orgRepo := repository.NewOrganizationRepository(db)
	orgHandler := handler.NewOrganizationHandler(orgRepo)
	mux.HandleFunc("/organizations/create", authMW(orgHandler.Create))
	mux.HandleFunc("/organizations/my", authMW(orgHandler.GetMy))
	mux.HandleFunc("/organizations/detail", authMW(orgHandler.GetByID))
	mux.HandleFunc("/organizations/update", authMW(orgHandler.Update))
	mux.HandleFunc("/organizations/delete", authMW(orgHandler.Delete))
	mux.HandleFunc("/organizations/members", authMW(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			orgHandler.GetMembers(w, r)
		case http.MethodPost:
			orgHandler.AddMember(w, r)
		case http.MethodDelete:
			orgHandler.RemoveMember(w, r)
		default:
			http.Error(w, "Метод не поддерживается", http.StatusMethodNotAllowed)
		}
	}))

	srv := &http.Server{
		Addr:    ":8080",
		Handler: middleware.CORS(mux),
		// Защита от Slowloris и подобных DoS-атак.
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	// Server в фоне.
	serverErr := make(chan error, 1)
	go func() {
		slog.Info("Event Map API запущен", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
		}
	}()

	// Background cleanup протухших токенов (refresh, email_verification, password_reset).
	// Раз в сутки. Если несколько подов — DELETE идемпотентен, лишняя нагрузка не критична.
	bgCtx, bgCancel := context.WithCancel(context.Background())
	defer bgCancel()
	go runTokenCleanup(bgCtx, tokenRepo, emailVerifyRepo, passwordResetRepo)

	// Ждём SIGTERM/SIGINT или ошибку запуска.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)

	var runErr error
	select {
	case err := <-serverErr:
		runErr = fmt.Errorf("server failed: %w", err)
	case sig := <-sigCh:
		slog.Info("shutdown initiated", "signal", sig.String())
	}

	// Graceful shutdown — даём 30 сек активным запросам завершиться.
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("shutdown failed", "err", err)
	}
	slog.Info("shutdown complete")
	return runErr
}

// cleaner — общий интерфейс для CleanupExpired, чтобы один цикл чистил
// все типы токенов одинаково.
type cleaner interface {
	CleanupExpired(ctx context.Context) (int64, error)
}

// runTokenCleanup — периодически чистит протухшие токены всех типов.
// Запускается раз в сутки. Прерывается через context при shutdown.
func runTokenCleanup(ctx context.Context, repos ...cleaner) {
	ticker := time.NewTicker(24 * time.Hour)
	defer ticker.Stop()

	// Первый прогон сразу — не ждём 24 часа после рестарта.
	doCleanupAll(ctx, repos)

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			doCleanupAll(ctx, repos)
		}
	}
}

func doCleanupAll(ctx context.Context, repos []cleaner) {
	for _, repo := range repos {
		// Отдельный таймаут на каждый — чтобы один зависший не блокировал остальные.
		c, cancel := context.WithTimeout(ctx, 30*time.Second)
		deleted, err := repo.CleanupExpired(c)
		cancel()
		if err != nil {
			slog.Error("token cleanup failed", "err", err)
			continue
		}
		if deleted > 0 {
			slog.Info("token cleanup complete", "deleted", deleted)
		}
	}
}

// liveHandler — для liveness probe. Если процесс отвечает — он жив.
// Не дёргает БД, чтобы временный сбой Postgres не вызвал рестарт пода.
func liveHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"alive"}`))
}

// readyHandler — для readiness probe. Проверяет что БД доступна.
// Если 503 — k8s выводит под из балансировки до восстановления.
func readyHandler(db interface{ Ping() error }) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if err := db.Ping(); err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte(`{"status":"down","reason":"db unreachable"}`))
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ready"}`))
	}
}
