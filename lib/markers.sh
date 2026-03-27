#!/usr/bin/env bash
# ── Console + transcript markers ──
# Unified markers for rounds, spirals, and phases.
# Uses MD_BUFFER (from lib/md.sh) instead of direct file writes.

mark_round() {
  local num="$1"
  local label="$2"

  echo ""
  echo "  ━━━ ROUND ${num}: ${label} ━━━━━━━━━━━━━━━━━━━━━━━"
  md_append_section 2 "Round ${num}: ${label}"
}

mark_spiral() {
  local num="$1"

  echo ""
  echo "  ━━━ SPIRAL ${num} ━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  md_append_section 2 "Spiral ${num}"
}

mark_pass() {
  local num="$1"
  local label="$2"

  echo ""
  echo "  ━━━ PASS ${num}: ${label} ━━━━━━━━━━━━━━━━━━━━━━━"
  md_append_section 2 "Pass ${num}: ${label}"
}

mode_emoji() {
  case "${1:-dyslexic}" in
    spiral)   echo "🌀🌿" ;;
    lapidary) echo "🪨✨" ;;
    *)        echo "💫🔀" ;;
  esac
}

mark_phase() {
  local label="$1"
  local subtitle="$2"

  echo ""
  echo "  ── ${label}: ${subtitle} ──"
  md_append_section 3 "${label} - ${subtitle}"
}
