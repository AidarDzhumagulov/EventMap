ALTER TABLE "public"."events"
    ADD COLUMN IF NOT EXISTS "invite_code" VARCHAR(8) DEFAULT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "idx_events_invite_code"
    ON "public"."events" ("invite_code")
    WHERE invite_code IS NOT NULL;
