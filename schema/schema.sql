CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL,
    rating FLOAT NOT NULL DEFAULT 0,
    password TEXT NOT NULL
);