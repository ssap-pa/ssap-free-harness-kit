#!/usr/bin/env bash
# gate.sh — deterministic completion gate for the AI coding harness.
#
# WEAKNESS #1 FIX (enforcement was a polite request): this turns the protocol's
# "you MUST produce X" prose into a hard pass/fail check. An LLM can forget a
# prose rule; it cannot make exit 1 become exit 0. Runs in pure bash — ZERO LLM
# tokens — so it never touches the metered/subscription billing path.
#
# Usage:  bin/gate.sh [PROJECT_DIR]   (defaults to ".")
# Exit:   0 = all gates pass · 1 = at least one violation (block "done") · 2 = bad input
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="${HARNESS_CONFIG:-$ROOT_DIR/harness.config.yaml}"
PROJECT="${1:-.}"

# Minimal "key: value" reader — no yq/python needed, so the gate has no deps.
cfg() {
  local key="$1" def="${2:-}" line val
  # anchor to TOP-LEVEL keys only (escape dots) so a nested YAML key can't shadow config
  line="$(grep -E "^${key//./\\.}[[:space:]]*:" "$CONFIG" 2>/dev/null | head -n1)" || true
  if [ -z "$line" ]; then printf '%s' "$def"; return; fi
  val="${line#*:}"
  val="${val%%#*}"                              # strip inline comment
  val="${val#"${val%%[![:space:]]*}"}"          # ltrim
  val="${val%"${val##*[![:space:]]}"}"          # rtrim
  val="${val%\"}"; val="${val#\"}"              # strip "quotes"
  val="${val%\'}"; val="${val#\'}"              # strip 'quotes'
  printf '%s' "$val"
}

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

[ -d "$PROJECT" ] || { echo "gate: project dir not found: $PROJECT" >&2; exit 2; }
[ -f "$CONFIG" ]  || { echo "gate: config not found: $CONFIG" >&2; exit 2; }

fail=0
pass()  { printf '  ✅ %s\n' "$1"; }
block() { printf '  🚫 BLOCK: %s\n' "$1"; fail=1; }

echo "== harness gate :: $PROJECT =="

# (1) Required artifact files must exist.
IFS=',' read -ra ARTS <<< "$(cfg gate_required_artifacts AI_HARNESS_LOG.md)"
for a in "${ARTS[@]}"; do
  a="$(trim "$a")"; [ -z "$a" ] && continue
  if [ -e "$PROJECT/$a" ]; then pass "artifact present: $a"; else block "missing required artifact: $a"; fi
done

# (2) Required glob patterns must match at least one file (e.g. CODEX_REVIEW*.md).
IFS=',' read -ra GLOBS <<< "$(cfg gate_required_globs 'CODEX_REVIEW*.md')"
for g in "${GLOBS[@]}"; do
  g="$(trim "$g")"; [ -z "$g" ] && continue
  # glob INSIDE the project dir (so metachars in $PROJECT aren't treated as pattern)
  # and require at least one *regular file* match, not a directory.
  found=0
  while IFS= read -r m; do
    [ -f "$PROJECT/$m" ] && { found=1; break; }
  done < <(cd "$PROJECT" 2>/dev/null && compgen -G "$g" || true)
  if [ "$found" -eq 1 ]; then pass "review artifact matches: $g"; else block "no file matches required pattern: $g"; fi
done

# (3) Verification must actually have run — demand an "exit 0" line in the log.
if [ "$(cfg gate_require_verification_evidence true)" = "true" ]; then
  log="$PROJECT/AI_HARNESS_LOG.md"
  if [ -f "$log" ] && grep -qE 'exit( code)? 0' "$log"; then
    pass "verification evidence found (exit 0)"
  else
    block "no verification evidence — AI_HARNESS_LOG.md needs an 'exit 0' line"
  fi
fi

# (4) no-hand-metrics: any 4+ digit token figure must cite a sessions/ source.
#     WEAKNESS-adjacent: stops estimates from masquerading as measured proof.
if [ "$(cfg gate_enforce_no_hand_metrics true)" = "true" ]; then
  log="$PROJECT/AI_HARNESS_LOG.md"
  if [ -f "$log" ]; then
    # catch both orders ("58026 tokens" and "tokens: 58026") and comma-grouped digits;
    # a line is allowed only if it cites a sessions/ path.
    metric_re='([0-9][0-9,]{3,}[[:space:]_-]*(tok|tokens|토큰))|((tok|tokens|토큰)[[:space:]:_-]*[0-9][0-9,]{3,})'
    offenders="$(grep -nE "$metric_re" "$log" | grep -v 'sessions/' || true)"
    if [ -n "$offenders" ]; then
      block "hand-written token metric without a sessions/ source:"
      printf '%s\n' "$offenders" | sed 's/^/        /'
    else
      pass "no-hand-metrics: token figures cite a source (or none present)"
    fi
  fi
fi

echo "----"
if [ "$fail" -eq 0 ]; then
  echo "✅ GATE PASS — completion allowed"
else
  echo "🚫 GATE FAIL — completion blocked until violations above are fixed"
fi
exit "$fail"
