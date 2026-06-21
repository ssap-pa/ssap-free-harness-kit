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

## What's in the box

| File | Purpose |
|------|---------|
| `harness.config.yaml` | single source of truth — model/provider names + gate rules |
| `bin/gate.sh` | **the gate**: blocks "done" unless artifacts + verification + cited metrics exist |
| `bin/preflight.sh` | checks engines are installed **and logged in on subscription auth** |
| `tests/test_gate.sh` | self-tests the gate (breaks fake projects, asserts it blocks) |
| `docs/SKILL.en.md` | the full protocol in English |
| `LICENSE` | MIT |

---

## Five weaknesses → fixes (every fix is free)

| # | Weakness in a prompt-only harness | Fix here | Cost |
|---|-----------------------------------|----------|------|
| 1 | "MUST produce X" is just a request the model can skip | `bin/gate.sh` returns **exit 1** if artifacts/verification are missing | 0 tokens |
| 2 | Model names hardcoded everywhere → rot in months | all names live in `harness.config.yaml`; scripts read them | 0 tokens |
| 3 | "Loads but no engine to route to" | `bin/preflight.sh` verifies install **and subscription login** | 0 tokens |
| 4 | Korean-only docs lock out most readers | English `README.md` + `docs/SKILL.en.md` | 0 tokens |
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
