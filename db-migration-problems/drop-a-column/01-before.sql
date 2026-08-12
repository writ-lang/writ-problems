-- STEP 0 — the table today. `legacy_flag` is the column we want to be rid of.
CREATE TABLE users (
    id          uuid PRIMARY KEY,
    email       text NOT NULL,
    legacy_flag boolean NOT NULL
);

INSERT INTO users (id, email, legacy_flag) VALUES ('u1', 'ada@example.com', false);
