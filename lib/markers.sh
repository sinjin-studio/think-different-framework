#!/usr/bin/env bash
# ── Console + transcript markers ──
# Unified markers for rounds, spirals, and phases.
# Expects globals: $TRANSCRIPT_MD

mark_round() {
  local num="$1"
  local label="$2"

  echo ""
  echo "  ━━━ ROUND ${num}: ${label} ━━━━━━━━━━━━━━━━━━━━━━━"
  printf "\n---\n\n## Round %s: %s\n" "$num" "$label" >> "$TRANSCRIPT_MD"
}

mark_spiral() {
  local num="$1"

  echo ""
  echo "  ━━━ SPIRAL ${num} ━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "\n---\n\n## Spiral %s\n" "$num" >> "$TRANSCRIPT_MD"
}

mark_pass() {
  local num="$1"
  local label="$2"

  echo ""
  echo "  ━━━ PASS ${num}: ${label} ━━━━━━━━━━━━━━━━━━━━━━━"
  printf "\n---\n\n## Pass %s: %s\n" "$num" "$label" >> "$TRANSCRIPT_MD"
}

mark_phase() {
  local label="$1"
  local subtitle="$2"

  echo ""
  echo "  ── ${label}: ${subtitle} ──"
  printf "\n### %s - %s\n" "$label" "$subtitle" >> "$TRANSCRIPT_MD"
}
