package auth

import (
	"crypto/rand"
	"encoding/base64"
)

// RandomToken генерит криптографически стойкий случайный токен в URL-safe base64.
// Используется для верификации email и сброса пароля — там нужна непредсказуемость
// (не UUID — у того есть энтропия меньше идеала и предсказуемая структура).
//
// 32 байта = 256 бит энтропии — больше чем хватает.
func RandomToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}
