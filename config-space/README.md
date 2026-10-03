# The configuration space: every combination, not a sample

A product deployment has feature flags and modes: SSO on or off, legacy
password login, multi-tenancy, an audit log, a region, a database that is
single or sharded. Some combinations are forbidden by the product's own
rules, and the admin operations that change the configuration are supposed to
refuse the steps that would reach them.

The usual check is a test matrix that samples combinations. Here there are
four flags and two two-valued modes: 2⁶ = 64 combinations. That is the whole
space, and writ walks all of it. The interesting finding is not a forbidden
combination a sample missed. It is one reached only by doing allowed steps in
a particular **order**, which no test of single configurations or single
steps can produce.

## The model

[`config-space.writ`](config-space.writ) has one `config` entity, `cfg`, and
four rules as laws:

| rule | in words |
| --- | --- |
| `audit-when-multi-tenant` | tenants' actions are audited |
| `no-legacy-in-eu` | password login is not offered in the EU deployment |
| `some-auth` | somebody can log in: SSO or legacy auth is on |
| `sharded-needs-sso` | the sharded database routes on the SSO tenant id |

Each admin operation (`enable-sso`, `disable-sso`, `enable-legacy-auth`, …,
`move-to-eu`, `move-to-us`, `shard`) checks in its `when` the rules it could
break. Writing those guards is the work: each is a rule read as a
precondition. `shard` is one-way, because sharding migrates the data and
nothing undoes it.

[`config-space-shortcut.writ`](config-space-shortcut.writ) leaves out one
condition. `disable-sso` checks that somebody can still log in, but not that
the database is unsharded. The check that remains is the obvious one: SSO is
an authentication flag, and its guard checks authentication. The one that is
gone belongs to another subsystem, and to a mode that changes once in the
product's life.

## What writ answers

The questions are in [`config-space.claims`](config-space.claims). The guarded
operations, exit 0:

```
states: 21   edges: 67
…
holds  fully-featured
  "a safe configuration with tenants, SSO and a sharded database exists"
holds  never-unsafe
  "no configuration the product forbids is ever reached"
holds  recoverable
holds  can-leave-eu
```

21 of the 64 combinations are reachable from the starting configuration, and
the four rules allow exactly 21. So the guarded operations reach every allowed
configuration and nothing else. The guards forbid nothing the rules allow,
and admit nothing they forbid.

The shortcut, exit 1:

```
equation sharded-needs-sso
  …
  violated in 3 reachable situations   witness: 1. enable-legacy-auth 2. shard 3. disable-sso → #15
…
fails  never-unsafe
  witness:  1. enable-legacy-auth   → #1   cfg.legacy-auth: no → yes
            2. shard                → #7   cfg.db-mode: single → sharded
            3. disable-sso          → #15   cfg.sso: yes → no
holds  recoverable
```

Each step is allowed, and the order is the finding. Turn SSO off first and
`shard` refuses, because it checks SSO. Shard first and `disable-sso` lets you
through, because it does not check the database. A test of `disable-sso` on a
single-database configuration passes. A test of `shard` without SSO is
refused. The failing path exists only in this sequence.

`recoverable` still holds: `enable-sso` repairs it. So the shortcut never
traps anyone, which is why the bug would ship. The broken configuration is a
state production can sit in until someone notices the router failing.

### Per region

FR-10's fibers answer the same question once per value of a cell:

```sh
writ check config-space-shortcut.writ --claims config-space.claims --fiber cfg.region
```

```
fails  never-unsafe
  …
  fiber cfg.region=us   FAILS   witness: 1. enable-legacy-auth 2. shard 3. disable-sso → #15
  fiber cfg.region=eu   holds
```

Only the US deployment can reach it. The EU forbids legacy auth, and turning
it on is the first step of the route. So the EU deployment is safe from this
bug because of a rule about a different thing. That protection is
accidental, and the fiber line shows it.

## A release that adds a flag

[`config-space-v2.writ`](config-space-v2.writ) is the guarded model plus one
flag, `new-billing`. The new billing system bills per tenant, so its enable
operation also turns multi-tenancy on. It was reviewed as a billing change.

```sh
writ compare config-space.writ config-space-v2.writ   # exit 1
```

```
equations:   audit-when-multi-tenant  preserved
             no-legacy-in-eu          preserved
             some-auth                preserved
             sharded-needs-sso        preserved
properties:  fully-featured           preserved
             never-unsafe             LOST      witness: 1. enable-new-billing
             recoverable              preserved
             can-leave-eu             preserved
```

One move: multi-tenancy on, audit log off, the first rule broken. A release
that adds a flag adds operations, and `compare` checks the operations, not
the flag. `writ check` on v2 says the same from the other side:

```
unadmitted  enable-new-billing may break audit-when-multi-tenant
```

The claims file lists every operation the team has agreed can touch each
rule. A new one that can is reported until someone either guards it or signs
it off.

## What the latch costs

[`config-space.rules`](config-space.rules) asks, with no goal in mind, which
configurations are in the last phase, the ones that can never get back to an
earlier one:

```sh
writ derive config-space.writ config-space.rules final-db
```

All nine rows say `sharded`. Every configuration on a single database can be
left and returned to, and every sharded one can only go to other sharded ones.
That is what one irreversible operation does to a configuration space: it
divides it in two, and a deployment crosses once.

## What is not modelled

Values, only members: a flag is on or off, a region is one of two. A flag
whose default differs by region would be a fixed arrow on the region, not a
cell. And every operation is available at any time to whoever administers the
deployment. Who may run which operation is the entitlement problems' subject
(`../entitlement-problems/`), and the two compose.

## Run it

```sh
writ check config-space.writ --claims config-space.claims                              # exit 0
writ check config-space-shortcut.writ --claims config-space.claims --fiber cfg.region  # exit 1
writ compare config-space.writ config-space-v2.writ                                    # exit 1
```

`../modality-cross-check.sh` checks the `.rules` encoding against `writ check`.
