-- STEP 2 — the old column goes, once nothing reads or writes it.
--
-- By now every address is in the new table: the backfill copied the old ones,
-- and every release deployed since step 1 writes there.

CREATE TABLE users (
    id    uuid PRIMARY KEY,
    email text NOT NULL
);

CREATE TABLE addresses (
    id      uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users (id),
    address text NOT NULL
);

INSERT INTO users (id, email) VALUES ('u1', 'ada@example.com');
INSERT INTO addresses (id, user_id, address) VALUES ('a1', 'u1', '1 Main St');
