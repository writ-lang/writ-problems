-- STEP 1 — the constraint arrives, NOT VALID.
--
-- A plain ADD CONSTRAINT … FOREIGN KEY scans the whole table under a lock,
-- and fails if any row is an orphan. NOT VALID skips the scan: rows already
-- there are not checked, but every INSERT, UPDATE and DELETE from now on is.
-- That last part is easy to miss, and it is the one that matters: the release
-- still running deletes customers without touching their orders, and from
-- this moment the database refuses those deletes.

CREATE TABLE customers (
    id uuid PRIMARY KEY
);

CREATE TABLE orders (
    id          uuid PRIMARY KEY,
    customer_id uuid NOT NULL
);

ALTER TABLE orders
    ADD CONSTRAINT orders_customer_fk
    FOREIGN KEY (customer_id) REFERENCES customers (id)
    NOT VALID;

INSERT INTO customers (id) VALUES ('c1');
INSERT INTO orders (id, customer_id) VALUES ('o1', 'c1');
INSERT INTO orders (id, customer_id) VALUES ('o2', 'c9');
