-- STEP 2, CONTRACT — the old column goes, once nothing reads or writes it.
--
-- By now every row has a full_name (the backfill saw to the old ones, and
-- every release deployed since the expand writes it), so the new column can be
-- NOT NULL here even though it could not be in step 1.

CREATE TABLE users (
    id        uuid PRIMARY KEY,
    full_name text NOT NULL,
    email     text NOT NULL
);

INSERT INTO users (id, full_name, email) VALUES ('u1', 'Ada', 'ada@example.com');
