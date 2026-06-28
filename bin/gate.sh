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

# (3) Verification must actually have RUN — not merely a string that claims it did.
#     WEAKNESS FIX: the old check passed on ANY 'exit 0' substring, so prose like
#     "remember to check exit 0" satisfied it without a command ever running.
#     Two stronger modes (selected in harness.config.yaml):
#       a) gate_verify_cmd set   → the GATE itself runs that command and gates on its
#          REAL exit code. Evidence = the gate's own observation of a live process,
#          which a string written into the log cannot fake.
#       b) gate_verify_cmd empty → require a STRUCTURED, line-anchored evidence line
#          ('gate-verify: <cmd> -> exit 0') that ordinary prose cannot trip.
if [ "$(cfg gate_require_verification_evidence true)" = "true" ]; then
  log="$PROJECT/AI_HARNESS_LOG.md"
  verify_cmd="$(cfg gate_verify_cmd '')"
  if [ -n "$verify_cmd" ]; then
    echo "  running verification: $verify_cmd"
    vout="$(mktemp)"
    if ( cd "$PROJECT" && eval "$verify_cmd" ) >"$vout" 2>&1; then
      [ -f "$log" ] && printf 'gate-verify: %s -> exit 0   (executed by gate.sh @ %s)\n' \
        "$verify_cmd" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log"
      pass "verification command ran and exited 0: $verify_cmd"
    else
      rc=$?
      block "verification command FAILED (exit $rc): $verify_cmd"
      sed 's/^/        /' "$vout" | tail -n 15
    fi
    rm -f "$vout"
  else
    # No command configured: demand a structured, anchored evidence line — NOT a
    # loose 'exit 0' substring. Prose can't satisfy 'gate-verify: <cmd> -> exit 0'.
    ev_re='^[[:space:]]*gate-verify:[[:space:]]*[^[:space:]].*->[[:space:]]*exit([[:space:]]+code)?[[:space:]]+0[[:space:]]*(\(.*\))?[[:space:]]*$'
    if [ -f "$log" ] && grep -qE "$ev_re" "$log"; then
      pass "structured verification evidence found (gate-verify line)"
    else
      block "no verification evidence — set 'gate_verify_cmd' in harness.config.yaml so the gate runs your check, or emit a 'gate-verify: <cmd> -> exit 0' line into AI_HARNESS_LOG.md"
    fi
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
