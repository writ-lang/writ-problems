-- STEP 0 — the schema as it stands in production today.
--
-- The row at the bottom is one representative user. `writ sql --with-data`
-- reads it, so this file is checkable on its own rather than being a fragment
-- that only means something next to the others.

CREATE TABLE users (
    id    uuid PRIMARY KEY,
    name  text NOT NULL,
    email text NOT NULL
);

INSERT INTO users (id, name, email) VALUES ('u1', 'Ada', 'ada@example.com');
