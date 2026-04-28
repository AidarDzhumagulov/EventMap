package main

import (
	"event-map/core"
	"event-map/internal/handler"
	"event-map/internal/middleware"
	"event-map/internal/repository"
	"log"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("godotenv: .env не найден, используем переменные окружения")
	}

	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	})))

	poolSize, _ := strconv.Atoi(os.Getenv("DB_POOL_SIZE"))
	maxOverflow, _ := strconv.Atoi(os.Getenv("DB_MAX_OVERFLOW"))
	poolRecycle, _ := strconv.Atoi(os.Getenv("DB_POOL_RECYCLE"))
	poolTimeout, _ := strconv.Atoi(os.Getenv("DB_POOL_TIMEOUT"))

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
		log.Fatalln("Не удалось подключиться к БД:", err)
	}
	defer db.Close()

	auth := middleware.AuthLogging
	pub := middleware.LoggingMiddleware

	http.HandleFunc("/ping", pub(pingHandler))

	storage := core.NewStorage()

	userRepo := repository.NewUserRepository(db)
	h := handler.NewHandler(userRepo)
	uploadHandler := handler.NewUploadHandler(storage)

	http.HandleFunc("/upload", auth(uploadHandler.Upload))
	http.HandleFunc("/register", pub(h.RegisterUser))
	http.HandleFunc("/login", pub(h.Login))
	http.HandleFunc("/refresh", pub(h.Refresh))
	http.HandleFunc("/me", auth(h.Me))
	http.HandleFunc("/me/update", auth(h.UpdateMe))

	categoryRepo := repository.NewCategoryRepository(db)
	categoryHandler := handler.NewCategoryHandler(categoryRepo)
	http.HandleFunc("/categories", pub(categoryHandler.GetCategories))

	locationRepo := repository.NewLocationRepository(db)
	locationHandler := handler.NewLocationHandler(locationRepo)
	http.HandleFunc("/locations/create", auth(locationHandler.CreateLocation))

	eventRepo := repository.NewEventRepository(db)
	eventHandler := handler.NewEventHandler(eventRepo)
	http.HandleFunc("/events", auth(eventHandler.GetEvents))
	http.HandleFunc("/events/create", auth(eventHandler.CreateEvent))
	http.HandleFunc("/events/detail", auth(eventHandler.GetEvent))
	http.HandleFunc("/events/feed", auth(eventHandler.GetFeed))
	http.HandleFunc("/events/my", auth(eventHandler.GetMyEvents))
	http.HandleFunc("/events/nearby", auth(eventHandler.GetNearby))
	http.HandleFunc("/events/update", auth(eventHandler.UpdateEvent))
	http.HandleFunc("/events/delete", auth(eventHandler.DeleteEvent))

	swipeRepo := repository.NewEventSwipeRepository(db)
	swipeHandler := handler.NewEventSwipeHandler(swipeRepo)
	http.HandleFunc("/events/skip", auth(swipeHandler.Skip))

	memberRepo := repository.NewEventMemberRepository(db)
	memberHandler := handler.NewEventMemberHandler(memberRepo, eventRepo)
	http.HandleFunc("/events/join", auth(memberHandler.Join))
	http.HandleFunc("/events/join-by-code", auth(memberHandler.JoinByCode))
	http.HandleFunc("/events/leave", auth(memberHandler.Leave))
	http.HandleFunc("/events/my-status", auth(memberHandler.GetMyStatus))
	http.HandleFunc("/events/members", auth(memberHandler.GetMembers))

	savedRepo := repository.NewSavedEventRepository(db)
	savedHandler := handler.NewSavedEventHandler(savedRepo)
	http.HandleFunc("/events/save", auth(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			savedHandler.Save(w, r)
		case http.MethodDelete:
			savedHandler.Unsave(w, r)
		default:
			http.Error(w, "Метод не поддерживается", http.StatusMethodNotAllowed)
		}
	}))
	http.HandleFunc("/events/saved", auth(savedHandler.GetSaved))
	http.HandleFunc("/events/is-saved", auth(savedHandler.IsSaved))

	orgRepo := repository.NewOrganizationRepository(db)
	orgHandler := handler.NewOrganizationHandler(orgRepo)
	http.HandleFunc("/organizations/create", auth(orgHandler.Create))
	http.HandleFunc("/organizations/my", auth(orgHandler.GetMy))
	http.HandleFunc("/organizations/detail", auth(orgHandler.GetByID))
	http.HandleFunc("/organizations/update", auth(orgHandler.Update))
	http.HandleFunc("/organizations/delete", auth(orgHandler.Delete))
	http.HandleFunc("/organizations/members", auth(func(w http.ResponseWriter, r *http.Request) {
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

	slog.Info("Event Map API запущен", "port", 8080)
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatalln("Ошибка запуска сервера:", err)
	}
}

func pingHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status": "ok", "message": "Event Map API is alive!"}`))
}
