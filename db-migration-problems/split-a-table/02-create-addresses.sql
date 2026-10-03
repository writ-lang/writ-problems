-- STEP 1 — the new table arrives beside the old column.
--
-- Nothing is moved yet. The code deployed next writes BOTH places (the
-- "dual write"), and a backfill copies the rows that existed before it. Until
-- the backfill finishes, the new table holds some addresses and not others,
-- and no row in this file says which: that is exactly what the model has to
-- carry as state of its own. Here, mid-backfill, Ada's address has not been
-- copied yet, so `addresses` has no row.
--
-- `user_id REFERENCES users` is a foreign key, and `writ sql` reads it as an
-- arrow from an address to a user.

CREATE TABLE users (
    id      uuid PRIMARY KEY,
    email   text NOT NULL,
    address text NOT NULL
);

CREATE TABLE addresses (
    id      uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users (id),
    address text NOT NULL
);

INSERT INTO users (id, email, address) VALUES ('u1', 'ada@example.com', '1 Main St');
