CREATE TABLE saved_events (
    event_id   UUID NOT NULL REFERENCES events(id),
    user_id    UUID NOT NULL REFERENCES users(id),
    saved_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (event_id, user_id)
);