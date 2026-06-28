[한국어](README.md) · **English**

# harness-kit

**An opinionated, evidence-enforced, flat-rate multi-model coding protocol.**
Build with one model, review with another — and let a *zero-token shell gate*,
not a polite prompt, decide whether the work is actually done.

> Status: reference implementation / config pattern. This is a small enforcement
> tool around a protocol, **not** a framework. That honesty is the point.

---

## Why this exists

Most "AI coding harness" repos are a pile of prompts that *ask* the model to
behave. Models forget prose as context grows. harness-kit keeps the good ideas
(two-model cross-review, proof-from-logs) but moves enforcement off the LLM and
into deterministic code that **costs zero tokens to run**.

### The moat: subscription auth, no metered billing

Both engines authenticate through **flat-rate subscriptions**, not per-token API
keys:

| Role | Engine | Auth | Billing |
|------|--------|------|---------|
| Build / orchestrate | Claude (CLI) | subscription | flat-rate |
| Review / verify | Codex (`codex exec`) | **Sign in with ChatGPT** | flat-rate |

Because the enforcement and portability layers are pure shell, **fixing the
protocol's weaknesses adds exactly $0** — there is no metered path to grow.

---

## Three layers

```
┌─────────────────────────────────────────────────────────────┐
│  VALUE LAYER   build + review        Claude · Codex (subs)   │  flat-rate, the moat
├─────────────────────────────────────────────────────────────┤
│  ENFORCE LAYER gate + self-tests     bin/gate.sh · tests/    │  deterministic, 0 tokens
├─────────────────────────────────────────────────────────────┤
│  PORTABLE LAYER preflight + config   preflight.sh · *.yaml   │  env / model-agnostic
└─────────────────────────────────────────────────────────────┘
```

Fixing the weaknesses only touches the bottom two layers. The value layer
(your subscriptions) is never changed — so it can never start metering.

---

## Smart routing — solved at zero tokens

"Smart routing (prompt-classification-based dynamic routing)" usually means
**asking an LLM one more time** to classify each request — "this is coding, that
is review" — and branching on the answer. But that classification call itself
**burns tokens**: you'd be opening a metered path just to route. That collides
head-on with this kit's moat (no metering).

The fix is **exactly the same trick** that built the moat:

> Just as enforcement was moved off the LLM into a zero-token shell,
> **classification is moved off the LLM into zero-token deterministic rules.**

Instead of asking the model how to classify, the shell decides from the
request's **observable signals**:

```
request comes in
 └─ deterministic classifier (keywords · file extension · diff size — 0 tokens)
     ├─ code create/edit   → Claude CLI (build)
     ├─ review/verify ask  → codex exec (review)
     └─ simple Q&A         → Claude only, skip Codex
```

| | LLM classification (common) | Deterministic classification (this kit) |
|---|---|---|
| Decision | extra call to the model | shell decides via keywords/ext/diff size |
| Cost | tokens per classification | **0 tokens** |
| Moat impact | adds a metered path | preserves (reinforces) the moat |
| Reproducibility | can vary per call | same input → same branch, always |

This is the **zero-token version of "prompt-classification-based dynamic
routing."** Today SOUL.md's "Claude = build / Codex = review" is a *fixed* split;
add one deterministic classification layer and it becomes **dynamic** — wake
Codex only when a request needs review, skip it for simple questions. Because the
classifier is shell, it spends no tokens, so it **reinforces** the moat by the
same principle rather than threatening it.

> Note: this is a different layer from Hermes' built-in "smart routing" (which
> dynamically picks a *provider*). That one classifies via an LLM call and can
> cost tokens. What's described here is **prompt-layer deterministic branching**
> — the version that keeps billing at zero.

---

## What's in the box

| File | Purpose |
|------|---------|
| `harness.config.yaml` | single source of truth — model/provider names + gate rules |
| `bin/gate.sh` | **the gate**: blocks "done" unless artifacts + verification + cited metrics exist |
| `bin/preflight.sh` | checks engines are installed **and logged in on subscription auth** |
| `tests/test_gate.sh` | self-tests the gate (breaks fake projects, asserts it blocks) |
| `install.sh` | installs SOUL.md + the skill into a Hermes profile (backs up first, zero tokens) |
| `hermes/SOUL.md` | drop-in identity: declares the agent an AI coding orchestrator + **forces the protocol** |
| `hermes/skills/coding-harness-protocol/SKILL.md` | the full protocol the SOUL triggers (model routing · 12-step flow · proof rules) |
| `docs/SKILL.en.md` | the full protocol in English |
| `docs/INSTALL_PROMPT.md` | one-paste prompt to install via your own Hermes agent |
| `LICENSE` | MIT |

---

## Adopt it in your own Hermes

Two text files do the whole job: a `SOUL.md` that **forces** the protocol on every
coding request, and the `coding-harness-protocol` skill it triggers. `install.sh`
drops both into your Hermes profile (backing up anything it overwrites):

```bash
git clone https://github.com/ssap-pa/free-Smart-Routing-harness.git
cd free-Smart-Routing-harness
./install.sh --dry-run     # preview — changes nothing
./install.sh               # installs ~/.hermes/SOUL.md + the skill (with backups)
./bin/preflight.sh         # confirm Claude + Codex reachable on subscription auth
```

Installing into a non-default profile:

```bash
HERMES_HOME=~/.hermes/profiles/work ./install.sh
```

Prefer to let your agent do it? Paste the block in [`docs/INSTALL_PROMPT.md`](docs/INSTALL_PROMPT.md)
into your Hermes chat. After install, any coding request auto-loads the protocol,
and completion is blocked until `bin/gate.sh` passes.

### Prerequisites — connect these three

| Connect | Role | How |
|---------|------|-----|
| **Claude CLI** | build / orchestrate engine | Hermes main provider = `claude-cli` / `claude-opus-4-8` |
| **Codex CLI** | review / verify engine | `npm i -g @openai/codex` |
| **ChatGPT login** | the auth that powers Codex CLI | `codex login` → `codex login status` shows *Logged in using ChatGPT* |

`bin/preflight.sh` checks all three for you.

---

## Five weaknesses → fixes (every fix is free)

| # | Weakness in a prompt-only harness | Fix here | Cost |
|---|-----------------------------------|----------|------|
| 1 | "MUST produce X" is just a request the model can skip | `bin/gate.sh` returns **exit 1** if artifacts/verification are missing | 0 tokens |
| 2 | Model names hardcoded everywhere → rot in months | all names live in `harness.config.yaml`; scripts read them | 0 tokens |
| 3 | "Loads but no engine to route to" | `bin/preflight.sh` verifies install **and subscription login** | 0 tokens |
| 4 | Korean-only docs lock out most readers | English `README.en.md` + `docs/SKILL.en.md` | 0 tokens |
| 5 | The harness itself had no tests | `tests/test_gate.sh` proves the gate blocks | 0 tokens |

---

## Quick start

```bash
# 1. confirm engines are reachable on your subscriptions
bin/preflight.sh

# 2. ... do the work: Claude builds, `codex exec` reviews, write AI_HARNESS_LOG.md + CODEX_REVIEW*.md ...

# 3. gate the project before declaring "done"
bin/gate.sh path/to/project        # exit 0 = allowed, exit 1 = blocked

# self-test the gate any time
bash tests/test_gate.sh
```

### Wire the gate in as a real block (recommended)

Call `bin/gate.sh` from a pre-completion / stop hook (or CI step) so a failing
gate actually prevents shipping — that is what turns the protocol from a request
into a guarantee.

---

## License

MIT — see [LICENSE](./LICENSE).
