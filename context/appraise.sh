#!/usr/bin/env bash
# ── Seed appraisal (lapidary composition) ──
# Assesses the raw material: what is it? What traditions does it sit within?
# What is the initial quality assessment?
# Expects globals: $SEED_TOPIC, $PROJECT_CONTEXT, $CONVERSATION,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON, $TURN_COUNT, $OUTPUT_DIR, $TIMESTAMP
# Depends on: lib/json.sh

appraise_seed() {
  start_spinner "🌱 Appraising the raw material"

  local appraise_prompt="You are preparing a creative thinking session that works through iterative refinement - cutting, polishing, and faceting raw material through repeated passes, each more precise than the last.

Given the seed topic below, appraise it as raw material. Do not solve it. ASSESS it.

Output EXACTLY this format, nothing else:

RAW MATERIAL: [What is this, really? Not what it says it is but what it actually is. Name the thing beneath the question. 2-3 sentences.]

TRADITIONS: [3-4 traditions, disciplines, or lineages this seed sits within, whether it knows it or not. Not keywords. Living traditions with centuries of accumulated intelligence. For each, one sentence on what that tradition would notice that others would miss.]

INITIAL WEIGHT: [An honest first assessment of quality. Is this a rich seam or a thin surface? Where is the density? Where is it thin? What would make this worth making well? 2-3 sentences.]

WHAT COULD BE REMOVED: [What is already unnecessary in how this seed is framed? What assumption, word, or framing is clutter rather than structure? What would sharpen it before the work even begins?]

${PROJECT_CONTEXT:+PROJECT CONTEXT (ground truth about the actual situation):
${PROJECT_CONTEXT}}

${GROUND_CONTEXT:+GROUND CHECK (what is stated vs inferred about this seed):
${GROUND_CONTEXT}}

${CORRECTIONS:+CORRECTIONS (treat these as ground truth - do not re-assume what has been corrected):
${CORRECTIONS}}

SEED TOPIC: ${SEED_TOPIC}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$appraise_prompt" > "$tmpfile"

  if claude_call "$tmpfile"; then
    APPRAISE_CONTEXT="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      stop_spinner "cap limit"
      return 1
    fi
    APPRAISE_CONTEXT="No appraisal context available. Agents should follow their own instincts."
  fi
  rm -f "$tmpfile"

  stop_spinner "done"
  echo ""

  CONVERSATION="The session begins with the seed topic: ${SEED_TOPIC}"

  if [ -n "$PROJECT_CONTEXT" ]; then
    CONVERSATION="${CONVERSATION}

PROJECT CONTEXT (ground truth about the actual project, business, or situation):
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

SEED APPRAISAL (raw material assessment, traditions, initial quality judgement - work with what resonates):
${APPRAISE_CONTEXT}"

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
