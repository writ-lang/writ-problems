-- STEP 0 — the schema as it stands in production today.
--
-- A ticket is open or closed, and the database says so: the CHECK lists the
-- values. `writ sql` reads a CHECK … IN as an enumerated type, so the members
-- below are the members of a type, not a comment.

CREATE TABLE tickets (
    id     uuid PRIMARY KEY,
    status text NOT NULL CHECK (status IN ('open', 'closed'))
);

INSERT INTO tickets (id, status) VALUES ('t1', 'closed');
