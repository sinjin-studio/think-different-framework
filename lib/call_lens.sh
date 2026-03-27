#!/usr/bin/env bash
# ── Core lens invocation ──
# Dynamic dispatch: calls lens_emoji_${key}, lens_name_${key},
# lens_bias_${key}, lens_system_${key} for the given lens key.
# Appends COMMON_RULES + PHASE INSTRUCTION to the system prompt.
# Expects globals: $SEED_TOPIC, $CONVERSATION, $UNIT_LABEL, $TURN_COUNT,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON, $RESUME_FROM_TURN
# Depends on: lib/json.sh, lib/md.sh, lib/cap_check.sh

# ── Lens inclusion/exclusion ──
# Checks INCLUDE_LENSES and EXCLUDE_LENSES arrays.
# Explicit exclude wins. Explicit include overrides mode defaults.
is_lens_active() {
  local key="$1"
  # Check lens actually exists
  if ! type "lens_emoji_${key}" &>/dev/null; then
    return 1
  fi
  # Explicit exclude wins
  if [ ${#EXCLUDE_LENSES[@]} -gt 0 ]; then
  for ex in "${EXCLUDE_LENSES[@]}"; do
    [ "$ex" = "$key" ] && return 1
  done
  fi
  # Explicit include wins over mode defaults
  if [ ${#INCLUDE_LENSES[@]} -gt 0 ]; then
  for inc in "${INCLUDE_LENSES[@]}"; do
    [ "$inc" = "$key" ] && return 0
  done
  fi
  # Fall through to mode default (return 0 = active)
  return 0
}

# ── Lens depth (--depth flag) ──
# Returns the depth level for a given lens key by parsing $LENS_DEPTH.
# Per-lens override (key:level) takes priority over global level.
get_lens_depth() {
  local key="$1"
  local depth_str="${LENS_DEPTH:-deep}"
  local _old_ifs="$IFS"
  local IFS=','
  # Check for per-lens override (key:level)
  for entry in $depth_str; do
    case "$entry" in
      "${key}:"*) echo "${entry#*:}"; IFS="$_old_ifs"; return ;;
    esac
  done
  # Fall back to global (bare value without colon)
  for entry in $depth_str; do
    case "$entry" in
      *:*) ;; # skip per-lens entries
      *) echo "$entry"; IFS="$_old_ifs"; return ;;
    esac
  done
  IFS="$_old_ifs"
  echo "deep"
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

# ── Dispatch a round of lenses (supports shuffle) ──
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
    if is_lens_active "$key"; then
      call_lens "$key" "$phase" "$unit_num" "$instruction" || true
      if [ "$CAP_LIMIT_HIT" = "true" ]; then
        return 1
      fi
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
- You are a misfit. A round peg. You have no respect for the way things are usually done.
- You are thinking because something matters enough to deserve it. Not for the sake of thinking."

# ── Context compaction ──
# Distills the growing CONVERSATION into a high-signal digest when it exceeds
# a character threshold or a turn interval. Preserves the last few verbatim turns
# so the next lens has both strategic memory and immediate context.
# Full transcript is always preserved in MD/JSON files (written incrementally).
COMPACT_INTERVAL=8
COMPACT_CHAR_THRESHOLD=15000
LAST_COMPACT_TURN=0

compact_conversation() {
  [ "${COMPACT_ENABLED:-true}" != "true" ] && return
  # Only compact if we've done enough turns since last compaction
  local turns_since=$((TURN_COUNT - LAST_COMPACT_TURN))
  local conv_len=${#CONVERSATION}
  if [ "$turns_since" -lt "$COMPACT_INTERVAL" ] && [ "$conv_len" -lt "$COMPACT_CHAR_THRESHOLD" ]; then
    return
  fi

  start_spinner "📦 Compacting conversation"

  local compact_prompt="Distill this creative thinking conversation into its essential moves. Preserve:
- Key insights discovered (use exact phrasing for breakthrough moments)
- Active tensions and unresolved contradictions
- Positions taken and territory opened by each lens
- Territory NOT yet explored
- Any mechanism findings (friction points, biases identified, transcendence checks)

Discard repetition, mechanism boilerplate, and lens responses that only restated what others said.

Output a DIGEST of 400-600 words. Write it as a flowing summary, not a list. This digest will be read by subsequent lenses as their memory of the conversation so far."

  local compact_message="SEED TOPIC: ${SEED_TOPIC}

FULL CONVERSATION (${TURN_COUNT} turns):
${CONVERSATION}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$compact_message" > "$tmpfile"

  VERBOSE_CALLER="compact"
  if claude_call "$tmpfile" "$compact_prompt"; then
    local digest="$CLAUDE_RESPONSE"
    # Extract the last 3-4 lens turns (everything after the last 3 "--- " markers)
    local recent_turns=""
    recent_turns=$(echo "$CONVERSATION" | python3 -c "
import sys
text = sys.stdin.read()
parts = text.split('\n--- ')
# Keep last 3 turns (rejoin with the delimiter)
if len(parts) > 3:
    recent = '\n--- '.join(parts[-3:])
    print('--- ' + recent)
else:
    print(text)
" 2>/dev/null || echo "$CONVERSATION")

    CONVERSATION="=== COMPACTED AT TURN ${TURN_COUNT} ===
${digest}

=== RECENT TURNS ===
${recent_turns}"

    LAST_COMPACT_TURN=$TURN_COUNT

    # Log compaction to transcript
    md_append_section "3" "📦 Context compacted at turn ${TURN_COUNT}"
    MD_BUFFER="${MD_BUFFER}
Conversation distilled to digest + last 3 turns.
"
    md_flush

    stop_spinner "done"
  else
    rm -f "$tmpfile"
    stop_spinner "skipped"
    return
  fi
  rm -f "$tmpfile"
}

call_lens() {
  local lens_key="$1"
  local phase="$2"
  local unit_num="$3"
  local instruction="$4"

  # Resume skip: if this turn was already completed, skip the Claude call
  if [ "$TURN_COUNT" -lt "$RESUME_FROM_TURN" ]; then
    echo "  ↩ Turn $((TURN_COUNT + 1)) skipped (resuming)"
    TURN_COUNT=$((TURN_COUNT + 1))
    return 0
  fi

  # Compact conversation if it has grown too large
  compact_conversation

  local emoji name bias system_prompt
  emoji=$(lens_emoji_${lens_key})
  name=$(lens_name_${lens_key})
  bias=$(lens_bias_${lens_key})
  system_prompt=$(lens_system_${lens_key})

  # Per-lens tool override: if lens_tools_${key} exists, use its tools for this call
  local saved_tools_flag="$ALLOWED_TOOLS_FLAG"
  if type "lens_tools_${lens_key}" &>/dev/null; then
    local lens_tools
    lens_tools=$(lens_tools_${lens_key})
    if [ -n "$lens_tools" ]; then
      ALLOWED_TOOLS_FLAG="--allowedTools ${lens_tools}"
    else
      ALLOWED_TOOLS_FLAG=""
    fi
  fi

  # Skip-turn autonomy: in strict mode, a separate pre-call asks the lens if it should speak.
  # Default autonomous mode uses inline skip detection (lens responds with SKIP: reason).
  if [ "${AUTONOMOUS_MODE:-}" = "true" ] && [ "${SKIP_STRICT:-}" = "true" ]; then
    local skip_prompt="You are ${name} (${bias}). Read the seed topic and conversation so far. Do you have something genuinely new to add that only your specific lens can see? If the conversation has already covered your perspective, or if speaking now would be redundant, be honest about it."
    local skip_message="SEED TOPIC: ${SEED_TOPIC}

CONVERSATION SO FAR:
${CONVERSATION}

Should you speak? Answer with JSON."
    local skip_schema='{"type":"object","properties":{"should_speak":{"type":"boolean"},"reason":{"type":"string"}},"required":["should_speak","reason"]}'

    local skip_tmpfile
    skip_tmpfile=$(mktemp)
    echo "$skip_message" > "$skip_tmpfile"

    VERBOSE_CALLER="skip:${lens_key}"
    if claude_call_json "$skip_tmpfile" "$skip_schema" "$skip_prompt"; then
      local should_speak
      should_speak=$(echo "$CLAUDE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('should_speak', True))" 2>/dev/null || echo "True")
      local skip_reason
      skip_reason=$(echo "$CLAUDE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('reason', ''))" 2>/dev/null || echo "")

      if [ "$should_speak" = "False" ]; then
        rm -f "$skip_tmpfile"
        ALLOWED_TOOLS_FLAG="$saved_tools_flag"
        echo "  ⏭ ${emoji} ${name} skipped: ${skip_reason}"
        md_append_section "3" "${emoji} ${name} (skipped: ${skip_reason})"
        TURN_COUNT=$((TURN_COUNT + 1))
        return 0
      fi
    fi
    rm -f "$skip_tmpfile"
  fi

  # Build skip-turn inline rule for autonomous mode (non-strict)
  local skip_rule=""
  if [ "${AUTONOMOUS_MODE:-}" = "true" ] && [ "${SKIP_STRICT:-}" != "true" ]; then
    skip_rule="
- If you genuinely have nothing new to add that only your specific lens can see, respond with exactly: SKIP: [one-sentence reason]. Otherwise, respond with your thinking."
  fi

  system_prompt="${system_prompt}

${COMMON_RULES}${skip_rule}

PHASE INSTRUCTION: ${instruction}"

  local user_message="SEED TOPIC: ${SEED_TOPIC}

CONVERSATION SO FAR:
${CONVERSATION}

---
It is now your turn. See differently. Add something new."

  start_spinner "${emoji} ${name}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$user_message" > "$tmpfile"

  VERBOSE_CALLER="lens:${lens_key}"
  local response
  if claude_call "$tmpfile" "$system_prompt"; then
    response="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    ALLOWED_TOOLS_FLAG="$saved_tools_flag"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      stop_spinner "cap limit"
      return 1
    fi
    response="[Lens could not respond]"
  fi
  rm -f "$tmpfile"

  # Inline skip detection: if the lens self-skipped, log and return early
  if [ "${AUTONOMOUS_MODE:-}" = "true" ] && [ "${SKIP_STRICT:-}" != "true" ]; then
    case "$response" in
      SKIP:*)
        local skip_reason="${response#SKIP: }"
        skip_reason="${skip_reason#SKIP:}"
        stop_spinner "skipped"
        ALLOWED_TOOLS_FLAG="$saved_tools_flag"
        echo "  ⏭ ${emoji} ${name} skipped: ${skip_reason}"
        md_append_section "3" "${emoji} ${name} (skipped: ${skip_reason})"
        TURN_COUNT=$((TURN_COUNT + 1))
        json_flush
        md_flush
        save_state
        return 0
        ;;
    esac
  fi

  stop_spinner "done"

  # Restore global tools flag
  ALLOWED_TOOLS_FLAG="$saved_tools_flag"

  CONVERSATION="${CONVERSATION}

--- ${emoji} ${name} (${phase}, ${UNIT_LABEL} ${unit_num}) ---
${response}"

  md_append_lens "$emoji" "$name" "$bias" "$response"
  json_append_entry "$lens_key" "$name" "$emoji" "$bias" "$phase" "$unit_num" "$TURN_COUNT" "$response"

  TURN_COUNT=$((TURN_COUNT + 1))

  # Atomic flush + save state after each successful turn
  json_flush
  md_flush
  save_state
}

# ── Mechanism memory ──
# Accumulates structured findings from mechanisms so subsequent mechanisms
# can build on prior analysis instead of re-discovering the same patterns.
MECHANISM_MEMORY=()

append_mechanism_memory() {
  local mechanism="$1"
  local unit_num="$2"
  local recommendation="$3"
  local summary="$4"
  MECHANISM_MEMORY+=("${mechanism}:${unit_num}:${recommendation}:${summary}")
}

# Build a MECHANISM HISTORY prompt section from accumulated memory
build_mechanism_history() {
  if [ ${#MECHANISM_MEMORY[@]} -eq 0 ]; then
    echo ""
    return
  fi
  local history="
MECHANISM HISTORY (what previous checks found - focus on NEW findings, do not repeat these unless they have evolved):
"
  local entry
  for entry in "${MECHANISM_MEMORY[@]}"; do
    local mech unit rec summary
    mech="${entry%%:*}"; entry="${entry#*:}"
    unit="${entry%%:*}"; entry="${entry#*:}"
    rec="${entry%%:*}"; summary="${entry#*:}"
    history="${history}- ${UNIT_LABEL} ${unit} ${mech}: ${summary} (recommendation: ${rec})
"
  done
  echo "$history"
}

# ── Mechanism flow control helpers ──
# These read the structured decisions from mechanisms and take action.
# Set MECHANISM_SKIP_TO_GROUND="true" to signal mode scripts to skip remaining rounds.
MECHANISM_SKIP_TO_GROUND=""
TRANSCENDENCE_STRIKE_COUNT=0

# React to friction decision: inject a lens if the friction detector recommends redirect
handle_friction_decision() {
  local unit_num="$1"
  [ -z "$FRICTION_DECISION" ] && return
  local friction_rec
  friction_rec=$(echo "$FRICTION_DECISION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('recommendation','continue'))" 2>/dev/null || echo "continue")
  if [ "$friction_rec" = "redirect" ]; then
    local inject_key
    inject_key=$(echo "$FRICTION_DECISION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('inject_lens',''))" 2>/dev/null || echo "")
    if [ -n "$inject_key" ] && is_lens_active "$inject_key"; then
      echo "  ↪ Friction redirect: injecting ${inject_key}"
      call_lens "$inject_key" "friction_redirect" "$unit_num" "The friction detector found the conversation is stuck. You are being brought in to break the pattern. Look at the friction points and bring your specific perspective to the contradictions." || true
    fi
  fi
}

# React to transcendence decision: two-strike pattern before skip to grounding.
# First signal is noted but session continues. Second consecutive signal triggers grounding.
# A "continue" signal resets the counter. This prevents premature exit - research shows
# breakthroughs often arrive at iteration 10+ (Anthropic harness design, 2025).
handle_transcendence_decision() {
  [ -z "$TRANSCENDENCE_DECISION" ] && return
  local trans_rec
  trans_rec=$(echo "$TRANSCENDENCE_DECISION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('recommendation','continue'))" 2>/dev/null || echo "continue")
  if [ "$trans_rec" = "compress" ] || [ "$trans_rec" = "ground_early" ]; then
    TRANSCENDENCE_STRIKE_COUNT=$((TRANSCENDENCE_STRIKE_COUNT + 1))
    if [ "$TRANSCENDENCE_STRIKE_COUNT" -ge 2 ]; then
      echo "  ↪ Transcendence ${trans_rec} (strike ${TRANSCENDENCE_STRIKE_COUNT}/2): skipping to grounding"
      MECHANISM_SKIP_TO_GROUND="true"
    else
      echo "  ↪ Transcendence ${trans_rec} (strike ${TRANSCENDENCE_STRIKE_COUNT}/2): noted, continuing"
    fi
  else
    TRANSCENDENCE_STRIKE_COUNT=0
  fi
}

# React to negative space decision: redirect a lens into unexplored territory
handle_negative_space_decision() {
  local unit_num="$1"
  [ -z "$NEGATIVE_SPACE_DECISION" ] && return
  local ns_rec
  ns_rec=$(echo "$NEGATIVE_SPACE_DECISION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('recommendation','note_and_continue'))" 2>/dev/null || echo "note_and_continue")
  if [ "$ns_rec" = "redirect_to_void" ]; then
    local inject_key ns_territory
    inject_key=$(echo "$NEGATIVE_SPACE_DECISION" | python3 -c "import sys,json; t=json.load(sys.stdin).get('territories',[]); print(t[0].get('suggested_lens','') if t else '')" 2>/dev/null || echo "")
    ns_territory=$(echo "$NEGATIVE_SPACE_DECISION" | python3 -c "import sys,json; t=json.load(sys.stdin).get('territories',[]); print(t[0].get('description','') if t else '')" 2>/dev/null || echo "")
    if [ -n "$inject_key" ] && is_lens_active "$inject_key"; then
      echo "  ↪ Negative space redirect: sending ${inject_key} into the dark"
      call_lens "$inject_key" "negative_space_exploration" "$unit_num" "The negative space mapper found territory nobody has explored yet: ${ns_territory}. Point your lens at this dark patch. What do you see there?" || true
    fi
  fi
}
