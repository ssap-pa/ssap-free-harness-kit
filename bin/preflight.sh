#!/usr/bin/env bash
# preflight.sh — verify the harness can actually route before any work starts.
#
# WEAKNESS #3 FIX (tight coupling / "loads but no engine to route to"): the most
# common failure is the protocol loading while the review/impl engine is missing
# or logged out. This checks the SUBSCRIPTION AUTH itself (the moat) and the
# config-declared engines, instead of assuming they exist.
#
# Usage:  bin/preflight.sh
# Exit:   0 = ready · 1 = at least one blocker
set -uo pipefail            # not -e: we want to run every check and report all

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="${HARNESS_CONFIG:-$ROOT_DIR/harness.config.yaml}"

cfg() {
  local key="$1" def="${2:-}" line val
  line="$(grep -E "^${key//./\\.}[[:space:]]*:" "$CONFIG" 2>/dev/null | head -n1)" || true
  if [ -z "$line" ]; then printf '%s' "$def"; return; fi
  val="${line#*:}"; val="${val%%#*}"
  val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
  val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
  printf '%s' "$val"
}

fail=0
ok()   { printf '  ✅ %s\n' "$1"; }
bad()  { printf '  🚫 %s\n' "$1"; fail=1; }
warn() { printf '  ⚠️  %s\n' "$1"; }

echo "== harness preflight =="

# config present
if [ -f "$CONFIG" ]; then ok "config: $CONFIG"; else bad "config not found: $CONFIG"; fi

# base toolchain
command -v git  >/dev/null && ok "git: $(git --version)"      || bad "git not found"
command -v node >/dev/null && ok "node: $(node -v)"           || warn "node not found (only needed for JS/TS projects)"

# ── review engine (Codex) + SUBSCRIPTION auth — the flat-rate moat ──
REVIEW_CLI="$(cfg review_cli codex)"
REVIEW_MODEL="$(cfg review_model gpt-5.5)"
if command -v "$REVIEW_CLI" >/dev/null; then
  ok "review CLI ($REVIEW_MODEL): $("$REVIEW_CLI" --version 2>/dev/null | head -n1)"
  # codex prints status to STDERR, so capture 2>&1 into a var (avoids pipefail false-neg).
  # Reject NEGATIVE text first — "Not logged in" contains "logged in", so an order-naive
  # grep would false-pass. Only then accept a positive ChatGPT-subscription signal.
  status="$("$REVIEW_CLI" login status 2>&1 || true)"
  if printf '%s\n' "$status" | grep -qiE 'not logged in|logged out|not authenticated|unauthenticated'; then
    bad "$REVIEW_CLI not logged in — run: $REVIEW_CLI login  (Sign in with ChatGPT)"
  elif printf '%s\n' "$status" | grep -qiE 'logged in.*chatgpt|chatgpt'; then
    ok "review auth: ChatGPT subscription (flat-rate — NO metered/per-token billing)"
  else
    bad "$REVIEW_CLI auth state unclear: ${status:-<no output>}"
  fi
else
  bad "review CLI '$REVIEW_CLI' not found — npm i -g @openai/codex"
fi

# ── impl engine (Claude) ──
IMPL_PROVIDER="$(cfg impl_provider claude-cli)"
IMPL_MODEL="$(cfg impl_model claude-opus-4-8)"
if command -v claude >/dev/null; then
  ok "impl CLI: claude present (provider=$IMPL_PROVIDER, model=$IMPL_MODEL)"
else
  warn "claude CLI not on PATH — ensure Hermes main provider = $IMPL_PROVIDER / $IMPL_MODEL"
fi

echo "----"
if [ "$fail" -eq 0 ]; then
  echo "✅ PREFLIGHT OK — engines reachable on subscription auth"
else
  echo "🚫 PREFLIGHT FAILED — fix blockers above before running the harness"
fi
exit "$fail"
