package main

import (
	"event-map/core"
	"event-map/internal/handler"
	"event-map/internal/middleware"
	"event-map/internal/repository"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

func main() {

	godotenv.Load()

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

	http.HandleFunc("/ping", pingHandler)

	storage := core.NewStorage()

	userRepo := repository.NewUserRepository(db)
	h := handler.NewHandler(userRepo)

	uploadHandler := handler.NewUploadHandler(storage)
	http.HandleFunc("/upload", middleware.AuthMiddleware(uploadHandler.Upload))
	http.HandleFunc("/register", h.RegisterUser)
	http.HandleFunc("/login", h.Login)
	http.HandleFunc("/refresh", h.Refresh)
	http.HandleFunc("/me", middleware.AuthMiddleware(h.Me))
	http.HandleFunc("/me/update", middleware.AuthMiddleware(h.UpdateMe))

	categoryRepo := repository.NewCategoryRepository(db)
	categoryHandler := handler.NewCategoryHandler(categoryRepo)
	http.HandleFunc("/categories", categoryHandler.GetCategories)

	locationRepo := repository.NewLocationRepository(db)
	locationHandler := handler.NewLocationHandler(locationRepo)
	http.HandleFunc("/locations/create", middleware.AuthMiddleware(locationHandler.CreateLocation))

	eventRepo := repository.NewEventRepository(db)
	eventHandler := handler.NewEventHandler(eventRepo)
	http.HandleFunc("/events", middleware.AuthMiddleware(eventHandler.GetEvents))
	http.HandleFunc("/events/create", middleware.AuthMiddleware(eventHandler.CreateEvent))
	http.HandleFunc("/events/detail", middleware.AuthMiddleware(eventHandler.GetEvent))
	http.HandleFunc("/events/my", middleware.AuthMiddleware(eventHandler.GetMyEvents))

	memberRepo := repository.NewEventMemberRepository(db)
	memberHandler := handler.NewEventMemberHandler(memberRepo, eventRepo)
	http.HandleFunc("/events/join", middleware.AuthMiddleware(memberHandler.Join))
	http.HandleFunc("/events/leave", middleware.AuthMiddleware(memberHandler.Leave))
	http.HandleFunc("/events/my-status", middleware.AuthMiddleware(memberHandler.GetMyStatus))
	http.HandleFunc("/events/members", middleware.AuthMiddleware(memberHandler.GetMembers))
	http.HandleFunc("/events/update", middleware.AuthMiddleware(eventHandler.UpdateEvent))
	http.HandleFunc("/events/delete", middleware.AuthMiddleware(eventHandler.DeleteEvent))

	savedRepo := repository.NewSavedEventRepository(db)
	savedHandler := handler.NewSavedEventHandler(savedRepo)
	http.HandleFunc("/events/save", middleware.AuthMiddleware(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			savedHandler.Save(w, r)
		case http.MethodDelete:
			savedHandler.Unsave(w, r)
		default:
			http.Error(w, "Метод не поддерживается", http.StatusMethodNotAllowed)
		}
	}))
	http.HandleFunc("/events/saved", middleware.AuthMiddleware(savedHandler.GetSaved))
	http.HandleFunc("/events/is-saved", middleware.AuthMiddleware(savedHandler.IsSaved))

	log.Println("Сервер Event Map запущен")

	err = http.ListenAndServe(":8080", nil)

	if err != nil {
		log.Println("Ошибка запуска сервера:", err)
	}
}

func pingHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status": "ok", "message": "Event Map API is alive!"}`))
}
