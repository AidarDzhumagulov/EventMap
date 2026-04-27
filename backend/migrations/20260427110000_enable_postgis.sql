CREATE EXTENSION IF NOT EXISTS postgis;

ALTER TABLE "public"."events"
  ADD COLUMN IF NOT EXISTS "geom" geometry(Point, 4326) NULL;

UPDATE "public"."events"
  SET geom = ST_SetSRID(ST_MakePoint(lon, lat), 4326)
  WHERE geom IS NULL AND lat IS NOT NULL AND lon IS NOT NULL;

CREATE INDEX IF NOT EXISTS "idx_events_geom"
  ON "public"."events" USING GIST (geom);
