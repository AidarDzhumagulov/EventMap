CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL,
    rating FLOAT NOT NULL DEFAULT 0,
    password TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
);

CREATE TABLE category_types (
    id SERIAL PRIMARY KEY,
    alias VARCHAR(100) NOT NULL UNIQUE,
    name_ru VARCHAR(100) NOT NULL
);

CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    alias VARCHAR(100) NOT NULL UNIQUE,
    name_ru VARCHAR(100) NOT NULL,
    category_type_id INT NOT NULL REFERENCES category_types(id)
);
