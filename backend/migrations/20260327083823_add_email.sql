-- Modify "users" table
ALTER TABLE "public"."users" ADD COLUMN "email" text NOT NULL, ADD CONSTRAINT "users_email_key" UNIQUE ("email");
