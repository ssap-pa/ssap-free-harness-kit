#!/usr/bin/env bash
# test_gate.sh — tests the gate itself.
#
# WEAKNESS #5 FIX (the harness had zero self-tests): "a harness that tests the
# harness." We deliberately build broken and complete fake projects and assert
# gate.sh returns the right exit code. If the gate ever stops blocking, this
# goes red. Pure bash — zero LLM tokens.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/../bin/gate.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

passed=0; failed=0
assert_exit() {           # desc, expected_exit, dir
  local desc="$1" expected="$2" dir="$3" got
  bash "$GATE" "$dir" >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$expected" ]; then
    printf '✅ %s (exit %d)\n' "$desc" "$got"; passed=$((passed+1))
  else
    printf '❌ %s (expected %d, got %d)\n' "$desc" "$expected" "$got"; failed=$((failed+1))
  fi
}

# Case 1 — empty project → BLOCK (1)
d="$TMP/empty"; mkdir -p "$d"
assert_exit "empty project is blocked" 1 "$d"

# Case 2 — has log but no CODEX_REVIEW → BLOCK
d="$TMP/no_review"; mkdir -p "$d"
printf 'log\nexit 0\n' > "$d/AI_HARNESS_LOG.md"
assert_exit "missing CODEX_REVIEW is blocked" 1 "$d"

# Case 3 — has both artifacts but no verification evidence → BLOCK
d="$TMP/no_verify"; mkdir -p "$d"
printf 'log without evidence\n' > "$d/AI_HARNESS_LOG.md"
: > "$d/CODEX_REVIEW.md"
assert_exit "missing verification evidence is blocked" 1 "$d"

# Case 4 — hand-written token metric with no source → BLOCK (no-hand-metrics)
d="$TMP/hand_metric"; mkdir -p "$d"
printf 'Codex review used 58026 tokens total\nexit 0\n' > "$d/AI_HARNESS_LOG.md"
: > "$d/CODEX_REVIEW.md"
assert_exit "uncited token metric is blocked" 1 "$d"

# Case 5 — fully compliant (cited metric + exit 0 + both artifacts) → PASS (0)
d="$TMP/ok"; mkdir -p "$d"
cat > "$d/AI_HARNESS_LOG.md" <<'EOF'
# Harness log
gate-verify: node --check -> exit 0
Codex review #1: 139943 tokens (~/.codex/sessions/019eeb65.jsonl)
EOF
: > "$d/CODEX_REVIEW.md"
assert_exit "compliant project passes" 0 "$d"

# Case 6 — glob match works with suffixed review file name → PASS
d="$TMP/ok_suffix"; mkdir -p "$d"
printf 'gate-verify: tsc --noEmit -> exit 0\n' > "$d/AI_HARNESS_LOG.md"
: > "$d/CODEX_REVIEW_round2.md"
assert_exit "CODEX_REVIEW_*.md satisfies the glob" 0 "$d"

# Case 7 — WEAKNESS FIX: loose 'exit 0' prose no longer counts as evidence → BLOCK
# (the whole point: a string in the log must not pass for a command that never ran)
d="$TMP/loose"; mkdir -p "$d"
printf 'some prose that casually mentions exit 0 but ran nothing\n' > "$d/AI_HARNESS_LOG.md"
: > "$d/CODEX_REVIEW.md"
assert_exit "loose 'exit 0' prose no longer passes" 1 "$d"

# Case 8 — STRONG MODE: gate RUNS gate_verify_cmd; real exit 0 → PASS
d="$TMP/verify_ok"; mkdir -p "$d"
printf 'log\n' > "$d/AI_HARNESS_LOG.md"; : > "$d/CODEX_REVIEW.md"
cat > "$TMP/cfg_ok.yaml" <<'EOF'
gate_required_artifacts: AI_HARNESS_LOG.md
gate_required_globs: CODEX_REVIEW*.md
gate_require_verification_evidence: true
gate_verify_cmd: true
gate_enforce_no_hand_metrics: true
EOF
HARNESS_CONFIG="$TMP/cfg_ok.yaml" bash "$GATE" "$d" >/dev/null 2>&1; got=$?
if [ "$got" -eq 0 ]; then printf '✅ gate runs verify cmd, real exit 0 → pass (exit %d)\n' "$got"; passed=$((passed+1)); else printf '❌ gate-runs-verify-ok (expected 0, got %d)\n' "$got"; failed=$((failed+1)); fi

# Case 9 — STRONG MODE: gate RUNS gate_verify_cmd; real exit 1 → BLOCK
d="$TMP/verify_fail"; mkdir -p "$d"
printf 'log\n' > "$d/AI_HARNESS_LOG.md"; : > "$d/CODEX_REVIEW.md"
cat > "$TMP/cfg_fail.yaml" <<'EOF'
gate_required_artifacts: AI_HARNESS_LOG.md
gate_required_globs: CODEX_REVIEW*.md
gate_require_verification_evidence: true
gate_verify_cmd: false
gate_enforce_no_hand_metrics: true
EOF
HARNESS_CONFIG="$TMP/cfg_fail.yaml" bash "$GATE" "$d" >/dev/null 2>&1; got=$?
if [ "$got" -eq 1 ]; then printf '✅ gate runs verify cmd, real exit 1 → block (exit %d)\n' "$got"; passed=$((passed+1)); else printf '❌ gate-runs-verify-fail (expected 1, got %d)\n' "$got"; failed=$((failed+1)); fi

echo "----"
printf 'tests passed: %d  failed: %d\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
