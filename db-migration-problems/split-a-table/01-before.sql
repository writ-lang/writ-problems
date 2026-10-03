-- STEP 0 — the schema as it stands in production today.
--
-- A user has one address, and it lives on the users table. The product now
-- wants several addresses per user, so the address moves to a table of its
-- own. One representative user below.

CREATE TABLE users (
    id      uuid PRIMARY KEY,
    email   text NOT NULL,
    address text NOT NULL
);

INSERT INTO users (id, email, address) VALUES ('u1', 'ada@example.com', '1 Main St');
