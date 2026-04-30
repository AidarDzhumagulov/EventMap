package email

import (
	"fmt"
	"os"
)

// appURL — базовый URL фронта/универсальной ссылки.
// Используется в письмах для построения ссылок подтверждения и сброса.
// На прод: APP_URL=https://eventmap.example.com
// В dev: deeplink eventmap://...
func appURL() string {
	if u := os.Getenv("APP_URL"); u != "" {
		return u
	}
	return "eventmap://"
}

// VerificationEmail — письмо для подтверждения email при регистрации.
func VerificationEmail(to, username, token string) Message {
	link := fmt.Sprintf("%s/verify-email?token=%s", appURL(), token)

	html := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: -apple-system, system-ui, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
  <h2 style="color: #1A1A2E;">Привет, %s!</h2>
  <p>Подтверди свой email чтобы продолжить пользоваться Event Map:</p>
  <p style="margin: 24px 0;">
    <a href="%s" style="background: #6B21A8; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; display: inline-block;">
      Подтвердить email
    </a>
  </p>
  <p style="color: #666; font-size: 13px;">Ссылка действительна 24 часа.</p>
  <p style="color: #999; font-size: 12px;">
    Если ты не регистрировался — просто проигнорируй это письмо.
  </p>
</body>
</html>`, username, link)

	text := fmt.Sprintf(`Привет, %s!

Подтверди свой email чтобы продолжить пользоваться Event Map:
%s

Ссылка действительна 24 часа.

Если ты не регистрировался — проигнорируй это письмо.`, username, link)

	return Message{
		To:       to,
		Subject:  "Подтверди email — Event Map",
		HTMLBody: html,
		TextBody: text,
	}
}

// PasswordResetEmail — письмо со ссылкой для сброса пароля.
func PasswordResetEmail(to, username, token string) Message {
	link := fmt.Sprintf("%s/reset-password?token=%s", appURL(), token)

	html := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: -apple-system, system-ui, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
  <h2 style="color: #1A1A2E;">Сброс пароля</h2>
  <p>Привет, %s. Кто-то запросил сброс пароля для твоего аккаунта.</p>
  <p style="margin: 24px 0;">
    <a href="%s" style="background: #6B21A8; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; display: inline-block;">
      Сбросить пароль
    </a>
  </p>
  <p style="color: #666; font-size: 13px;">Ссылка действительна 1 час.</p>
  <p style="color: #999; font-size: 12px;">
    Если это был не ты — просто проигнорируй письмо. Твой пароль не изменится.
    После сброса все активные сессии будут отозваны из соображений безопасности.
  </p>
</body>
</html>`, username, link)

	text := fmt.Sprintf(`Привет, %s.

Кто-то запросил сброс пароля для твоего аккаунта Event Map.

Перейди по ссылке чтобы установить новый пароль:
%s

Ссылка действительна 1 час.

Если это был не ты — проигнорируй письмо. Твой пароль не изменится.`, username, link)

	return Message{
		To:       to,
		Subject:  "Сброс пароля — Event Map",
		HTMLBody: html,
		TextBody: text,
	}
}
