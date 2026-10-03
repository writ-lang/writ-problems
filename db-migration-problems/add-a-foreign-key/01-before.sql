-- STEP 0 — the schema as it stands in production today.
--
-- orders.customer_id points at a customer, but nothing says so: there is no
-- foreign key. So the data has drifted. The code deployed today deletes a
-- customer without touching their orders, and order o2 below belongs to a
-- customer who no longer exists — an ORPHAN.

CREATE TABLE customers (
    id uuid PRIMARY KEY
);

CREATE TABLE orders (
    id          uuid PRIMARY KEY,
    customer_id uuid NOT NULL
);

INSERT INTO customers (id) VALUES ('c1');
INSERT INTO orders (id, customer_id) VALUES ('o1', 'c1');
INSERT INTO orders (id, customer_id) VALUES ('o2', 'c9');
