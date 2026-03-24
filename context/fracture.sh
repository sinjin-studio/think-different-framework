#!/usr/bin/env bash
# ── Seed fracturing (dyslexic composition) ──
# Breaks the seed into fragments, adjacencies, and entry points.
# Expects globals: $SEED_TOPIC, $PROJECT_CONTEXT, $CONVERSATION,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON, $TURN_COUNT, $OUTPUT_DIR, $TIMESTAMP
# Depends on: lib/json.sh

fracture_seed() {
  start_spinner "🌱 Fracturing the seed"

  local fracture_prompt="You are preparing a creative thinking session that works through dyslexic thinking, seeing differently, making unexpected connections, shifting scale.

Given the seed topic below, break it apart. Do not analyse it. FRACTURE it.

Output EXACTLY this format, nothing else:

FRAGMENTS: [4-5 individual words or short phrases pulled from the seed that could each be the entire problem if looked at from the right angle. Not keywords. Entry points.]

ADJACENT WORLDS: [3-4 completely unrelated domains, situations, or human experiences that FEEL like this problem even though they look nothing like it. Not analogies. Adjacencies. Things that sit next to this in some dimension nobody usually looks at.]

HUMAN MOMENT: [One very specific, concrete, sensory moment in the life of the person at the centre of this seed. Not abstract. A time of day, a physical sensation, a decision being made with hands and eyes, not just mind.]

WILDCARD: [Something that has no connection to the seed at all but might produce a collision worth having.]

${PROJECT_CONTEXT:+PROJECT CONTEXT (ground truth about the actual situation):
${PROJECT_CONTEXT}}

${GROUND_CONTEXT:+GROUND CHECK (what is stated vs inferred about this seed):
${GROUND_CONTEXT}}

${CORRECTIONS:+CORRECTIONS (treat these as ground truth - do not re-assume what has been corrected):
${CORRECTIONS}}

SEED TOPIC: ${SEED_TOPIC}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$fracture_prompt" > "$tmpfile"

  if claude_call "$tmpfile"; then
    FRACTURE_CONTEXT="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      stop_spinner "cap limit"
      return 1
    fi
    FRACTURE_CONTEXT="No fracture context available. Agents should follow their own instincts."
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

SEED FRACTURE (fragments, adjacencies, and entry points - use what pulls you, ignore what doesn't):
${FRACTURE_CONTEXT}"

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
