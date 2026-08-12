-- STEP 1 DONE WRONG — the same file with one phrase added: NOT NULL.
--
-- This is the most common way to get the expand step wrong. It passes review
-- because NOT NULL is good practice everywhere else, and it passes on an empty
-- database because there are no rows to contradict it.
--
-- The row below is the same existing user, and it is what makes the mistake
-- provable rather than merely visible: it has no full_name, because at this
-- instant no row does.

CREATE TABLE users (
    id        uuid PRIMARY KEY,
    name      text NOT NULL,
    full_name text NOT NULL,
    email     text NOT NULL
);

INSERT INTO users (id, name, email, full_name)
VALUES ('u1', 'Ada', 'ada@example.com', NULL);
