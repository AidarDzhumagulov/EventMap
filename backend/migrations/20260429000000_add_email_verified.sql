-- email_verified: помечаем что юзер подтвердил свой email через ссылку из письма.
-- Существующие юзеры считаются подтверждёнными (legacy миграция через TRUE default).
-- Новые после этой миграции — false по умолчанию (см. handler RegisterUser).
ALTER TABLE users
    ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT true;

-- Для будущих регистраций default переключим в false программно при INSERT.
-- Этот ALTER оставляет TRUE как default для совместимости.
