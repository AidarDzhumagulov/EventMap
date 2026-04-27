CREATE TYPE business_role AS ENUM ('owner', 'manager', 'smm');

CREATE TABLE "public"."organizations" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" character varying(255) NOT NULL,
  "description" text NULL,
  "is_verified" boolean NOT NULL DEFAULT false,
  "billing_info" text NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "created_by" uuid NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "organizations_created_by_fkey"
    FOREIGN KEY ("created_by") REFERENCES "public"."users" ("id")
    ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE "public"."business_members" (
  "user_id" uuid NOT NULL,
  "organization_id" uuid NOT NULL,
  "role" business_role NOT NULL DEFAULT 'manager',
  "joined_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("user_id", "organization_id"),
  CONSTRAINT "business_members_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "public"."users" ("id")
    ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "business_members_organization_id_fkey"
    FOREIGN KEY ("organization_id") REFERENCES "public"."organizations" ("id")
    ON UPDATE NO ACTION ON DELETE CASCADE
);

CREATE INDEX "idx_business_members_org" ON "public"."business_members" ("organization_id");
CREATE INDEX "idx_business_members_user" ON "public"."business_members" ("user_id");
