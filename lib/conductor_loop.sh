#!/usr/bin/env bash
# ── Conductor orchestration loop ──
# The agentic core: a conductor agent makes structured decisions
# about which lens speaks next, creating an evaluate-decide-act loop.
# Replaces hardcoded composition sequences when --autonomous is enabled.
#
# Expects globals: $SEED_TOPIC, $CONVERSATION, $MODE, $TURN_COUNT,
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
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0

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
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0
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
  local turn_in_session=0

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

    local conductor_prompt="SEED TOPIC: ${SEED_TOPIC}

${state_summary}

CONVERSATION SO FAR:
${CONVERSATION}

---
What should happen next? Decide which lens should speak and what instruction to give it. Or trigger a mechanism, review, or end the session.

Respond with a JSON object."

    local decision_schema="{\"type\":\"object\",\"properties\":{\"next_lens\":{\"type\":\"string\",\"enum\":[${valid_lenses}]},\"phase\":{\"type\":\"string\"},\"instruction\":{\"type\":\"string\"},\"mechanism_after\":{\"type\":\"string\",\"enum\":[\"friction\",\"sensory\",\"bias\",\"transcendence\",\"negative_space\",\"\"]},\"review_now\":{\"type\":\"boolean\"},\"end_session\":{\"type\":\"boolean\"}},\"required\":[\"next_lens\",\"phase\",\"instruction\",\"end_session\"]}"

    local tmpfile
    tmpfile=$(mktemp)
    echo "$conductor_prompt" > "$tmpfile"

    start_spinner "🎼 Conductor deciding"

    local decision_json
    VERBOSE_CALLER="conductor"
    if claude_call_json "$tmpfile" "$decision_schema" "$conductor_system"; then
      decision_json="$CLAUDE_RESPONSE"
    else
      rm -f "$tmpfile"
      if [ "$CAP_LIMIT_HIT" = "true" ]; then
        stop_spinner "cap limit"
        return 0
      fi
      stop_spinner "failed"
      echo "  Conductor could not decide. Ending session."
      break
    fi
    rm -f "$tmpfile"
    stop_spinner "done"

    # Parse the decision
    local next_lens phase instruction mechanism_after review_now end_session
    next_lens=$(echo "$decision_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('next_lens',''))" 2>/dev/null || echo "")
    phase=$(echo "$decision_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('phase',''))" 2>/dev/null || echo "")
    instruction=$(echo "$decision_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('instruction',''))" 2>/dev/null || echo "")
    mechanism_after=$(echo "$decision_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('mechanism_after',''))" 2>/dev/null || echo "")
    review_now=$(echo "$decision_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('review_now',False))" 2>/dev/null || echo "False")
    end_session=$(echo "$decision_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('end_session',False))" 2>/dev/null || echo "False")

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

    # Dispatch the chosen lens
    if [ -n "$next_lens" ] && is_lens_active "$next_lens"; then
      call_lens "$next_lens" "$phase" "$((turn_in_session + 1))" "$instruction" || true
      [ "$CAP_LIMIT_HIT" = "true" ] && return 0

      # Track diversity
      if [ -z "$lenses_spoken" ]; then
        lenses_spoken="$next_lens"
      else
        lenses_spoken="${lenses_spoken},${next_lens}"
      fi
      turn_in_session=$((turn_in_session + 1))
    else
      echo "  ⚠ Conductor chose unavailable lens: '${next_lens}'. Skipping."
      if [ -z "$next_lens" ]; then
        echo "  DEBUG: Raw conductor response: $(echo "$decision_json" | head -c 200)"
      fi
    fi

    # Run mechanism if requested
    if [ -n "$mechanism_after" ]; then
      case "$mechanism_after" in
        friction)
          detect_prediction_errors "$((turn_in_session))" || true
          [ "$CAP_LIMIT_HIT" = "true" ] && return 0
          handle_friction_decision "$((turn_in_session))"
          [ "$CAP_LIMIT_HIT" = "true" ] && return 0
          ;;
        sensory)
          sensory_check || true
          ;;
        bias)
          detect_cognitive_bias "$((turn_in_session))" || true
          [ "$CAP_LIMIT_HIT" = "true" ] && return 0
          ;;
        transcendence)
          transcendence_check "$((turn_in_session))" || true
          [ "$CAP_LIMIT_HIT" = "true" ] && return 0
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
          [ "$CAP_LIMIT_HIT" = "true" ] && return 0
          handle_negative_space_decision "$((turn_in_session))"
          [ "$CAP_LIMIT_HIT" = "true" ] && return 0
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
        [ "$CAP_LIMIT_HIT" = "true" ] && return 0
      fi
      if is_lens_active "reifier"; then
        call_lens "reifier" "ground" "$((turn_in_session + 1))" "Final word. State the single most important insight. State it once with nuance. Then state it again in one sentence a child could understand. Both versions should be true." || true
      fi
      ;;
    spiral)
      if is_lens_active "empath"; then
        call_lens "empath" "ground" "$((turn_in_session + 1))" "What is new here? What would actually change behaviour? Strip away every metaphor and say what remains." || true
        [ "$CAP_LIMIT_HIT" = "true" ] && return 0
      fi
      if is_lens_active "integrator"; then
        call_lens "integrator" "ground" "$((turn_in_session + 1))" "Final word. Name the single most important insight. State it simply. Then state it even more simply. Make it count." || true
      fi
      ;;
    lapidary)
      if is_lens_active "empath"; then
        call_lens "empath" "ground" "$((turn_in_session + 1))" "The session is ending. What does the person at the centre of this actually need? What would change their behaviour? Strip away everything and say what remains." || true
        [ "$CAP_LIMIT_HIT" = "true" ] && return 0
      fi
      if is_lens_active "editor"; then
        call_lens "editor" "ground" "$((turn_in_session + 1))" "Final word. State the single most important insight in the most precise, economical language you can. Make every word load-bearing." || true
      fi
      ;;
  esac
}
