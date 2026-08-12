-- STEP 2 — the column becomes required.
--
-- This file is only correct at the right MOMENT. By the time it runs, two
-- things must already be true: every existing row has a country (the backfill),
-- and every running release writes one (the deploy). Neither fact is visible
-- here, and that is what the rest of this directory is about.
CREATE TABLE users (
    id      uuid PRIMARY KEY,
    email   text NOT NULL,
    country text NOT NULL
);

INSERT INTO users (id, email, country) VALUES ('u1', 'ada@example.com', 'GB');
