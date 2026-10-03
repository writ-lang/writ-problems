# An AI agent's tool policy, and the read-only tool that leaks

An AI coding agent works through tools: read a file, run a shell command,
fetch a web page. Its harness applies a **policy** to every call. Some tools
are allowed outright. The rest wait for a human to say yes. In **ask** mode
the human is there. In **auto** mode the agent works on its own with the
tools the policy allows, which is the point of auto mode, and also its risk.

The security question is never "would the agent do this". A web page the
agent reads can carry instructions (prompt injection), so any call the policy
permits is a call that can happen. The question is "would the policy let it".

Version 1 of the policy allows file reading outright and makes the shell ask.
Version 2 adds one tool, `web-fetch`, allowed outright because "it only reads
pages". It cannot open a file, so it cannot leak one. It doesn't need to. The
agent read the API key earlier with a tool that was allowed to, and a request
to a URL carries whatever is in the URL.

## The model

[`agent-guardrails.writ`](agent-guardrails.writ) has:

- a **session** whose `mode` is `ask` or `auto`. The human switches it either
  way (`switch-to-auto`, `switch-to-ask`);
- **tools** with what they *can* do, a fact (`reads-secrets`, `reaches-net`),
  and whether the policy *allows* them outright, a decision (`allowed`);
- one **secret**, `api-key`: whether it is in the agent's context, and whether
  it has left, `stayed`, `approved` or `silent`;
- an approval **queue** holding the call waiting on the human, if any.

The agent's moves are written per tool. `read-secret-with-file-read` puts the
key in context. `send-secret-with-T` sends it out with no one asked, and needs
auto mode, a tool allowed outright and a tool that reaches the network.
`ask-to-send-with-T` puts any other network call to the human, who answers
with `human-approves-T` or `human-denies`.

One rule is a law: `no-silent-exfiltration`, the secret never ends up `silent`.

[`agent-guardrails-v2.writ`](agent-guardrails-v2.writ) is version 1 plus the
`web-fetch` tool and the one move its permissions create.

## What writ answers

The human's questions are in [`agent-guardrails.claims`](agent-guardrails.claims).
Version 1, exit 0:

```
states: 8   edges: 16
…
holds  useful
  "the agent can work on its own with what it has read"
holds  human-can-release
  "a human can still choose to send the secret"
holds  no-unapproved-exfiltration
  "a secret never leaves without a human saying yes"
holds  human-can-interrupt
  "from every situation, the human can still get back to ask mode"
```

Then compare the two versions:

```sh
writ compare agent-guardrails.writ agent-guardrails-v2.writ   # exit 1
```

```
equations:   no-silent-exfiltration      preserved
properties:  useful                      preserved
             human-can-release           preserved
             no-unapproved-exfiltration  LOST      witness: 1. switch-to-auto 2. read-secret-with-file-read 3. send-secret-with-web-fetch
             human-can-interrupt         preserved
```

**Under policy v2, a secret leaves the machine in three moves with no human
decision among them: switch to auto mode, read a file that holds the key,
fetch a URL.** That sentence can go straight into the policy ticket.

`writ check` on version 2 adds two details. The verdict names the tool, from
the `(show carrier)` on the property:

```
fails  no-unapproved-exfiltration
  …
  carrier  (at state 6)
    t = web-fetch
```

The second detail is a line the human's claims file caused:

```
unadmitted  send-secret-with-web-fetch may break no-silent-exfiltration
```

The new tool created a move that can break the rule, and nobody acknowledged
it. writ reports that before anyone asks.

[`agent-guardrails.rules`](agent-guardrails.rules) lists every unasked
exfiltration with its tool and the mode at the time:

```
exfil-path  (4 rows)
  6  web-fetch  auto
  9  web-fetch  auto
  10  web-fetch  ask
  11  web-fetch  ask
```

The `ask` rows are situations where the secret had already left and the human
switched back afterwards. Switching back closes nothing that already happened.

## The loop

The architecture the writ recommendations propose: an LLM writes or edits the
model, writ verifies it, and the LLM revises until it holds. That works only
under one discipline: **the claims file is the human's, and the agent may not
edit it.** An agent told "make v2 pass" can change the policy. It cannot
change the questions. Two attempts are in this directory, and both were run
against the unedited `agent-guardrails.claims`.

**The honest fix:** [`attempt-fetch-asks.writ`](attempt-fetch-asks.writ) stops
allowing `web-fetch` outright, so a fetch asks like the shell does. Every
question holds, `useful` included: the agent still works on its own in auto
mode. `check` still exits 1:

```
unadmitted  human-approves-web-fetch may break no-silent-exfiltration
```

The fix added a new way for the secret to leave, through a human's approval.
Whether that is acceptable is the human's call, so the acknowledgement goes in
the human's file. `writ compare agent-guardrails.writ attempt-fetch-asks.writ`
exits 0: nothing v1 guaranteed was lost.

**The cheat:** [`attempt-forget-out.writ`](attempt-forget-out.writ) changes
nothing the policy allows. It deletes the record of the secret leaving: the
`out` arrow, and the law that read it. Every dangerous call is still there.

```
holds  useful
n/a  human-can-release
n/a  no-unapproved-exfiltration
holds  human-can-interrupt
certified: every answer re-derived from the model (writ-cert)
```

`n/a` means the question names something the model no longer has, so it was
not answered. No property failed, because the one that would have was taken
away. That is why `writ check` treats an `n/a` as a finding and **exits 1** on
this file: a gate that reads the exit status cannot be talked out of its
question. (Earlier versions of writ exited 0 here. This scenario is how that
was found.)

`compare` against the last version the human approved says what was taken:

```sh
writ compare agent-guardrails.writ attempt-forget-out.writ   # exit 1
```

```
equations:   no-silent-exfiltration      LOST
properties:  useful                      preserved
             human-can-release           LOST
             no-unapproved-exfiltration  LOST
             human-can-interrupt         preserved
```

writ's MCP server already enforces both halves. It reads `.claims` from the
human's directory whatever path the agent passes, and it reports what each
edit lost, `n/a` included (see writ's `docs/mcp.md`). From the command line,
`check` exits 1 on an `n/a`, and `--json` carries `"verdict": "n/a"` for a
script that wants to say why.

## What to take away

A tool's risk is not what it can read but what it can carry. `web-fetch` was
judged on the first and was dangerous on the second, because the danger needs
two tools: one that puts the secret in context and one that sends context
out. Neither is a problem alone, and a review that looks at one tool at a
time passes both.

To adapt it, list your harness's tools with what each can read and reach,
give the secret the places it can come from, and write the policy as
`allowed`. The questions carry over unchanged.

## Run it

```sh
writ check agent-guardrails.writ --claims agent-guardrails.claims          # exit 0
writ compare agent-guardrails.writ agent-guardrails-v2.writ                # exit 1
writ check attempt-forget-out.writ --claims agent-guardrails.claims        # exit 1: two n/a
writ compare agent-guardrails.writ attempt-forget-out.writ                 # exit 1
```

`../modality-cross-check.sh` checks the `.rules` encoding against `writ check`.
