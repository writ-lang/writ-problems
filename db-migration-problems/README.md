# Database migration problems

Three worked examples. Each one is a schema change that looks routine, has a
plan that reads correctly, and goes wrong anyway — and each one ends with `pol`
refusing the wrong version and naming the step responsible.

You do not need to know anything about `pol` to read any of them. Each has its
own page, written from the beginning.

---

## The three

| problem | the mistake | how far in |
| --- | --- | --- |
| [`drop-a-column/`](drop-a-column/) | dropping a column while a release that still reads it is live | **2 moves** |
| [`add-a-required-column/`](add-a-required-column/) | adding `NOT NULL` before the code that supplies a value is deployed | **3 moves** |
| [`rename-a-column/`](rename-a-column/) | switching readers to the new column before the backfill finishes | **4 moves** |

They are listed easiest first. `drop-a-column/` is the smallest thing here —
four situations, three steps — and is the one to read if you only read one.

## What they have in common

Each directory holds the same five things:

- **The SQL.** One `.sql` file per step of the migration, which is what you
  would actually write. Each carries a single representative row, so each file
  can be checked on its own.
- **A plan** that is safe.
- **The same plan with one thing removed** — one word, one condition, one
  conjunct. That is the whole difference between the two files.
- **One set of questions**, asked of both plans. Holding the questions fixed is
  what makes the comparison mean something: any difference in the answers comes
  from the change and from nothing else.
- **A second copy of the questions**, written a different way, so that two
  independent parts of `pol` answer them and can be checked against each other.

And each one ends the same way. The safe plan exits 0. The shortcut exits 1,
says which rule broke, how many situations are affected, and prints the
shortest route to one of them.

## Three things that are true of all three

**The unsafe plan is always faster.** Two steps instead of three. Three instead
of five. Four instead of nine. That is not a coincidence — the removed
condition is always a *wait*, and skipping a wait is exactly what makes a
migration shorter. Whatever intuition tells you the quick version is fine, it
was going to say that.

**The unsafe plan still finishes.** In all three, the shortcut reaches the
intended end state and never gets stuck. Every question you would naturally ask
— does it work, does it complete, can it get stranded — answers in its favour.
The only question that catches it is whether it is safe *on the way*.

**The mistake is never in a file.** In two of the three, every SQL file and
every release is individually correct. What is wrong is the order, or the
moment, and neither of those is written down anywhere a reviewer can look. That
is the argument for writing the sequence down at all.

## Where the DDL helps, and where it stops

`rename-a-column/` has one mistake that *is* visible in a single file: adding
the new column as `NOT NULL` during the expand step. `pol sql` reads the DDL
into a model, and the good and bad versions differ by a single character —
`text?` against `text`. Because the file also carries a row that predates the
column, the bad version is not merely different but refused:

```console
$ pol sql 02-expand-wrong.sql --with-data > wrong.pol
$ pol check wrong.pol
pol: wrong.pol: value out of domain for cell users.full-name for u1
```

That is worth knowing on its own: some migration mistakes can be caught from
one file, before anything is deployed, with no model to write.

But that is where the DDL stops. A `.sql` file says what the table looks like
at that step. It does not say when to run the step relative to a deploy, and it
does not say what your code reads and writes. Every other mistake in this
folder lives in exactly those two gaps.

## Running them

With `pol` installed (see the
[install instructions](https://github.com/sajonaro/pol#install)), from any of
the three directories:

```console
$ pol check drop-a-column.pol --claims drop-a-column.claims           # exit 0
$ pol check drop-a-column-shortcut.pol --claims drop-a-column.claims  # exit 1
```

Or run all of them, with the rest of the repository's checks, from the top:

```console
$ ./run-tests.sh
```

## Using one on your own migration

Start from whichever of the three is closest to what you are doing, and change
four things:

1. **The columns**, and for each one whether it exists, whether every row has a
   value, and whether it is required.
2. **What each release of your code reads and writes.** Take this from the
   code, not from the plan — the plan says what you meant.
3. **The steps**, and the condition on each: the precondition you are claiming
   to have checked before you run it.
4. Usually nothing in **the rules**. They are about columns and releases in
   general, not about your particular column, so they tend to carry over
   unchanged.

If you add a step, `pol` will tell you it is unacknowledged and exit 1 until you
say, in the questions file, that you have considered which rules it could
affect. That is deliberate.
