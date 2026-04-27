CREATE TABLE "public"."locations" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "lat" double precision NOT NULL,
  "lon" double precision NOT NULL,
  "address" text NULL,
  "name" text NULL,
  "provider" character varying(50) NOT NULL DEFAULT 'nominatim',
  "external_id" text NULL,
  PRIMARY KEY ("id")
);

ALTER TABLE "public"."events"
  ADD CONSTRAINT "events_location_id_fkey"
  FOREIGN KEY ("location_id") REFERENCES "public"."locations" ("id")
  ON UPDATE NO ACTION ON DELETE NO ACTION;
