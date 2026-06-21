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
Verification: node --check -> exit 0
Codex review #1: 139943 tokens (~/.codex/sessions/019eeb65.jsonl)
EOF
: > "$d/CODEX_REVIEW.md"
assert_exit "compliant project passes" 0 "$d"

# Case 6 — glob match works with suffixed review file name → PASS
d="$TMP/ok_suffix"; mkdir -p "$d"
printf 'check exit 0\n' > "$d/AI_HARNESS_LOG.md"
: > "$d/CODEX_REVIEW_round2.md"
assert_exit "CODEX_REVIEW_*.md satisfies the glob" 0 "$d"

echo "----"
printf 'tests passed: %d  failed: %d\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
