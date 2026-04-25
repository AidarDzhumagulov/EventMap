-- Create "events" table
CREATE TABLE "public"."events" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" character varying(255) NOT NULL,
  "description" text NULL,
  "cover_url" character varying(500) NULL,
  "lat" double precision NOT NULL,
  "lon" double precision NOT NULL,
  "city_name" character varying(100) NOT NULL,
  "start_time" timestamptz NOT NULL,
  "end_time" timestamptz NULL,
  "is_private" boolean NOT NULL DEFAULT false,
  "status" character varying(20) NOT NULL DEFAULT 'upcoming',
  "max_members" integer NULL,
  "category_id" integer NULL,
  "organization_id" uuid NULL,
  "location_id" uuid NULL,
  "created_by" uuid NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NULL,
  "updated_by" uuid NULL,
  "deleted_at" timestamptz NULL,
  "deleted_by" uuid NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "events_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT "events_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT "events_deleted_by_fkey" FOREIGN KEY ("deleted_by") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT "events_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION
);
-- Create index "idx_events_city" to table: "events"
CREATE INDEX "idx_events_city" ON "public"."events" ("city_name");
-- Create index "idx_events_created_by" to table: "events"
CREATE INDEX "idx_events_created_by" ON "public"."events" ("created_by");
-- Create index "idx_events_start_time" to table: "events"
CREATE INDEX "idx_events_start_time" ON "public"."events" ("start_time");
-- Create index "idx_events_status" to table: "events"
CREATE INDEX "idx_events_status" ON "public"."events" ("status");
