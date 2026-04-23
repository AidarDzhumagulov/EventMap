package main

import (
	"event-map/core"
	"event-map/internal/handler"
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

	userRepo := repository.NewUserRepository(db)
	h := handler.NewHandler(userRepo)
	http.HandleFunc("/register", h.RegisterUser)
	http.HandleFunc("/login", h.Login)

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
