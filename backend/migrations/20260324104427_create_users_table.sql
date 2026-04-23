-- Create "users" table
CREATE TABLE "public"."users" (
  "id" uuid NOT NULL,
  "username" text NOT NULL,
  "role" text NOT NULL,
  "rating" double precision NOT NULL DEFAULT 0,
  PRIMARY KEY ("id"),
  CONSTRAINT "users_username_key" UNIQUE ("username")
);
