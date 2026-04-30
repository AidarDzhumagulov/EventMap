-- Токены сброса пароля. Одноразовые, с TTL 1 час.
-- used_at — защита от повторного использования (атакующий получил токен из письма
-- но юзер уже сбросил пароль; повторный reset через тот же токен не должен сработать).
CREATE TABLE password_reset_tokens (
    token      TEXT PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_password_reset_user ON password_reset_tokens(user_id);
CREATE INDEX idx_password_reset_expires ON password_reset_tokens(expires_at);
