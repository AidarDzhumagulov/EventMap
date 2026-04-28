-- Partial index для быстрого подсчёта members_count в выдаче событий.
-- Используется в JOIN-агрегации в event_repository.go (eventSelect const).
CREATE INDEX IF NOT EXISTS idx_event_members_event_go
    ON event_members(event_id)
    WHERE status = 'go';
