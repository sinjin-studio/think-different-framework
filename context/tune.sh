#!/usr/bin/env bash
# ── Seed tuning (spiral composition) ──
# Generates tensions, human realities, and wildcards for the seed.
# Expects globals: $SEED_TOPIC, $PROJECT_CONTEXT, $CONVERSATION,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON, $TURN_COUNT, $OUTPUT_DIR, $TIMESTAMP
# Depends on: lib/json.sh

tune_seed() {
  echo -n "  🌱 Tuning lenses to the seed..."

  local tuning_prompt="You are preparing a multi-agent brainstorming session. Given the seed topic below, suggest unexpected angles of approach.

Output EXACTLY this format, nothing else:

TENSIONS: [3-4 genuine tensions or contradictions embedded in the seed that are worth exploring. Frame each as a sharp question.]

HUMAN REALITY: [2-3 observations about the actual lived experience of the person or people at the centre of this seed. What do they feel? What do they want? What are they afraid of? Be specific and empathetic, not abstract.]

WILDCARD: [One completely orthogonal concept, phenomenon, or question that has no obvious connection to the seed but might produce the most interesting collision.]

${PROJECT_CONTEXT:+PROJECT CONTEXT (use this to ground your suggestions in the actual situation):
${PROJECT_CONTEXT}}

${GROUND_CONTEXT:+GROUND CHECK (what is stated vs inferred about this seed):
${GROUND_CONTEXT}}

${CORRECTIONS:+CORRECTIONS (treat these as ground truth - do not re-assume what has been corrected):
${CORRECTIONS}}

SEED TOPIC: ${SEED_TOPIC}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$tuning_prompt" > "$tmpfile"

  if claude_call "$tmpfile"; then
    LENS_CONTEXT="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      echo " cap limit reached"
      return 1
    fi
    LENS_CONTEXT="No lens context available. Agents should follow their own instincts."
  fi
  rm -f "$tmpfile"

  echo " done"
  echo ""

  CONVERSATION="The session begins with the seed topic: ${SEED_TOPIC}"

  if [ -n "$PROJECT_CONTEXT" ]; then
    CONVERSATION="${CONVERSATION}

PROJECT CONTEXT (ground truth about the actual project, business, or situation this seed relates to):
${PROJECT_CONTEXT}"
  fi

  if [ -n "$GROUND_CONTEXT" ]; then
    CONVERSATION="${CONVERSATION}

GROUND CHECK (what is stated vs inferred about this seed):
${GROUND_CONTEXT}"
  fi

  if [ -n "$CORRECTIONS" ]; then
    CONVERSATION="${CONVERSATION}

CORRECTIONS (ground truth - do not re-assume what has been corrected):
${CORRECTIONS}"
  fi

  CONVERSATION="${CONVERSATION}

LENS CONTEXT (optional starting points for the agents, not constraints):
${LENS_CONTEXT}"

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
