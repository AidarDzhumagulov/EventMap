DROP TABLE IF EXISTS event_members;

CREATE TYPE member_status AS ENUM ('go', 'think', 'decline');

CREATE TABLE event_members (
    event_id UUID   NOT NULL REFERENCES events(id),
    user_id  UUID   NOT NULL REFERENCES users(id),
    status   member_status NOT NULL DEFAULT 'go',
    PRIMARY KEY (event_id, user_id)
);