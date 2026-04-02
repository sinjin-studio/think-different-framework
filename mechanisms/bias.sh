#!/usr/bin/env bash
# -- Cognitive bias as creative fuel --
# Reads conversation and identifies which cognitive biases are alive,
# then asks how each could be channelled into something authentic.
# Returns structured decision in $BIAS_DECISION (JSON).
# Expects globals: $THINKING_SESSION, $TRANSCRIPT_MD, $TRANSCRIPT_JSON,
#                  $TURN_COUNT, $UNIT_LABEL
# Depends on: lib/json.sh, lib/cap_check.sh

BIAS_DECISION=""

detect_cognitive_bias() {
  [ "$BIAS_ENABLED" != "true" ] && return
  local unit_num="$1"
  BIAS_DECISION=""
  start_spinner "🧲 Reading cognitive bias as creative fuel"

  local mechanism_history
  mechanism_history=$(build_mechanism_history)

  local bias_prompt="You are a metacognitive observer reading a thinking session across multiple cognitive lenses. Your job is not to flag biases as problems. It is to notice which cognitive biases are already alive in the thinking and ask how each could be channelled into something authentic and resonant.

Humans do not decide rationally. The best communication has always worked with how people actually think, not against it. Your job is to name the bias, show how the thinking is already channelling it, and ask whether it could be channelled more honestly.

Look for:
- Loss aversion: is the thinking tapping into what people fear losing? Could it create genuine urgency rather than manufactured panic?
- Identity/in-group bias: is the thinking building belonging? Could it invite people in rather than define them from outside?
- Self-serving bias: is the thinking empowering people's self-image? Could it make the audience the hero honestly?
- Scarcity: is the thinking creating desire through limits? Is the scarcity real or fabricated?
- Social proof: is the thinking leveraging what others do? Could it build trust rather than manufacture conformity?
- Availability heuristic: is one vivid image dominating? Could that vividness serve truth rather than distort it?
- Anchoring: has the first idea set the frame? Could that anchor be chosen deliberately rather than accidentally?

The line to draw: understanding how humans actually decide versus exploiting them. The former is craft. The latter is manipulation. Name which side each bias is on.

Respond with a JSON object containing:
- observations: an array of 2-3 short observation strings (name the bias, show how it is operating, ask how it could be channelled generatively)
- biases_detected: an array of bias names found in the thinking
- recommendation: a short string describing how the thinking could channel these biases more honestly

${mechanism_history}
THINKING SESSION:
$(get_conversation_for "mechanism")"

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

  local json_schema='{"type":"object","properties":{"observations":{"type":"array","items":{"type":"string"}},"biases_detected":{"type":"array","items":{"type":"string"}},"recommendation":{"type":"string"}},"required":["observations","biases_detected","recommendation"]}'

  local biases decision_json
  VERBOSE_CALLER="mechanism:bias"
  if claude_call_json "$tmpfile" "$json_schema"; then
    decision_json="$CLAUDE_RESPONSE"
    BIAS_DECISION="$decision_json"
    biases=$(echo "$decision_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for obs in d.get('observations', []):
    print(obs)
" 2>/dev/null || echo "No significant cognitive biases detected.")
    # Append to mechanism memory
    local bias_names bias_rec_text
    bias_names=$(echo "$decision_json" | python3 -c "import sys,json; print(', '.join(json.load(sys.stdin).get('biases_detected',[])))" 2>/dev/null || echo "")
    bias_rec_text=$(echo "$decision_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('recommendation',''))" 2>/dev/null || echo "")
    append_mechanism_memory "bias" "$unit_num" "$bias_names" "$bias_rec_text"
  else
    rm -f "$tmpfile"
    if [ "$RATE_LIMIT_HIT" = "true" ]; then
      stop_spinner "rate limit"
      return 1
    fi
    biases="No significant cognitive biases detected."
  fi
  rm -f "$tmpfile"

  stop_spinner "done"

  THINKING_SESSION="${THINKING_SESSION}

=== COGNITIVE BIAS CHECK (${UNIT_LABEL} ${unit_num}) ===
These biases are alive in the thinking. They are creative fuel, not warnings. The question is whether they are being channelled honestly or accidentally.
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
