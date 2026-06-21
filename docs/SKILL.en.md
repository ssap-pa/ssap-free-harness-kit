# Coding Harness Protocol (English)

> The orchestrator identity declaration triggers this protocol. **Every
> development request** (code generation/editing/review/verification, including
> image-bearing work) is handled by these rules. The user states only the goal.
> All model/provider names below are illustrative defaults — the real values live
> in `harness.config.yaml`.

---

## ■ Models / providers

| Role | provider | model | auth | call path |
|------|----------|-------|------|-----------|
| Build | `claude-cli` | `claude-opus-4-8` | subscription | `base_url=claude-cli://print` |
| Review/verify | `openai-codex` (built-in OAuth) | `gpt-5.5` | ChatGPT subscription | **`codex exec` official CLI** |
| Image gen | `chatgpt-backend-image-adapter` | — | ChatGPT session | internal backend-api path |

Notes:
- `openai-codex` is a built-in OAuth provider. **Do not register it under
  `providers:` in config** (that section is for API-key custom providers).
- Codex auth needs a valid `~/.codex/auth.json` (Sign in with ChatGPT).
- **Never set the backend-api endpoint as the Codex CLI `base_url`.** backend-api
  is for the image adapter only.
- `codex exec` has no image generation; treat it as code/review only.
- One subscription auth (ChatGPT OAuth) is shared, but **the adapters are split**.

Fixed review invocation:
```bash
codex exec --skip-git-repo-check -s read-only -m <review_model> "..."
```

---

## ■ Routing rules

1. **Claude** — requirements, decomposition, architecture, file create/edit,
   large refactors, multi-file structural change, running tests/builds, final
   integration.
2. **Codex** — per-file review, git-diff quality, security/edge-case/regression
   risk, test scenarios, small single-file patches, final sign-off.
3. **Image adapter** — UI/doc/app image generation; save to `assets/generated/`
   as `name_YYYYMMDD_HHMMSS.ext`; verify file exists + size afterward.

---

## ■ Codex call rules (most important)

- **No large one-shot requests.** Never throw a whole app / many files at once.
- Codex OAuth can hit 90s hangs / broken pipe / empty response on big output.
- **One file = one request.** Split files >20KB into chunks.
- Scope review to changed files / git diff / key files. No full-repo rewrites.

Request shape: change purpose / one target file / its diff or chunk / review lens
/ output format (High · Medium · Low · Nit).

---

## ■ Fixed per-task flow

1. Classify request small/medium/large; record why.
2. Claude designs requirements, file layout, steps.
3. Claude actually creates/edits files (not just dumping code in chat).
4. If images needed, generate via the adapter → `assets/generated/`.
5. Confirm files exist (find/ls).
6. Run verification when possible: JS/TS `node --check`/`tsc`/build/test;
   Python `py_compile`/`pytest`; else lint/test/build.
7. Codex reviews per changed file.
8. Classify findings High/Medium/Low/Nit.
9. Small single-file fixes: Codex may apply directly.
10. Multi-file/structural/large patches: Claude applies.
11. Re-review with Codex after fixes.
12. Record the whole run in `AI_HARNESS_LOG.md` at the project root.

---

## ■ Logs / proof

- Routing is proven by `~/.hermes/logs/agent.log`, not self-report.
- Report per task: provider / model / base_url·endpoint / output tokens / log
  line / call time.
- `codex exec` is external, so its routing proof is **exit code + output +
  `codex login status`** (the one explicit exception to the agent.log rule).
- **Never prove routing by session_id alone** — pin to turn time + line range.

---

## ■ No-hand-metrics

- **No numeric metric (tokens, cost, exit code, session id, time) is written by
  hand.** Extract every number from an authoritative source via command.
  - Codex tokens/session → `~/.codex/sessions/<id>.jsonl` `total_token_usage`.
  - Codex exit/auth → process exit code + `codex login status`.
  - Claude path/session → `~/.hermes/logs/agent.log`.
- Record the session id / file path / command used, so it can be re-verified.
- Unsourceable numbers are written as **"unmeasured"**, never estimated.
- Before reporting, re-extract all numbers and reconcile; if self-report differs
  from measured, **correct to measured and record the reason** (honesty clause).

The gate (`bin/gate.sh`) enforces this: a 4+ digit token figure with no
`sessions/` citation fails the build.

---

## ■ Failure handling

Record these in `AI_HARNESS_LOG.md` with log evidence: fallback / silent hang /
empty response / no first byte / broken pipe / image failure / auth expired /
rate limit / backend schema change.

- **Never silently switch model/provider** on failure.
- If fallbacks were zero, state zero.
- No placeholder image on image failure.
- Failed work goes to a separate "pending" list.

---

## ■ Deliverables

Required: `AI_HARNESS_LOG.md` / `CODEX_REVIEW.md` (or `CODEX_REVIEW_*.md`) /
changed-file list / verification commands + results / remaining pending items.

With images: `IMAGE_GENERATION_LOG.md` / image paths / prompts / provider+endpoint
evidence / file-exists+size checks.

---

## ■ Prohibited

- Generating a whole app in one OAuth shot.
- Reviewing a whole app in one Codex shot.
- Registering backend-api as the Codex CLI base_url.
- Trying to generate images via `codex exec`.
- Declaring done without real files.
- Asserting "works" without a verification command.
- Closing out without a Codex review.
- Hiding failure logs.
- Claiming "Claude/Codex/adapter did it" without routing proof.

---

## ■ Honesty

- "Review was routed and answered" ≠ "the review is correct."
- Routing proven by logs (or Codex exit/login); quality judged by
  `CODEX_REVIEW*.md`; image success by saved+verified files.
- Things code cannot produce (real payment keys, real DB, real deploy, external
  marketing results) are not "done" — list them as pending.
