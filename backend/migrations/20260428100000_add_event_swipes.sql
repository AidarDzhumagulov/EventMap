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
