# Codex Review — harness-kit

Reviewer engine: `codex exec -m gpt-5.5` (official CLI, ChatGPT subscription / flat-rate).
Routing proof: each review = a real `~/.codex/sessions/` rollout file, `codex` exit 0.
One file = one request (per protocol).

## Round 1 — bin/gate.sh
- session: `019eeba5-5d5f-7692-a5de-20453c7aed9a`
- usage: 36204 tokens (~/.codex/sessions/2026/06/22/rollout-2026-06-22T04-25-43-019eeba5-5d5f-7692-a5de-20453c7aed9a.jsonl)
- exit: 0

| Sev | Finding | Resolution |
|-----|---------|------------|
| High | none | — |
| Medium | no-hand-metrics grep missed `tokens: 1234` / comma digits | **fixed** — bidirectional regex + comma support |
| Medium | `compgen -G "$PROJECT/$g"` let `$PROJECT` metachars act as glob; didn't require a regular file | **fixed** — glob inside `$PROJECT`, require `-f` |
| Low | `cfg()` matched indented/nested keys | **fixed** — anchored to top-level keys, escape dots |
| Low | comment-strip breaks quoted `#`; comma can't appear in a value | **documented** as a by-design parser limit in config |
| Nit | emoji output in minimal terminals | accepted (cosmetic) |

## Round 1 — bin/preflight.sh
- session: `019eeba6-64ad-7822-9221-8ae6bfd62f77`
- usage: 27064 tokens (~/.codex/sessions/2026/06/22/rollout-2026-06-22T04-26-51-019eeba6-64ad-7822-9221-8ae6bfd62f77.jsonl)
- exit: 0

| Sev | Finding | Resolution |
|-----|---------|------------|
| High | login check `grep 'logged in\|chatgpt'` false-passes on **"Not logged in"** | **fixed** — reject negative text first, then accept positive |
| Medium | `pipefail` could false-negative when CLI exits nonzero | **fixed** — capture `status="$(... 2>&1 || true)"`, grep the var |
| Medium | `cfg()` nested-key shadowing | **fixed** — top-level anchor |
| Low | `$REVIEW_CLI` unquoted on `--version` | **fixed** — quoted |
| Nit | `REVIEW_MODEL` parsed but unused | **fixed** — now shown in output |

## Round 2 — re-review (both files)
- session: `019eeba8-64e8-77d1-bf2a-48a236129235`
- usage: 28427 tokens (~/.codex/sessions/2026/06/22/rollout-2026-06-22T04-29-02-019eeba8-64e8-77d1-bf2a-48a236129235.jsonl)
- exit: 0
- verdict: **all 5 prior issues RESOLVED, no new High/Medium.**
