#!/usr/bin/env bash
# ── Cognitive bias detection ──
# Reads conversation and flags active cognitive biases.
# Different from friction (friction is felt, bias is identified).
# Outputs as signal, not correction.
# Expects globals: $CONVERSATION, $TRANSCRIPT_MD, $TRANSCRIPT_JSON,
#                  $TURN_COUNT, $UNIT_LABEL
# Depends on: lib/json.sh

detect_cognitive_bias() {
  [ "$BIAS_ENABLED" != "true" ] && return
  local unit_num="$1"
  start_spinner "🔬 Checking for cognitive bias"

  local bias_prompt="You are a metacognitive observer reading a conversation between several thinkers. Your job is not to evaluate the ideas. It is to notice the THINKING PATTERNS and flag any cognitive biases that are shaping the conversation.

Look for:
- Anchoring: is the conversation stuck on the first idea or framing?
- Confirmation bias: are agents finding evidence for what they already believe?
- Availability heuristic: is one example or analogy dominating because it was vivid, not because it was best?
- Groupthink: are agents converging too quickly? Is disagreement being smoothed over?
- Framing effect: is the way the question was framed determining the answers?
- Sunk cost: is the conversation continuing a direction because of investment rather than merit?
- Dunning-Kruger: is confidence outpacing the depth of the thinking?

Output 2-3 short observations. Name the bias. Describe how it is operating in this specific conversation. One sentence each. No labels, no numbering. Write as signals, not corrections.

CONVERSATION:
${CONVERSATION}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$bias_prompt" > "$tmpfile"

  # Resume skip
  if [ "$TURN_COUNT" -lt "$RESUME_FROM_TURN" ]; then
    rm -f "$tmpfile"
    stop_spinner "skipped (resuming)"
    TURN_COUNT=$((TURN_COUNT + 1))
    return
  fi

  local biases
  if claude_call "$tmpfile"; then
    biases="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      stop_spinner "cap limit"
      return 1
    fi
    biases="No significant cognitive biases detected."
  fi
  rm -f "$tmpfile"

  stop_spinner "done"

  CONVERSATION="${CONVERSATION}

=== COGNITIVE BIAS CHECK (${UNIT_LABEL} ${unit_num}) ===
These biases have been detected in the thinking so far. They are signals, not corrections. Be aware of them but do not overcorrect.
${biases}"

  md_append_section 3 "🔬 Bias Check (${UNIT_LABEL} ${unit_num})"
  MD_BUFFER="${MD_BUFFER}
${biases}
"

  json_append_entry "bias_detector" "Bias Check" "🔬" "Metacognitive Signal" "bias" "$unit_num" "$TURN_COUNT" "$biases"
  TURN_COUNT=$((TURN_COUNT + 1))

  json_flush
  md_flush
  save_state
}
