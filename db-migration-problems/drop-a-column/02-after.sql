-- STEP 1 — the column is gone. There is no step between these two files: a
-- drop is one statement, and that is exactly what makes it easy to run early.
CREATE TABLE users (
    id    uuid PRIMARY KEY,
    email text NOT NULL
);

INSERT INTO users (id, email) VALUES ('u1', 'ada@example.com');
