#!/usr/bin/env bash
# ── Friction detection (Clark-inspired) ──
# Finds prediction errors between rounds - the signal is in the
# contradiction, not the agreement.
# Returns structured decision in $FRICTION_DECISION (JSON).
# Expects globals: $CONVERSATION, $TRANSCRIPT_MD, $TRANSCRIPT_JSON,
#                  $TURN_COUNT, $UNIT_LABEL
# Depends on: lib/json.sh, lib/cap_check.sh

FRICTION_DECISION=""

detect_prediction_errors() {
  [ "$FRICTION_ENABLED" != "true" ] && return
  local unit_num="$1"
  FRICTION_DECISION=""
  start_spinner "⚡ Detecting prediction errors"

  local mechanism_history
  mechanism_history=$(build_mechanism_history)

  local error_prompt="You are reading a conversation between several thinkers working on a problem. Do not analyse it. React to it.

Read the conversation and notice where it SNAGS. Where something doesn't fit. Where two people said things that can't both be true but somehow both feel right. Where someone said something that changed the direction and nobody acknowledged it. Where everyone is standing on the same assumption like it's solid ground but it might be ice.

Respond with a JSON object containing:
- observations: an array of 3 short observation strings (one sentence each, things that felt like friction)
- recommendation: one of 'deepen' (the friction needs more exploration), 'redirect' (the conversation is stuck, inject a new lens), or 'continue' (healthy friction, let it ride)
- inject_lens: if recommendation is 'redirect', which lens key should be injected next (e.g. 'skeptic', 'observer', 'empath'). Empty string if not applicable.
${mechanism_history}
CONVERSATION:
${CONVERSATION}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$error_prompt" > "$tmpfile"

  # Resume skip
  if [ "$TURN_COUNT" -lt "$RESUME_FROM_TURN" ]; then
    rm -f "$tmpfile"
    stop_spinner "skipped (resuming)"
    TURN_COUNT=$((TURN_COUNT + 1))
    return
  fi

  local json_schema='{"type":"object","properties":{"observations":{"type":"array","items":{"type":"string"}},"recommendation":{"type":"string","enum":["deepen","redirect","continue"]},"inject_lens":{"type":"string"}},"required":["observations","recommendation"]}'

  local errors decision_json
  VERBOSE_CALLER="mechanism:friction"
  if claude_call_json "$tmpfile" "$json_schema"; then
    decision_json="$CLAUDE_RESPONSE"
    FRICTION_DECISION="$decision_json"
    # Extract observations as prose for conversation
    errors=$(echo "$decision_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for obs in d.get('observations', []):
    print(obs)
" 2>/dev/null || echo "No prediction errors detected.")
    # Append to mechanism memory
    local friction_rec_mem friction_summary
    friction_rec_mem=$(echo "$decision_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('recommendation','continue'))" 2>/dev/null || echo "continue")
    friction_summary=$(echo "$decision_json" | python3 -c "import sys,json; obs=json.load(sys.stdin).get('observations',[]); print('; '.join(obs[:2]))" 2>/dev/null || echo "")
    append_mechanism_memory "friction" "$unit_num" "$friction_rec_mem" "$friction_summary"
  else
    rm -f "$tmpfile"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      stop_spinner "cap limit"
      return 1
    fi
    errors="No prediction errors detected."
  fi
  rm -f "$tmpfile"

  stop_spinner "done"

  CONVERSATION="${CONVERSATION}

=== FRICTION (${UNIT_LABEL} ${unit_num}) ===
These are the snags, the catches, the places where the conversation doesn't quite fit together. Follow the friction. Do not smooth it out.
${errors}"

  md_append_section 3 "⚡ Friction (${UNIT_LABEL} ${unit_num})"
  MD_BUFFER="${MD_BUFFER}
${errors}
"

  json_append_entry "error_detector" "Prediction Error" "⚡" "Mismatch Signal" "error" "$unit_num" "$TURN_COUNT" "$errors"
  TURN_COUNT=$((TURN_COUNT + 1))

  json_flush
  md_flush
  save_state
}
