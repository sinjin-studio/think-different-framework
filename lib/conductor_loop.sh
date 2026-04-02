#!/usr/bin/env bash
# ── Conductor orchestration loop ──
# The agentic core: a conductor agent makes structured decisions
# about which lens speaks next, creating an evaluate-decide-act loop.
# Replaces hardcoded composition sequences when --autonomous is enabled.
#
# Expects globals: $SEED_TOPIC, $THINKING_SESSION, $MODE, $TURN_COUNT,
#                  $UNIT_LABEL, $TRANSCRIPT_MD, $TRANSCRIPT_JSON
# Depends on: lib/call_lens.sh, lib/cap_check.sh, lenses/conductor.sh,
#             mechanisms/*.sh

# ── Guard rails ──
CONDUCTOR_MAX_TURNS="${CONDUCTOR_MAX_TURNS:-35}"
CONDUCTOR_MIN_TURNS="${CONDUCTOR_MIN_TURNS:-15}"
CONDUCTOR_MIN_DIVERSITY=7

run_conductor_session() {
  UNIT_LABEL="turn"

  # Source conductor
  source "${SCRIPT_DIR}/lenses/conductor.sh"

  # Source all lenses (conductor can call any of them)
  local lens_files
  lens_files=$(find "${SCRIPT_DIR}/lenses" -name "*.sh" ! -name "conductor.sh" -type f)
  while IFS= read -r lens_file; do
    [ -n "$lens_file" ] && source "$lens_file"
  done <<< "$lens_files"

  # Source context and mechanisms
  source "${SCRIPT_DIR}/context/gather.sh"
  source "${SCRIPT_DIR}/context/ground.sh"
  source "${SCRIPT_DIR}/mechanisms/friction.sh"
  source "${SCRIPT_DIR}/mechanisms/sensory.sh"
  source "${SCRIPT_DIR}/mechanisms/bias.sh"
  source "${SCRIPT_DIR}/mechanisms/transcendence.sh"
  source "${SCRIPT_DIR}/mechanisms/negative_space.sh"

  # Get conductor system prompt for this mode
  local conductor_system
  conductor_system=$(get_conductor_system "$MODE")

  # Skip seed prep and context gathering on resume (conversation already loaded)
  if [ "${RESUME_MODE:-}" != "true" ]; then
    # Gather context and prepare seed (using mode-appropriate preparation)
    gather_project_context || true
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    # Run seed preparation based on mode
    case "$MODE" in
      dyslexic)
        source "${SCRIPT_DIR}/context/fracture.sh"
        fracture_seed || true
        ;;
      spiral)
        source "${SCRIPT_DIR}/context/tune.sh"
        tune_seed || true
        ;;
      lapidary)
        source "${SCRIPT_DIR}/context/appraise.sh"
        appraise_seed || true
        ;;
    esac
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0
  fi

  # Build list of valid lens keys from sourced functions
  local valid_lenses=""
  local _func
  for _func in $(declare -F | sed -n 's/.*lens_emoji_\([a-z_]*\)/\1/p'); do
    if [ -z "$valid_lenses" ]; then
      valid_lenses="\"$_func\""
    else
      valid_lenses="${valid_lenses},\"$_func\""
    fi
  done

  # Track which lenses have spoken for diversity check
  local lenses_spoken=""
  local turn_in_session="${RESUME_FROM_TURN:-0}"
  local user_questions_asked=0

  # ── Main conductor loop ──
  while [ "$turn_in_session" -lt "$CONDUCTOR_MAX_TURNS" ]; do
    # Build conductor state summary
    local mech_history
    mech_history=$(build_mechanism_history)

    local state_summary="Session state:
- Mode: ${MODE}
- Turn: $((turn_in_session + 1)) of ${CONDUCTOR_MAX_TURNS} max
- Lenses heard: ${lenses_spoken:-none yet}
- Budget remaining: $((CONDUCTOR_MAX_TURNS - turn_in_session)) turns
${mech_history}"

    local conductor_thinking
    conductor_thinking=$(get_conversation_for "conductor")

    # ── Phase 1: Pick lens + instruction ──
    local phase1_prompt="SEED TOPIC: ${SEED_TOPIC}

${state_summary}

THINKING SO FAR:
${conductor_thinking}

---
Phase 1: Decide which lens should speak next and what instruction to give it. Or set next_lens to 'user' to pause and ask the operator a question (max 2 per session).

In your 'reasoning' field: name what territory the thinking has NOT explored and explain why you are choosing this lens now. This reasoning is logged for session review.

Respond with a JSON object."

    local phase1_schema="{\"type\":\"object\",\"properties\":{\"reasoning\":{\"type\":\"string\"},\"next_lens\":{\"type\":\"string\",\"enum\":[${valid_lenses},\"user\"]},\"phase\":{\"type\":\"string\"},\"instruction\":{\"type\":\"string\"}},\"required\":[\"reasoning\",\"next_lens\",\"phase\",\"instruction\"]}"

    local tmpfile
    tmpfile=$(mktemp)
    echo "$phase1_prompt" > "$tmpfile"

    start_spinner "🎼 Conductor deciding (phase 1)"

    local phase1_json
    VERBOSE_CALLER="conductor:phase1"
    if claude_call_json "$tmpfile" "$phase1_schema" "$conductor_system"; then
      phase1_json="$CLAUDE_RESPONSE"
    else
      rm -f "$tmpfile"
      if [ "$RATE_LIMIT_HIT" = "true" ]; then
        stop_spinner "rate limit"
        return 0
      fi
      stop_spinner "failed"
      echo "  Conductor could not decide. Ending session."
      break
    fi
    rm -f "$tmpfile"
    stop_spinner "done"

    # Parse Phase 1 decision
    local next_lens phase instruction reasoning
    next_lens=$(echo "$phase1_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('next_lens',''))" 2>/dev/null || echo "")
    phase=$(echo "$phase1_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('phase',''))" 2>/dev/null || echo "")
    instruction=$(echo "$phase1_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('instruction',''))" 2>/dev/null || echo "")
    reasoning=$(echo "$phase1_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('reasoning',''))" 2>/dev/null || echo "")

    # Log conductor reasoning
    if [ -n "$reasoning" ]; then
      echo "  💭 Conductor: ${reasoning}"
    fi

    # Handle user question
    if [ "$next_lens" = "user" ]; then
      if [ "$user_questions_asked" -ge 2 ]; then
        echo "  ⚠ Conductor wants to ask user but already asked ${user_questions_asked} questions (max 2). Skipping."
      else
        echo ""
        echo "  ━━━ CONDUCTOR QUESTION ━━━━━━━━━━━━━━━━━━━━━"
        echo "  ${instruction}"
        echo ""
        echo -n "  Your answer: "
        local user_answer
        read -r user_answer
        echo ""
        THINKING_SESSION="${THINKING_SESSION}

=== USER INPUT (${UNIT_LABEL} $((turn_in_session + 1))) ===
Conductor asked: ${instruction}
User answered: ${user_answer}"

        md_append_section 3 "❓ Conductor Question (${UNIT_LABEL} $((turn_in_session + 1)))"
        MD_BUFFER="${MD_BUFFER}
**Q:** ${instruction}
**A:** ${user_answer}
"
        json_append_entry "conductor" "User Question" "❓" "Clarification" "user_question" "$((turn_in_session + 1))" "$TURN_COUNT" "Q: ${instruction} | A: ${user_answer}"
        TURN_COUNT=$((TURN_COUNT + 1))

        json_flush
        md_flush
        save_state

        user_questions_asked=$((user_questions_asked + 1))
        turn_in_session=$((turn_in_session + 1))
      fi
      continue
    fi

    # Dispatch the chosen lens
    local lens_actually_spoke="false"
    if [ -n "$next_lens" ] && is_lens_active "$next_lens"; then
      local conv_len_before=${#THINKING_SESSION}
      call_lens "$next_lens" "$phase" "$((turn_in_session + 1))" "$instruction" || true
      [ "$RATE_LIMIT_HIT" = "true" ] && return 0

      # Check if the lens actually added to the thinking session (not a skip)
      if [ ${#THINKING_SESSION} -gt "$conv_len_before" ]; then
        lens_actually_spoke="true"
        # Track diversity only for lenses that actually contributed
        if [ -z "$lenses_spoken" ]; then
          lenses_spoken="$next_lens"
        else
          lenses_spoken="${lenses_spoken},${next_lens}"
        fi
      fi
      turn_in_session=$((turn_in_session + 1))
    else
      echo "  ⚠ Conductor chose unavailable lens: '${next_lens}'. Skipping."
      if [ -z "$next_lens" ]; then
        echo "  DEBUG: Raw conductor response: $(echo "$phase1_json" | head -c 200)"
      fi
      continue
    fi

    # ── Phase 2: React to lens output - decide mechanism/review/end ──
    # Skip Phase 2 if the lens self-skipped (nothing new to react to)
    if [ "$lens_actually_spoke" != "true" ]; then
      continue
    fi

    # Extract last lens response for the conductor to react to
    local last_response=""
    last_response=$(echo "$THINKING_SESSION" | python3 -c "
import sys
text = sys.stdin.read()
parts = text.split('\n--- ')
if len(parts) > 1:
    # Last turn, truncated to 500 chars for the conductor prompt
    print(parts[-1][:500])
else:
    print('')
" 2>/dev/null || echo "")

    local phase2_prompt="SEED TOPIC: ${SEED_TOPIC}

Session state:
- Turn: ${turn_in_session} of ${CONDUCTOR_MAX_TURNS} max
- Lenses heard: ${lenses_spoken:-none yet}
- Last lens was: ${next_lens}
$(build_mechanism_history)

LAST LENS RESPONSE:
${last_response}

---
Phase 2: You have just heard ${next_lens} speak. Now decide:
- Should a mechanism run to check the thinking? (friction, sensory, bias, transcendence, negative_space, or empty string for none)
- Should the session be reviewed now?
- Should the session end?

React to what the lens actually said, not what you predicted. If the response opened unexpected territory, let it breathe. If it circled or collapsed, intervene.

Respond with a JSON object."

    local phase2_schema="{\"type\":\"object\",\"properties\":{\"reasoning\":{\"type\":\"string\"},\"mechanism\":{\"type\":\"string\",\"enum\":[\"friction\",\"sensory\",\"bias\",\"transcendence\",\"negative_space\",\"\"]},\"review_now\":{\"type\":\"boolean\"},\"end_session\":{\"type\":\"boolean\"}},\"required\":[\"reasoning\",\"end_session\"]}"

    local tmpfile2
    tmpfile2=$(mktemp)
    echo "$phase2_prompt" > "$tmpfile2"

    start_spinner "🎼 Conductor reacting (phase 2)"

    local phase2_json
    VERBOSE_CALLER="conductor:phase2"
    if claude_call_json "$tmpfile2" "$phase2_schema" "$conductor_system"; then
      phase2_json="$CLAUDE_RESPONSE"
    else
      rm -f "$tmpfile2"
      if [ "$RATE_LIMIT_HIT" = "true" ]; then
        stop_spinner "rate limit"
        return 0
      fi
      stop_spinner "skipped"
      # If phase 2 fails, continue without mechanism/review - not fatal
      continue
    fi
    rm -f "$tmpfile2"
    stop_spinner "done"

    # Parse Phase 2 decision
    local mechanism_after review_now end_session phase2_reasoning
    mechanism_after=$(echo "$phase2_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('mechanism',''))" 2>/dev/null || echo "")
    review_now=$(echo "$phase2_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('review_now',False))" 2>/dev/null || echo "False")
    end_session=$(echo "$phase2_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('end_session',False))" 2>/dev/null || echo "False")
    phase2_reasoning=$(echo "$phase2_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('reasoning',''))" 2>/dev/null || echo "")

    if [ -n "$phase2_reasoning" ]; then
      echo "  💭 Conductor (react): ${phase2_reasoning}"
    fi

    # End session if conductor says so (check turn floor + diversity first)
    if [ "$end_session" = "True" ]; then
      if [ "$turn_in_session" -lt "$CONDUCTOR_MIN_TURNS" ] && [ "$turn_in_session" -lt "$CONDUCTOR_MAX_TURNS" ]; then
        echo "  ⚠ Conductor wants to end at turn ${turn_in_session} but minimum is ${CONDUCTOR_MIN_TURNS}. Continuing."
      else
        local unique_count
        unique_count=$(echo "$lenses_spoken" | tr ',' '\n' | sort -u | grep -c '.' || echo "0")
        if [ "$unique_count" -lt "$CONDUCTOR_MIN_DIVERSITY" ] && [ "$turn_in_session" -lt "$CONDUCTOR_MAX_TURNS" ]; then
          echo "  ⚠ Conductor wants to end but only ${unique_count} distinct lenses heard (min: ${CONDUCTOR_MIN_DIVERSITY}). Continuing."
        else
          echo "  🎼 Conductor ending session after ${turn_in_session} turns"
          break
        fi
      fi
    fi

    # Run mechanism if requested
    if [ -n "$mechanism_after" ]; then
      case "$mechanism_after" in
        friction)
          detect_prediction_errors "$((turn_in_session))" || true
          [ "$RATE_LIMIT_HIT" = "true" ] && return 0
          handle_friction_decision "$((turn_in_session))"
          [ "$RATE_LIMIT_HIT" = "true" ] && return 0
          ;;
        sensory)
          sensory_check || true
          ;;
        bias)
          detect_cognitive_bias "$((turn_in_session))" || true
          [ "$RATE_LIMIT_HIT" = "true" ] && return 0
          ;;
        transcendence)
          transcendence_check "$((turn_in_session))" || true
          [ "$RATE_LIMIT_HIT" = "true" ] && return 0
          handle_transcendence_decision
          if [ "$MECHANISM_SKIP_TO_GROUND" = "true" ]; then
            if [ "$turn_in_session" -lt "$CONDUCTOR_MIN_TURNS" ]; then
              echo "  ↪ Transcendence triggered but turn ${turn_in_session} < min ${CONDUCTOR_MIN_TURNS}. Continuing."
              MECHANISM_SKIP_TO_GROUND=""
            else
              echo "  ↪ Transcendence triggered early grounding"
              break
            fi
          fi
          ;;
        negative_space)
          map_negative_space "$((turn_in_session))" || true
          [ "$RATE_LIMIT_HIT" = "true" ] && return 0
          handle_negative_space_decision "$((turn_in_session))"
          [ "$RATE_LIMIT_HIT" = "true" ] && return 0
          ;;
      esac
    fi

    # Review if conductor requests it
    if [ "$review_now" = "True" ]; then
      source "${SCRIPT_DIR}/mechanisms/review.sh"
      review_session || true
      local verdict
      verdict=$(get_review_verdict)
      if [ "$verdict" = "restart" ]; then
        echo "  ↻ Mid-session review recommends restart"
        break
      fi
    fi
  done

  # ── GROUND ──
  echo ""
  echo "  ━━━ GROUNDING ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  md_append_section 2 "Grounding"

  # Final grounding lenses based on mode
  case "$MODE" in
    dyslexic)
      if is_lens_active "empath"; then
        call_lens "empath" "ground" "$((turn_in_session + 1))" "This is the end. Deliver the verdict. What is new here? What would actually change behaviour? Strip away the metaphors. Say what remains. Identify the 1-3 ideas that pass the simplicity test. For each one: what is the smallest experiment someone could take tomorrow?" || true
        [ "$RATE_LIMIT_HIT" = "true" ] && return 0
      fi
      if is_lens_active "reifier"; then
        call_lens "reifier" "ground" "$((turn_in_session + 1))" "Final word. State the single most important insight. State it once with nuance. Then state it again in one sentence a child could understand. Both versions should be true." || true
      fi
      ;;
    spiral)
      if is_lens_active "empath"; then
        call_lens "empath" "ground" "$((turn_in_session + 1))" "What is new here? What would actually change behaviour? Strip away every metaphor and say what remains." || true
        [ "$RATE_LIMIT_HIT" = "true" ] && return 0
      fi
      if is_lens_active "integrator"; then
        call_lens "integrator" "ground" "$((turn_in_session + 1))" "Final word. Name the single most important insight. State it simply. Then state it even more simply. Make it count." || true
      fi
      ;;
    lapidary)
      if is_lens_active "empath"; then
        call_lens "empath" "ground" "$((turn_in_session + 1))" "The session is ending. What does the person at the centre of this actually need? What would change their behaviour? Strip away everything and say what remains." || true
        [ "$RATE_LIMIT_HIT" = "true" ] && return 0
      fi
      if is_lens_active "editor"; then
        call_lens "editor" "ground" "$((turn_in_session + 1))" "Final word. State the single most important insight in the most precise, economical language you can. Make every word load-bearing." || true
      fi
      ;;
  esac
}
