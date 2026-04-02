#!/usr/bin/env bash
# ── Seed appraisal (lapidary composition) ──
# Assesses the raw material: what is it? What traditions does it sit within?
# What is the initial quality assessment?
# Grounding is embedded: surfaces and verifies assumptions before appraising.
# Expects globals: $SEED_TOPIC, $PROJECT_CONTEXT, $THINKING_SESSION,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON, $TURN_COUNT, $OUTPUT_DIR,
#                  $TIMESTAMP, $GROUND_ENABLED, $ALLOWED_TOOLS
# Depends on: lib/json.sh, context/ground.sh (for build_ground_preamble)

appraise_seed() {
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

Then appraise the seed."
  fi

  start_spinner "🌱 Appraising the raw material"

  local appraise_prompt="You are preparing a creative thinking session that works through iterative refinement - cutting, polishing, and faceting raw material through repeated passes, each more precise than the last.

${ground_section:+${ground_section}

}Given the seed topic below, appraise it as raw material. Do not solve it. ASSESS it.

Output EXACTLY this format, nothing else:

${ground_section:+ASSUMPTIONS: [3-4 assumptions about the problem/audience/situation, each marked VERIFIED or UNVERIFIED, with 2-3 alternative realities]

}RAW MATERIAL: [What is this, really? Not what it says it is but what it actually is. Name the thing beneath the question. 2-3 sentences.]

TRADITIONS: [3-4 traditions, disciplines, or lineages this seed sits within, whether it knows it or not. Not keywords. Living traditions with centuries of accumulated intelligence. For each, one sentence on what that tradition would notice that others would miss.]

INITIAL WEIGHT: [An honest first assessment of quality. Is this a rich seam or a thin surface? Where is the density? Where is it thin? What would make this worth making well? 2-3 sentences.]

WHAT COULD BE REMOVED: [What is already unnecessary in how this seed is framed? What assumption, word, or framing is clutter rather than structure? What would sharpen it before the work even begins?]

${PROJECT_CONTEXT:+PROJECT CONTEXT (ground truth about the actual situation):
${PROJECT_CONTEXT}}
${ZEITGEIST_CONTEXT:+
${ZEITGEIST_CONTEXT}}

SEED TOPIC: ${SEED_TOPIC}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$appraise_prompt" > "$tmpfile"

  VERBOSE_CALLER="seed:appraise"
  if claude_call "$tmpfile"; then
    APPRAISE_CONTEXT="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$RATE_LIMIT_HIT" = "true" ]; then
      stop_spinner "rate limit"
      return 1
    fi
    APPRAISE_CONTEXT="No appraisal context available. Lenses should follow their own instincts."
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

SEED APPRAISAL (raw material assessment, traditions, initial quality judgement - work with what resonates):
${APPRAISE_CONTEXT}"

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

  md_append_section 3 "Seed Appraisal"
  MD_BUFFER="${MD_BUFFER}
${APPRAISE_CONTEXT}
"

  if [ -n "$PROJECT_CONTEXT" ]; then
    json_append_entry "context" "Context Gatherer" "📍" "Ground Truth" "context" 0 0 "$PROJECT_CONTEXT"
  fi

  json_append_entry "appraiser" "Seed Appraisal" "🌱" "Raw Material Assessment" "appraise" 0 1 "$APPRAISE_CONTEXT"
  TURN_COUNT=2
}
