-- Create "category_types" table
CREATE TABLE "public"."category_types" (
  "id" serial NOT NULL,
  "alias" character varying(100) NOT NULL,
  "name_ru" character varying(100) NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "category_types_alias_key" UNIQUE ("alias")
);
-- Create "categories" table
CREATE TABLE "public"."categories" (
  "id" serial NOT NULL,
  "alias" character varying(100) NOT NULL,
  "name_ru" character varying(100) NOT NULL,
  "category_type_id" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "categories_alias_key" UNIQUE ("alias"),
  CONSTRAINT "categories_category_type_id_fkey" FOREIGN KEY ("category_type_id") REFERENCES "public"."category_types" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION
);
