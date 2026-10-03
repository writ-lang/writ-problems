-- STEP 1 — the new value arrives. Tickets can now be archived.
--
-- This is instantaneous and safe: widening a CHECK rewrites nothing, and no
-- row changes. The row below is the same ticket, still closed. The migration
-- in the sense that matters has not happened yet. It happens the first time
-- something WRITES 'archived', and every release still running then has to be
-- able to read it.

CREATE TABLE tickets (
    id     uuid PRIMARY KEY,
    status text NOT NULL CHECK (status IN ('open', 'closed', 'archived'))
);

INSERT INTO tickets (id, status) VALUES ('t1', 'closed');
