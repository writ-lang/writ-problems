-- STEP 0 — the table today. There is no country on a user at all.
CREATE TABLE users (
    id    uuid PRIMARY KEY,
    email text NOT NULL
);

INSERT INTO users (id, email) VALUES ('u1', 'ada@example.com');
