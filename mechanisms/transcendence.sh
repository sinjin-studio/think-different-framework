#!/usr/bin/env bash
# ── Transcendence check ──
# Reads conversation and flags when the entire session has stayed
# within a transactional/utilitarian frame without anyone noticing.
# Returns structured decision in $TRANSCENDENCE_DECISION (JSON).
# Expects globals: $CONVERSATION, $TRANSCRIPT_MD, $TRANSCRIPT_JSON,
#                  $TURN_COUNT, $UNIT_LABEL
# Depends on: lib/json.sh, lib/cap_check.sh

TRANSCENDENCE_DECISION=""

transcendence_check() {
  [ "$TRANSCENDENCE_ENABLED" != "true" ] && return
  local unit_num="$1"
  TRANSCENDENCE_DECISION=""
  start_spinner "🕯️ Transcendence check"

  local mechanism_history
  mechanism_history=$(build_mechanism_history)

  local transcendence_prompt="You are reading a conversation between several thinkers working on a problem. Do not analyse it. Feel it.

Read the entire conversation and notice one thing: has anyone named what this is actually in service of? Not the business objective. Not the user need. The thing underneath - the devotion, the love, the care, the sacred ordinary thing that makes this worth someone's life hours.

Respond with a JSON object containing:
- observations: an array of 3 short observation strings:
  1. What the conversation treats as the ultimate justification for its ideas (the frame it has not questioned).
  2. What it might look like if the conversation took seriously the possibility that the people involved are driven by love, devotion, or care rather than by incentive, convenience, or fear.
  3. What urgency the conversation is avoiding. If the people at the centre had one year to act, not a career, which ideas survive?
- has_breakthrough: boolean - has the conversation touched something genuinely transcendent, beyond the transactional?
- recommendation: one of 'compress' (a breakthrough was found, compress and move to grounding), 'continue' (keep exploring), or 'ground_early' (the conversation is circling, ground what exists)

${mechanism_history}
CONVERSATION:
$(get_conversation_for "mechanism")"

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

  local json_schema='{"type":"object","properties":{"observations":{"type":"array","items":{"type":"string"}},"has_breakthrough":{"type":"boolean"},"recommendation":{"type":"string","enum":["compress","continue","ground_early"]}},"required":["observations","has_breakthrough","recommendation"]}'

  local observations decision_json
  VERBOSE_CALLER="mechanism:transcendence"
  if claude_call_json "$tmpfile" "$json_schema"; then
    decision_json="$CLAUDE_RESPONSE"
    TRANSCENDENCE_DECISION="$decision_json"
    observations=$(echo "$decision_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for obs in d.get('observations', []):
    print(obs)
" 2>/dev/null || echo "No transcendence signal detected.")
    # Append to mechanism memory
    local trans_rec_mem trans_summary
    trans_rec_mem=$(echo "$decision_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('recommendation','continue'))" 2>/dev/null || echo "continue")
    trans_summary=$(echo "$decision_json" | python3 -c "import sys,json; obs=json.load(sys.stdin).get('observations',[]); print(obs[0] if obs else '')" 2>/dev/null || echo "")
    append_mechanism_memory "transcendence" "$unit_num" "$trans_rec_mem" "$trans_summary"
  else
    rm -f "$tmpfile"
    if [ "$RATE_LIMIT_HIT" = "true" ]; then
      stop_spinner "rate limit"
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
