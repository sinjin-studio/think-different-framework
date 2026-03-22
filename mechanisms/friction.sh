#!/usr/bin/env bash
# ── Friction detection (Clark-inspired) ──
# Finds prediction errors between rounds - the signal is in the
# contradiction, not the agreement.
# Expects globals: $CONVERSATION, $TRANSCRIPT_MD, $TRANSCRIPT_JSON,
#                  $TURN_COUNT, $UNIT_LABEL
# Depends on: lib/json.sh

detect_prediction_errors() {
  [ "$FRICTION_ENABLED" != "true" ] && return
  local unit_num="$1"
  echo -n "  ⚡ Detecting prediction errors..."

  local error_prompt="You are reading a conversation between several thinkers working on a problem. Do not analyse it. React to it.

Read the conversation and notice where it SNAGS. Where something doesn't fit. Where two people said things that can't both be true but somehow both feel right. Where someone said something that changed the direction and nobody acknowledged it. Where everyone is standing on the same assumption like it's solid ground but it might be ice.

Output three short observations. Not analysis. Observations. Things you noticed that felt like friction, like a catch in the throat, like a word that means two things at once. One sentence each. No labels, no numbering.

CONVERSATION:
${CONVERSATION}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$error_prompt" > "$tmpfile"

  local errors
  errors=$(cat "$tmpfile" | claude -p 2>/dev/null) || {
    errors="No prediction errors detected."
  }
  rm -f "$tmpfile"

  echo " done"

  CONVERSATION="${CONVERSATION}

=== FRICTION (${UNIT_LABEL} ${unit_num}) ===
These are the snags, the catches, the places where the conversation doesn't quite fit together. Follow the friction. Do not smooth it out.
${errors}"

  printf "\n### ⚡ Friction (%s %s)\n\n%s\n" "$UNIT_LABEL" "$unit_num" "$errors" >> "$TRANSCRIPT_MD"

  json_append_entry "error_detector" "Prediction Error" "⚡" "Mismatch Signal" "error" "$unit_num" "$TURN_COUNT" "$errors"
  TURN_COUNT=$((TURN_COUNT + 1))
}
