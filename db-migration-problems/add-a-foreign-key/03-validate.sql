-- STEP 2 — the constraint is validated.
--
-- VALIDATE CONSTRAINT scans the existing rows, without the heavy lock. It
-- fails if an orphan is left, so the orphans are deleted (or re-pointed) first;
-- order o2 is gone below. After this the database guarantees what the code
-- always assumed.
--
-- `writ sql --strict` declines this ALTER: it changes the validation state of
-- a constraint, and a schema has no such state. The model carries it instead.

CREATE TABLE customers (
    id uuid PRIMARY KEY
);

CREATE TABLE orders (
    id          uuid PRIMARY KEY,
    customer_id uuid NOT NULL REFERENCES customers (id)
);

ALTER TABLE orders VALIDATE CONSTRAINT orders_customer_fk;

INSERT INTO customers (id) VALUES ('c1');
INSERT INTO orders (id, customer_id) VALUES ('o1', 'c1');
