-- refresh_tokens — учёт refresh-токенов для:
--  1) rotation: при /refresh старый помечается used, выдаётся новый;
--  2) reuse detection: повторное использование used-токена = кража, отзываем всю family;
--  3) logout: revoke по family_id (одна сессия) или user_id (все сессии).
CREATE TABLE refresh_tokens (
    jti        UUID PRIMARY KEY,
    family_id  UUID NOT NULL,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    issued_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at    TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_family ON refresh_tokens(family_id);
-- Для очистки протухших токенов фоновым джобом.
CREATE INDEX idx_refresh_tokens_expires ON refresh_tokens(expires_at);
