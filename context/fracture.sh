#!/usr/bin/env bash
# ── Seed fracturing (dyslexic composition) ──
# Breaks the seed into fragments, adjacencies, and entry points.
# Grounding is embedded: surfaces and verifies assumptions before fracturing.
# Expects globals: $SEED_TOPIC, $PROJECT_CONTEXT, $THINKING_SESSION,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON, $TURN_COUNT, $OUTPUT_DIR,
#                  $TIMESTAMP, $GROUND_ENABLED, $ALLOWED_TOOLS
# Depends on: lib/json.sh, context/ground.sh (for build_ground_preamble)

fracture_seed() {
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

Then fracture the seed."
  fi

  start_spinner "🌱 Fracturing the seed"

  local fracture_prompt="You are preparing a creative thinking session that works through dyslexic thinking, seeing differently, making unexpected connections, shifting scale.

${ground_section:+${ground_section}

}Given the seed topic below, break it apart. Do not analyse it. FRACTURE it.

Output EXACTLY this format, nothing else:

${ground_section:+ASSUMPTIONS: [3-4 assumptions about the problem/audience/situation, each marked VERIFIED or UNVERIFIED, with 2-3 alternative realities]

}FRAGMENTS: [4-5 individual words or short phrases pulled from the seed that could each be the entire problem if looked at from the right angle. Not keywords. Entry points.]

ADJACENT WORLDS: [3-4 completely unrelated domains, situations, or human experiences that FEEL like this problem even though they look nothing like it. Not analogies. Adjacencies. Things that sit next to this in some dimension nobody usually looks at.]

HUMAN MOMENT: [One very specific, concrete, sensory moment in the life of the person at the centre of this seed. Not abstract. A time of day, a physical sensation, a decision being made with hands and eyes, not just mind.]

WILDCARD: [Something that has no connection to the seed at all but might produce a collision worth having.]

${PROJECT_CONTEXT:+PROJECT CONTEXT (ground truth about the actual situation):
${PROJECT_CONTEXT}}
${ZEITGEIST_CONTEXT:+
${ZEITGEIST_CONTEXT}}

SEED TOPIC: ${SEED_TOPIC}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$fracture_prompt" > "$tmpfile"

  VERBOSE_CALLER="seed:fracture"
  if claude_call "$tmpfile"; then
    FRACTURE_CONTEXT="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$RATE_LIMIT_HIT" = "true" ]; then
      stop_spinner "rate limit"
      return 1
    fi
    FRACTURE_CONTEXT="No fracture context available. Lenses should follow their own instincts."
  fi
  rm -f "$tmpfile"

  stop_spinner "done"
  echo ""

  THINKING_SESSION="The session begins with the seed topic: ${SEED_TOPIC}"

  if [ -n "$PROJECT_CONTEXT" ]; then
    THINKING_SESSION="${THINKING_SESSION}

PROJECT CONTEXT (ground truth about the actual project, business, or situation):
${PROJECT_CONTEXT}"
  fi

  if [ -n "${SEED_VERIFICATION:-}" ]; then
    THINKING_SESSION="${THINKING_SESSION}

PROVOCATION VERIFICATION (claims checked, framing flagged - use corrected provocation as ground truth):
${SEED_VERIFICATION}"
  fi

  THINKING_SESSION="${THINKING_SESSION}

SEED FRACTURE (fragments, adjacencies, and entry points - use what pulls you, ignore what doesn't):
${FRACTURE_CONTEXT}"

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

  md_append_section 3 "Seed Fracture"
  MD_BUFFER="${MD_BUFFER}
${FRACTURE_CONTEXT}
"

  if [ -n "$PROJECT_CONTEXT" ]; then
    json_append_entry "context" "Context Gatherer" "📍" "Ground Truth" "context" 0 0 "$PROJECT_CONTEXT"
  fi

  json_append_entry "fracture" "Seed Fracture" "🌱" "Fragmentation" "fracture" 0 1 "$FRACTURE_CONTEXT"
  TURN_COUNT=2
}
