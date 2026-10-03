# Adding a foreign key NOT VALID: the rows are spared, the code is not

`orders.customer_id` should point at a customer, and nothing enforces it.
The code deployed today deletes a customer and leaves their orders behind, so
the table has **orphans**. The textbook plan:

1. deploy code that re-points a customer's orders before deleting them;
2. clean up the existing orphans;
3. add the foreign key `NOT VALID`: no table scan and no long lock;
4. `VALIDATE CONSTRAINT`: checks the old rows, under a lighter lock.

`NOT VALID` is known as the safe way to add a foreign key, and it does spare
the rows already there. What it does not spare is the code still running.
From the moment the constraint exists, every write is checked, and the old
release's delete is now one the database refuses.

## The model

The SQL is [`01-before.sql`](01-before.sql) (order `o2` points at customer
`c9`, who does not exist), [`02-add-not-valid.sql`](02-add-not-valid.sql) and
[`03-validate.sql`](03-validate.sql).

`writ sql` reads a foreign key's presence, not its validation state, and says
so for both `ALTER` statements:

- `ADD CONSTRAINT … NOT VALID`: the key is read, `(fk customer-id customers)`,
  and the clause is declined, because the model would otherwise claim the key
  for rows the database never checked, like the orphan `o2 → c9` in that
  file:

  ```
  declined:
    19: NOT VALID — the constraint is read, but rows already present are not checked by it, and writ reads it as holding for every row
  ```

  It is the one decline that makes a model stricter than the database rather
  than laxer, which is why `--strict` fails on it. (Earlier versions of writ
  dropped the clause without a word. This scenario is how that was found.)
- `VALIDATE CONSTRAINT` is declined too: it "changes whether a constraint has
  been checked against existing rows, which a schema does not record".

So the model carries the state itself. [`add-a-foreign-key.writ`](add-a-foreign-key.writ)
has the constraint as `none`, `not-valid` or `validated`; the orders table's
orphans as `none` or `some`; and releases `r1`, which makes orphans, and `r2`,
which does not.

Two rules:

- `validated-means-no-orphans`: the database's own check, because
  `VALIDATE CONSTRAINT` fails while an orphan is left;
- `enforced-means-every-writer-complies`: once the constraint is enforced at
  all, no running release makes orphans. The database cannot check this one
  ahead of time. It finds out on the first refused delete.

The safe plan adds the constraint once the fleet has **settled** on r2.
[`add-a-foreign-key-shortcut.writ`](add-a-foreign-key-shortcut.writ) adds it
as soon as r2 is deploying.

## What writ answers

The safe plan exits 0. The shortcut, exit 1:

```
equation enforced-means-every-writer-complies
  …
  violated in 1 reachable situations   witness: 1. deploy-r2 2. add-not-valid → #3
```

Two steps. r1 is still serving, and from now until the rollout completes,
deleting a customer fails on every r1 instance. `validated-means-no-orphans`
is never broken: validation still waits for the cleanup. The half of the
plan everyone checks is fine.

This is the shape of `../add-a-required-column/` again: a constraint the
database enforces on behalf of code that does not yet keep it. `NOT NULL`
there, a foreign key here: two costumes for one mistake.

## Run it

```sh
writ check add-a-foreign-key.writ --claims add-a-foreign-key.claims           # exit 0
writ check add-a-foreign-key-shortcut.writ --claims add-a-foreign-key.claims  # exit 1
```

Siblings: [`../change-an-enum/`](../change-an-enum/),
[`../split-a-table/`](../split-a-table/), and the first three.
