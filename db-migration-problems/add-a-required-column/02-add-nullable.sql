-- STEP 1 — the column arrives, nullable, because the rows that already exist
-- have no value for it.
CREATE TABLE users (
    id      uuid PRIMARY KEY,
    email   text NOT NULL,
    country text
);

INSERT INTO users (id, email, country) VALUES ('u1', 'ada@example.com', NULL);
