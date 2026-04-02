#!/usr/bin/env bash
# ── Polish mechanism (lapidary composition) ──
# Between-pass assessment: what survived? What was revealed?
# Like friction (snags) and reseed (surprising insight), but oriented
# toward quality - asking what is worth keeping and what the cutting revealed.
# Expects globals: $THINKING_SESSION, $TRANSCRIPT_MD, $TRANSCRIPT_JSON,
#                  $TURN_COUNT, $UNIT_LABEL
# Depends on: lib/json.sh

polish() {
  local pass_num="$1"
  start_spinner "💎 Polishing between passes"

  local polish_prompt="You are reading a thinking session across multiple cognitive lenses, working material through iterative refinement. A pass of cutting and shaping has just been completed.

Read the thinking and assess what this pass revealed. Not what was said - what survived and what was exposed by the cutting.

Output three short observations:
1. What survived this pass that deserves to be worked harder? The idea or angle that proved load-bearing under pressure.
2. What was revealed by the cutting? Something that was hidden before this pass but is now visible because surrounding material was removed.
3. What is the quality trajectory? Is the material getting denser and more precise, or is it losing its life? Is the next pass needed or would it over-polish?

One sentence each. No labels, no numbering. Write as a craftsperson assessing their own work between passes.

THINKING SESSION:
$(get_conversation_for "mechanism")"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$polish_prompt" > "$tmpfile"

  # Resume skip
  if [ "$TURN_COUNT" -lt "$RESUME_FROM_TURN" ]; then
    rm -f "$tmpfile"
    stop_spinner "skipped (resuming)"
    TURN_COUNT=$((TURN_COUNT + 1))
    return
  fi

  local assessment
  VERBOSE_CALLER="mechanism:polish"
  if claude_call "$tmpfile"; then
    assessment="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$RATE_LIMIT_HIT" = "true" ]; then
      stop_spinner "rate limit"
      return 1
    fi
    assessment="The material is taking shape. Continue working."
  fi
  rm -f "$tmpfile"

  stop_spinner "done"

  THINKING_SESSION="${THINKING_SESSION}

=== POLISH (${UNIT_LABEL} ${pass_num}) ===
Assessment between passes. What survived, what was revealed, what is the quality trajectory. Work with these signals - they tell you where the density is.
${assessment}"

  md_append_section 3 "💎 Polish (${UNIT_LABEL} ${pass_num})"
  MD_BUFFER="${MD_BUFFER}
${assessment}
"

  json_append_entry "polish" "Polish" "💎" "Quality Assessment" "polish" "$pass_num" "$TURN_COUNT" "$assessment"
  TURN_COUNT=$((TURN_COUNT + 1))

  json_flush
  md_flush
  save_state
}
