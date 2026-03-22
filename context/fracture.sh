#!/usr/bin/env bash
# ── Seed fracturing (dyslexic composition) ──
# Breaks the seed into fragments, adjacencies, and entry points.
# Expects globals: $SEED_TOPIC, $PROJECT_CONTEXT, $CONVERSATION,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON, $TURN_COUNT, $OUTPUT_DIR, $TIMESTAMP
# Depends on: lib/json.sh

fracture_seed() {
  echo -n "  🌱 Fracturing the seed..."

  local fracture_prompt="You are preparing a creative thinking session that works through dyslexic thinking, seeing differently, making unexpected connections, shifting scale.

Given the seed topic below, break it apart. Do not analyse it. FRACTURE it.

Output EXACTLY this format, nothing else:

FRAGMENTS: [4-5 individual words or short phrases pulled from the seed that could each be the entire problem if looked at from the right angle. Not keywords. Entry points.]

ADJACENT WORLDS: [3-4 completely unrelated domains, situations, or human experiences that FEEL like this problem even though they look nothing like it. Not analogies. Adjacencies. Things that sit next to this in some dimension nobody usually looks at.]

HUMAN MOMENT: [One very specific, concrete, sensory moment in the life of the person at the centre of this seed. Not abstract. A time of day, a physical sensation, a decision being made with hands and eyes, not just mind.]

WILDCARD: [Something that has no connection to the seed at all but might produce a collision worth having.]

${PROJECT_CONTEXT:+PROJECT CONTEXT (ground truth about the actual situation):
${PROJECT_CONTEXT}}

SEED TOPIC: ${SEED_TOPIC}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$fracture_prompt" > "$tmpfile"

  FRACTURE_CONTEXT=$(cat "$tmpfile" | claude -p 2>/dev/null) || {
    FRACTURE_CONTEXT="No fracture context available. Agents should follow their own instincts."
  }
  rm -f "$tmpfile"

  echo " done"
  echo ""

  CONVERSATION="The session begins with the seed topic: ${SEED_TOPIC}"

  if [ -n "$PROJECT_CONTEXT" ]; then
    CONVERSATION="${CONVERSATION}

PROJECT CONTEXT (ground truth about the actual project, business, or situation):
${PROJECT_CONTEXT}"
  fi

  CONVERSATION="${CONVERSATION}

SEED FRACTURE (fragments, adjacencies, and entry points - use what pulls you, ignore what doesn't):
${FRACTURE_CONTEXT}"

  if [ -n "$PROJECT_CONTEXT" ]; then
    echo "### Project Context" >> "$TRANSCRIPT_MD"
    echo "" >> "$TRANSCRIPT_MD"
    echo "${PROJECT_CONTEXT}" >> "$TRANSCRIPT_MD"
    echo "" >> "$TRANSCRIPT_MD"
  fi

  echo "### Seed Fracture" >> "$TRANSCRIPT_MD"
  echo "" >> "$TRANSCRIPT_MD"
  echo "${FRACTURE_CONTEXT}" >> "$TRANSCRIPT_MD"
  echo "" >> "$TRANSCRIPT_MD"

  if [ -n "$PROJECT_CONTEXT" ]; then
    json_append_entry "context" "Context Gatherer" "📍" "Ground Truth" "context" 0 0 "$PROJECT_CONTEXT"
  fi

  json_append_entry "fracture" "Seed Fracture" "🌱" "Fragmentation" "fracture" 0 1 "$FRACTURE_CONTEXT"
  TURN_COUNT=2
}
