-- STEP 1, EXPAND — the new column arrives beside the old one.
--
-- It MUST be nullable, and that is the whole content of this file. The table
-- already has rows. None of them has a value for a column that did not exist a
-- moment ago, and the code currently deployed does not write it either. A
-- nullable column is the only kind that both of those facts allow.
--
-- The row below is that existing user, seen the instant the column appears:
-- full_name is NULL, because nothing has filled it in yet.

CREATE TABLE users (
    id        uuid PRIMARY KEY,
    name      text NOT NULL,
    full_name text,
    email     text NOT NULL
);

INSERT INTO users (id, name, email, full_name)
VALUES ('u1', 'Ada', 'ada@example.com', NULL);
