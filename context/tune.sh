#!/usr/bin/env bash
# ── Seed tuning (spiral composition) ──
# Generates tensions, human realities, and wildcards for the seed.
# Grounding is embedded: surfaces and verifies assumptions before tuning.
# Expects globals: $SEED_TOPIC, $PROJECT_CONTEXT, $CONVERSATION,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON, $TURN_COUNT, $OUTPUT_DIR,
#                  $TIMESTAMP, $GROUND_ENABLED, $ALLOWED_TOOLS
# Depends on: lib/json.sh, context/ground.sh (for build_ground_preamble)

tune_seed() {
  # Build optional grounding preamble
  local ground_section=""
  if [ "${GROUND_ENABLED:-true}" = "true" ]; then
    local web_available="false"
    case "${ALLOWED_TOOLS:-}" in
      *WebSearch*) web_available="true" ;;
    esac

    if [ "$web_available" != "true" ]; then
      echo ""
      echo "  ⚠ Web search unavailable - assumptions will be unverified."
      echo "  Rerun with default tools or --allowedTools 'WebSearch,WebFetch' for verified grounding."
      echo ""
    fi

    ground_section="$(build_ground_preamble)

Then tune the seed."
  fi

  start_spinner "🌱 Tuning lenses to the seed"

  local tuning_prompt="You are preparing a multi-lens brainstorming session. Given the seed topic below, suggest unexpected angles of approach.

${ground_section:+${ground_section}

}Output EXACTLY this format, nothing else:

${ground_section:+ASSUMPTIONS: [3-4 assumptions about the problem/audience/situation, each marked VERIFIED or UNVERIFIED, with 2-3 alternative realities]

}TENSIONS: [3-4 genuine tensions or contradictions embedded in the seed that are worth exploring. Frame each as a sharp question.]

HUMAN REALITY: [2-3 observations about the actual lived experience of the person or people at the centre of this seed. What do they feel? What do they want? What are they afraid of? Be specific and empathetic, not abstract.]

WILDCARD: [One completely orthogonal concept, phenomenon, or question that has no obvious connection to the seed but might produce the most interesting collision.]

${PROJECT_CONTEXT:+PROJECT CONTEXT (use this to ground your suggestions in the actual situation):
${PROJECT_CONTEXT}}
${ZEITGEIST_CONTEXT:+
${ZEITGEIST_CONTEXT}}

SEED TOPIC: ${SEED_TOPIC}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$tuning_prompt" > "$tmpfile"

  VERBOSE_CALLER="seed:tune"
  if claude_call "$tmpfile"; then
    LENS_CONTEXT="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$RATE_LIMIT_HIT" = "true" ]; then
      stop_spinner "rate limit"
      return 1
    fi
    LENS_CONTEXT="No lens context available. Lenses should follow their own instincts."
  fi
  rm -f "$tmpfile"

  stop_spinner "done"
  echo ""

  CONVERSATION="The session begins with the seed topic: ${SEED_TOPIC}"

  if [ -n "$PROJECT_CONTEXT" ]; then
    CONVERSATION="${CONVERSATION}

PROJECT CONTEXT (ground truth about the actual project, business, or situation this seed relates to):
${PROJECT_CONTEXT}"
  fi

  if [ -n "${SEED_VERIFICATION:-}" ]; then
    CONVERSATION="${CONVERSATION}

PROVOCATION VERIFICATION (claims checked, framing flagged - use corrected provocation as ground truth):
${SEED_VERIFICATION}"
  fi

  CONVERSATION="${CONVERSATION}

LENS CONTEXT (optional starting points for the lenses, not constraints):
${LENS_CONTEXT}"

  if [ -n "${SEED_VERIFICATION:-}" ]; then
    md_append_section 3 "Provocation Verification"
    MD_BUFFER="${MD_BUFFER}
${SEED_VERIFICATION}
"
    json_append_entry "verify" "Provocation Verification" "🔍" "Fact Check" "verify" 0 0 "$SEED_VERIFICATION"
  fi

  if [ -n "$PROJECT_CONTEXT" ]; then
    md_append_section 3 "Project Context"
    MD_BUFFER="${MD_BUFFER}
${PROJECT_CONTEXT}
"
  fi

  md_append_section 3 "Lens Context"
  MD_BUFFER="${MD_BUFFER}
${LENS_CONTEXT}
"

  if [ -n "$PROJECT_CONTEXT" ]; then
    json_append_entry "context" "Context Gatherer" "📍" "Ground Truth" "context" 0 0 "$PROJECT_CONTEXT"
  fi

  json_append_entry "tuner" "Seed Tuner" "🌱" "Lens Selection" "tuning" 0 1 "$LENS_CONTEXT"
  TURN_COUNT=2
}
