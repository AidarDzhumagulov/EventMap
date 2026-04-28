CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL,
    rating FLOAT NOT NULL DEFAULT 0,
    password TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
);

CREATE TABLE category_types (
    id SERIAL PRIMARY KEY,
    alias VARCHAR(100) NOT NULL UNIQUE,
    name_ru VARCHAR(100) NOT NULL
);

CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    alias VARCHAR(100) NOT NULL UNIQUE,
    name_ru VARCHAR(100) NOT NULL,
    category_type_id INT NOT NULL REFERENCES category_types(id)
);

CREATE TABLE events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    cover_url       VARCHAR(500),
    lat             DOUBLE PRECISION NOT NULL,
    lon             DOUBLE PRECISION NOT NULL,
    city_name       VARCHAR(100) NOT NULL,
    start_time      TIMESTAMPTZ NOT NULL,
    end_time        TIMESTAMPTZ,
    is_private      BOOLEAN NOT NULL DEFAULT false,
    status          VARCHAR(20) NOT NULL DEFAULT 'upcoming',
    max_members     INT,
    category_id     INT REFERENCES categories(id),
    organization_id UUID,
    location_id     UUID,
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ,
    updated_by      UUID REFERENCES users(id),
    deleted_at      TIMESTAMPTZ,
    deleted_by      UUID REFERENCES users(id)
);

CREATE INDEX idx_events_city ON events(city_name);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_created_by ON events(created_by);
CREATE INDEX idx_events_start_time ON events(start_time);

CREATE TYPE member_status AS ENUM ('go', 'think', 'decline');

CREATE TABLE event_members (
    event_id   UUID NOT NULL REFERENCES events(id),
    user_id    UUID NOT NULL REFERENCES users(id),
    status     member_status NOT NULL DEFAULT 'go',
    PRIMARY KEY (event_id, user_id)
);

-- Partial index для быстрого подсчёта members_count в eventSelect.
-- Покрывает только status='go' (90%+ записей), компактнее full index.
CREATE INDEX idx_event_members_event_go
    ON event_members(event_id)
    WHERE status = 'go';

CREATE TABLE saved_events (
    event_id   UUID NOT NULL REFERENCES events(id),
    user_id    UUID NOT NULL REFERENCES users(id),
    saved_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (event_id, user_id)
);

-- Учёт refresh-токенов для rotation, reuse-detection и logout.
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
CREATE INDEX idx_refresh_tokens_expires ON refresh_tokens(expires_at);

-- Скипы для анти-повтора в свайп-ленте.
-- Лайки хранятся в saved_events, RSVP — в event_members.
-- GetFeed фильтрует все три таблицы.
CREATE TABLE event_swipes (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id   UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    swiped_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, event_id)
);

CREATE INDEX idx_event_swipes_user ON event_swipes(user_id);
