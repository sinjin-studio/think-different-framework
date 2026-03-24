#!/usr/bin/env bash
# ── Transcendence check ──
# Reads conversation and flags when the entire session has stayed
# within a transactional/utilitarian frame without anyone noticing.
# Different from bias (bias detects thinking patterns, transcendence
# detects motivational blindness).
# Outputs as signal, not correction.
# Expects globals: $CONVERSATION, $TRANSCRIPT_MD, $TRANSCRIPT_JSON,
#                  $TURN_COUNT, $UNIT_LABEL
# Depends on: lib/json.sh

transcendence_check() {
  [ "$TRANSCENDENCE_ENABLED" != "true" ] && return
  local unit_num="$1"
  start_spinner "🕯️ Transcendence check"

  local transcendence_prompt="You are reading a conversation between several thinkers working on a problem. Do not analyse it. Feel it.

Read the entire conversation and notice one thing: has anyone named what this is actually in service of? Not the business objective. Not the user need. The thing underneath - the devotion, the love, the care, the sacred ordinary thing that makes this worth someone's life hours.

Output three short observations:
1. What the conversation treats as the ultimate justification for its ideas (the frame it has not questioned).
2. What it might look like if the conversation took seriously the possibility that the people involved are driven by love, devotion, or care rather than by incentive, convenience, or fear.
3. What urgency the conversation is avoiding. If the people at the centre had one year to act, not a career, which ideas survive?

One sentence each. No labels, no numbering. Write as someone who sees the sacred in the ordinary and knows the ordinary is temporary.

CONVERSATION:
${CONVERSATION}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$transcendence_prompt" > "$tmpfile"

  # Resume skip
  if [ "$TURN_COUNT" -lt "$RESUME_FROM_TURN" ]; then
    rm -f "$tmpfile"
    stop_spinner "skipped (resuming)"
    TURN_COUNT=$((TURN_COUNT + 1))
    return
  fi

  local observations
  if claude_call "$tmpfile"; then
    observations="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      stop_spinner "cap limit"
      return 1
    fi
    observations="No transcendence signal detected."
  fi
  rm -f "$tmpfile"

  stop_spinner "done"

  CONVERSATION="${CONVERSATION}

=== TRANSCENDENCE CHECK (${UNIT_LABEL} ${unit_num}) ===
A check on what this conversation is in service of. Not to correct the thinking but to ask whether it has touched the thing that actually matters.
${observations}"

  md_append_section 3 "🕯️ Transcendence Check (${UNIT_LABEL} ${unit_num})"
  MD_BUFFER="${MD_BUFFER}
${observations}
"

  json_append_entry "transcendence" "Transcendence Check" "🕯️" "Metacognitive Signal" "transcendence" "$unit_num" "$TURN_COUNT" "$observations"
  TURN_COUNT=$((TURN_COUNT + 1))

  json_flush
  md_flush
  save_state
}
