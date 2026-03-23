#!/usr/bin/env bash
# ── Core agent invocation ──
# Dynamic dispatch: calls agent_emoji_${key}, agent_name_${key},
# agent_bias_${key}, agent_system_${key} for the given agent key.
# Appends COMMON_RULES + PHASE INSTRUCTION to the system prompt.
# Expects globals: $SEED_TOPIC, $CONVERSATION, $UNIT_LABEL, $TURN_COUNT,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON
# Depends on: lib/json.sh, lib/md.sh

# ── Agent inclusion/exclusion ──
# Checks INCLUDE_AGENTS and EXCLUDE_AGENTS arrays.
# Explicit exclude wins. Explicit include overrides mode defaults.
is_agent_active() {
  local key="$1"
  # Explicit exclude wins
  if [ ${#EXCLUDE_AGENTS[@]} -gt 0 ]; then
  for ex in "${EXCLUDE_AGENTS[@]}"; do
    [ "$ex" = "$key" ] && return 1
  done
  fi
  # Explicit include wins over mode defaults
  if [ ${#INCLUDE_AGENTS[@]} -gt 0 ]; then
  for inc in "${INCLUDE_AGENTS[@]}"; do
    [ "$inc" = "$key" ] && return 0
  done
  fi
  # Fall through to mode default (return 0 = active)
  return 0
}

# ── Shuffle array (Fisher-Yates, bash 3.2 compatible) ──
shuf_array() {
  local arr=("$@")
  local i j tmp
  for (( i=${#arr[@]}-1; i>0; i-- )); do
    j=$(( RANDOM % (i+1) ))
    tmp="${arr[$i]}"
    arr[$i]="${arr[$j]}"
    arr[$j]="$tmp"
  done
  printf '%s\n' "${arr[@]}"
}

# ── Dispatch a round of agents (supports shuffle) ──
# Each entry: "key:phase:unit_num:instruction"
# Delimiter is the first colon-separated triple, rest is instruction
dispatch_round() {
  local entries=("$@")
  if [ "$SHUFFLE_ENABLED" = "true" ]; then
    local shuffled
    shuffled=$(shuf_array "${entries[@]}")
    entries=()
    while IFS= read -r line; do
      entries+=("$line")
    done <<< "$shuffled"
  fi
  for entry in "${entries[@]}"; do
    local key phase unit_num instruction
    key="${entry%%:*}"; entry="${entry#*:}"
    phase="${entry%%:*}"; entry="${entry#*:}"
    unit_num="${entry%%:*}"; instruction="${entry#*:}"
    if is_agent_active "$key"; then
      call_agent "$key" "$phase" "$unit_num" "$instruction"
    fi
  done
}

COMMON_RULES="Rules:
- Never summarise what others have said - always add something NEW
- Keep responses to 150-200 words - density over volume
- Write in first person, conversationally, as if thinking aloud
- Do not use bullet points, numbered lists, headers, or markdown formatting
- Do not use em dashes. Use hyphens, commas, or full stops instead
- Output ONLY your thinking. No preamble, no meta-commentary, just the thought itself
- If a PROJECT CONTEXT is provided, treat it as ground truth about the real situation
- If a LENS CONTEXT is provided, treat it as possible starting points, not constraints
- You are not trying to be clever. You are trying to see differently.
- You are a misfit. A round peg. You have no respect for the way things are usually done."

call_agent() {
  local agent_key="$1"
  local phase="$2"
  local unit_num="$3"
  local instruction="$4"

  local emoji name bias system_prompt
  emoji=$(agent_emoji_${agent_key})
  name=$(agent_name_${agent_key})
  bias=$(agent_bias_${agent_key})
  system_prompt=$(agent_system_${agent_key})

  system_prompt="${system_prompt}

${COMMON_RULES}

PHASE INSTRUCTION: ${instruction}"

  local user_message="SEED TOPIC: ${SEED_TOPIC}

CONVERSATION SO FAR:
${CONVERSATION}

---
It is now your turn. See differently. Add something new."

  echo -n "  ${emoji} ${name} is thinking..."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$user_message" > "$tmpfile"

  local response
  response=$(cat "$tmpfile" | claude -p --system-prompt "$system_prompt" 2>/dev/null) || {
    response="[Agent could not respond]"
  }
  rm -f "$tmpfile"

  echo " done"

  CONVERSATION="${CONVERSATION}

--- ${emoji} ${name} (${phase}, ${UNIT_LABEL} ${unit_num}) ---
${response}"

  md_append_agent "$emoji" "$name" "$bias" "$response"
  json_append_entry "$agent_key" "$name" "$emoji" "$bias" "$phase" "$unit_num" "$TURN_COUNT" "$response"

  TURN_COUNT=$((TURN_COUNT + 1))
}
