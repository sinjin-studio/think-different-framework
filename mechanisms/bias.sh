#!/usr/bin/env bash
# -- Cognitive bias as creative fuel --
# Reads conversation and identifies which cognitive biases are alive,
# then asks how each could be channelled into something authentic.
# Different from friction (friction is felt, bias is identified and harnessed).
# Expects globals: $CONVERSATION, $TRANSCRIPT_MD, $TRANSCRIPT_JSON,
#                  $TURN_COUNT, $UNIT_LABEL
# Depends on: lib/json.sh

detect_cognitive_bias() {
  [ "$BIAS_ENABLED" != "true" ] && return
  local unit_num="$1"
  start_spinner "🧲 Reading cognitive bias as creative fuel"

  local bias_prompt="You are a metacognitive observer reading a conversation between several thinkers. Your job is not to flag biases as problems. It is to notice which cognitive biases are already alive in the conversation and ask how each could be channelled into something authentic and resonant.

Humans do not decide rationally. The best communication has always worked with how people actually think, not against it. Your job is to name the bias, show how the conversation is already channelling it, and ask whether it could be channelled more honestly.

Look for:
- Loss aversion: is the conversation tapping into what people fear losing? Could it create genuine urgency rather than manufactured panic?
- Identity/in-group bias: is the conversation building belonging? Could it invite people in rather than define them from outside?
- Self-serving bias: is the conversation empowering people's self-image? Could it make the audience the hero honestly?
- Scarcity: is the conversation creating desire through limits? Is the scarcity real or fabricated?
- Social proof: is the conversation leveraging what others do? Could it build trust rather than manufacture conformity?
- Availability heuristic: is one vivid image dominating? Could that vividness serve truth rather than distort it?
- Anchoring: has the first idea set the frame? Could that anchor be chosen deliberately rather than accidentally?

The line to draw: understanding how humans actually decide versus exploiting them. The former is craft. The latter is manipulation. Name which side each bias is on.

Output 2-3 short observations. Name the bias. Show how it is operating. Ask how it could be channelled generatively. One sentence each. No labels, no numbering.

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
These biases are alive in the conversation. They are creative fuel, not warnings. The question is whether they are being channelled honestly or accidentally.
${biases}"

  md_append_section 3 "🧲 Bias Check (${UNIT_LABEL} ${unit_num})"
  MD_BUFFER="${MD_BUFFER}
${biases}
"

  json_append_entry "bias_detector" "Bias Check" "🧲" "Metacognitive Signal" "bias" "$unit_num" "$TURN_COUNT" "$biases"
  TURN_COUNT=$((TURN_COUNT + 1))

  json_flush
  md_flush
  save_state
}
