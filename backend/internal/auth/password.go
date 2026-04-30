package auth

import (
	"crypto/sha256"
	"errors"
	"os"

	"golang.org/x/crypto/bcrypt"
)

// Cost для bcrypt. 12 — рекомендация OWASP для production (~250ms на хэш,
// что замедляет атаку перебором). Меньше — слабая защита, больше — медленный логин.
const bcryptCost = 12

// ErrPasswordMismatch — пароль не совпал.
var ErrPasswordMismatch = errors.New("password mismatch")

// HashPassword — текущий способ хэширования. Чистый bcrypt без SHA256-прокладки
// и без глобальной соли (bcrypt сам хранит соль внутри хэша).
func HashPassword(password string) (string, error) {
	h, err := bcrypt.GenerateFromPassword([]byte(password), bcryptCost)
	if err != nil {
		return "", err
	}
	return string(h), nil
}

// VerifyPassword — пробует современный способ, потом legacy.
// Возвращает (needsRehash=true, nil) если пароль валиден, но был
// захэширован legacy-способом — вызывающий код должен пересохранить хэш
// через `HashPassword` для перехода на новый формат.
//
// Legacy путь (SHA256+SALT перед bcrypt) — антипаттерн (см. password.go комменты),
// оставлен только для входа старых юзеров. После их первого логина пароль
// перехэшируется в новый формат, и зависимость от SALT для них пропадает.
// Когда все старые юзеры мигрируют — этот блок можно удалить вместе с ENV SALT.
func VerifyPassword(stored, password string) (needsRehash bool, err error) {
	// Современный способ: bcrypt(password).
	if err := bcrypt.CompareHashAndPassword([]byte(stored), []byte(password)); err == nil {
		return false, nil
	}

	// Legacy: bcrypt(sha256(password + global_salt)). DEPRECATED.
	salt := os.Getenv("SALT")
	digest := sha256.Sum256([]byte(password + salt))
	if err := bcrypt.CompareHashAndPassword([]byte(stored), digest[:]); err == nil {
		return true, nil
	}

	return false, ErrPasswordMismatch
}
