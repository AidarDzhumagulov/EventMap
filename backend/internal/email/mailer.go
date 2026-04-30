// Package email — отправка писем через SMTP.
//
// Интерфейс Mailer один — реализаций две:
//   - SMTPMailer — реальный SMTP (для прода)
//   - NoopMailer — пишет в логи вместо отправки (для dev/тестов)
//
// Выбор реализации делается в New() по наличию ENV SMTP_HOST.
// Это позволяет запускать сервер локально без SMTP, но видеть в логах
// какие письма ушли бы.
package email

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"strconv"

	"github.com/wneessen/go-mail"
)

// Message — общая структура для всех типов писем.
type Message struct {
	To       string
	Subject  string
	HTMLBody string
	TextBody string // fallback для клиентов без HTML
}

// Mailer — абстракция отправки. Все хендлеры зависят от неё, не от SMTP напрямую.
type Mailer interface {
	Send(ctx context.Context, msg Message) error
}

// New создаёт Mailer на основе ENV.
// Если SMTP_HOST не задан — возвращается NoopMailer (для dev).
func New() Mailer {
	host := os.Getenv("SMTP_HOST")
	if host == "" {
		slog.Warn("SMTP_HOST not set — using noop mailer (emails will be logged instead of sent)")
		return &NoopMailer{}
	}

	port, _ := strconv.Atoi(os.Getenv("SMTP_PORT"))
	if port == 0 {
		port = 587 // STARTTLS по умолчанию
	}

	return &SMTPMailer{
		host:     host,
		port:     port,
		username: os.Getenv("SMTP_USER"),
		password: os.Getenv("SMTP_PASSWORD"),
		from:     os.Getenv("SMTP_FROM"),
	}
}

// SMTPMailer — реальная отправка через SMTP с STARTTLS.
type SMTPMailer struct {
	host     string
	port     int
	username string
	password string
	from     string
}

func (m *SMTPMailer) Send(ctx context.Context, msg Message) error {
	letter := mail.NewMsg()
	if err := letter.From(m.from); err != nil {
		return fmt.Errorf("set from: %w", err)
	}
	if err := letter.To(msg.To); err != nil {
		return fmt.Errorf("set to: %w", err)
	}
	letter.Subject(msg.Subject)
	letter.SetBodyString(mail.TypeTextPlain, msg.TextBody)
	if msg.HTMLBody != "" {
		letter.AddAlternativeString(mail.TypeTextHTML, msg.HTMLBody)
	}

	client, err := mail.NewClient(m.host,
		mail.WithPort(m.port),
		mail.WithSMTPAuth(mail.SMTPAuthPlain),
		mail.WithUsername(m.username),
		mail.WithPassword(m.password),
		mail.WithTLSPolicy(mail.TLSMandatory),
	)
	if err != nil {
		return fmt.Errorf("new mail client: %w", err)
	}

	if err := client.DialAndSendWithContext(ctx, letter); err != nil {
		return fmt.Errorf("send: %w", err)
	}
	return nil
}

// NoopMailer — пишет в логи вместо отправки. Для dev и тестов.
type NoopMailer struct{}

func (m *NoopMailer) Send(_ context.Context, msg Message) error {
	slog.Info("noop mailer: would send email",
		"to", msg.To,
		"subject", msg.Subject,
		"text_body", msg.TextBody,
	)
	return nil
}
