# AI_HARNESS_LOG — harness-kit

Built with the coding-harness protocol: **Claude builds → Codex reviews → fix →
Codex re-reviews → gate**. Both engines on flat-rate subscription auth (no metered
billing). All metrics extracted from authoritative sources (no-hand-metrics).

## Classification
- Size: **MEDIUM** (8 files; bash + yaml + markdown; ships its own self-tests).
- Codex scope: one file = one request; no whole-repo one-shot.

## Routing / engines
| Role | provider / model | auth | proof |
|------|------------------|------|-------|
| Build | claude-cli / claude-opus-4-8 | subscription | this session |
| Review | openai-codex / gpt-5.5 (`codex exec`) | ChatGPT subscription | `~/.codex/sessions/*.jsonl` + exit 0 |

## Files produced
- harness.config.yaml, bin/gate.sh, bin/preflight.sh, tests/test_gate.sh,
  README.md, docs/SKILL.en.md, LICENSE, .gitignore

## Verification commands & results
- `bash -n bin/gate.sh bin/preflight.sh tests/test_gate.sh` → exit 0 (syntax clean)
- `bash tests/test_gate.sh` → 6 passed / 0 failed → exit 0
- `bash bin/preflight.sh` → exit 0 (engines reachable on subscription auth)
- `bash bin/gate.sh .` (pre-artifacts) → exit 1 (correctly blocked)

## Bug found & fixed during verification (root cause, not symptom)
- **preflight false-negative**: `codex login status` prints "Logged in using ChatGPT"
  to **stderr**; preflight discarded stderr (`2>/dev/null`) so the grep saw nothing.
  Root cause confirmed by isolating stdout vs stderr. Fixed to `2>&1`, then hardened
  per Codex review (negative-match-first).

## Codex review (see CODEX_REVIEW.md)
- Round 1 gate.sh: session 019eeba5 — 36204 tokens (~/.codex/sessions/2026/06/22/rollout-2026-06-22T04-25-43-019eeba5-5d5f-7692-a5de-20453c7aed9a.jsonl), exit 0
- Round 1 preflight.sh: session 019eeba6 — 27064 tokens (~/.codex/sessions/2026/06/22/rollout-2026-06-22T04-26-51-019eeba6-64ad-7822-9221-8ae6bfd62f77.jsonl), exit 0
- Round 2 re-review: session 019eeba8 — 28427 tokens (~/.codex/sessions/2026/06/22/rollout-2026-06-22T04-29-02-019eeba8-64e8-77d1-bf2a-48a236129235.jsonl), exit 0
- Outcome: 1 High + 4 Medium + 4 Low + 3 Nit raised; all High/Medium fixed; 5/5 prior issues RESOLVED on re-review; no new High/Medium.

## Five weaknesses → fixes (all zero-token)
1. enforcement = request → `bin/gate.sh` returns exit 1 (proven by tests)
2. model-name rot → `harness.config.yaml` single source of truth
3. tight coupling / no engine → `bin/preflight.sh` checks subscription auth
4. Korean-only → English README + docs/SKILL.en.md
5. no self-tests → tests/test_gate.sh (6 cases)

## Pending (cannot be produced by code alone — honesty clause)
- Wiring `gate.sh` into a real stop-hook / CI in the consumer's environment.
- `shellcheck` not installed here; static review done by Codex instead (noted, not hidden).
- Publishing to a public GitHub remote (awaiting user go-ahead).

## Fallbacks
- 0 silent model/provider switches. 0 fabricated outputs. All failures above logged.
- Verification step exit codes: see "Verification commands & results" (exit 0 throughout).
