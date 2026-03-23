#!/usr/bin/env bash
# ── Seed grounding ──
# Surfaces assumptions BEFORE the session begins.
# Classifies seed content as STATED, INFERRED, or UNKNOWN.
# Interactive review lets the user correct wrong assumptions.
# Corrections become ground truth for all agents.
#
# Expects globals: $SEED_TOPIC, $PROJECT_CONTEXT, $CONVERSATION,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON, $TURN_COUNT,
#                  $GROUND_ENABLED
# Sets: $GROUND_CONTEXT, $CORRECTIONS
# Depends on: lib/json.sh

ground_seed() {
  GROUND_CONTEXT=""
  CORRECTIONS=""

  if [ "$GROUND_ENABLED" != "true" ]; then
    return
  fi

  echo -n "  🔍 Grounding the seed..."

  local ground_prompt="You are a rigorous analyst preparing a creative thinking session. Your job is to separate what is actually known from what would be assumed.

Given the seed topic (and any project context) below, classify EVERYTHING into three categories. Be ruthless about the distinction between what was actually said and what you are filling in.

Output EXACTLY this format, nothing else:

STATED:
[Quote or closely paraphrase only things explicitly said in the seed or project context. Number each item. Cite the source - seed or context.]

INFERRED:
[Things an AI would naturally assume but that were NOT explicitly stated. Number each item. For each, give 2-3 alternative realities that are equally plausible given only what was stated. Format: N. [assumption] -- Alternatives: a) ... b) ... c) ...]

UNKNOWN:
[Questions a good interviewer would ask before proceeding. Things that would change the direction of thinking depending on the answer. Number each item.]

Be thorough. Most seeds contain more inferences than people realise. The goal is to catch wrong assumptions before they contaminate a multi-agent session where every agent builds on what came before.

${PROJECT_CONTEXT:+PROJECT CONTEXT:
${PROJECT_CONTEXT}}

SEED TOPIC: ${SEED_TOPIC}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$ground_prompt" > "$tmpfile"

  GROUND_CONTEXT=$(cat "$tmpfile" | claude -p 2>/dev/null) || {
    GROUND_CONTEXT=""
    rm -f "$tmpfile"
    echo " skipped (could not reach model)"
    return
  }
  rm -f "$tmpfile"

  echo " done"
  echo ""

  # Display ground check
  echo "$GROUND_CONTEXT"
  echo ""

  # Write to transcript
  echo "### Ground Check" >> "$TRANSCRIPT_MD"
  echo "" >> "$TRANSCRIPT_MD"
  echo "${GROUND_CONTEXT}" >> "$TRANSCRIPT_MD"
  echo "" >> "$TRANSCRIPT_MD"

  # Write to JSON
  json_append_entry "ground" "Ground Check" "🔍" "Assumption Surfacing" "ground" 0 0 "$GROUND_CONTEXT"

  # Interactive review
  review_assumptions
}

review_assumptions() {
  # Extract INFERRED section for display
  local inferred_section
  inferred_section=$(echo "$GROUND_CONTEXT" | sed -n '/^INFERRED:/,/^UNKNOWN:/p' | sed '$d' | sed '1d')

  if [ -z "$inferred_section" ]; then
    return
  fi

  echo "  Correct any assumptions (number=correction), Enter when done:"

  CORRECTIONS=""
  while true; do
    echo -n "  > "
    read -r input

    # Empty input means done
    if [ -z "$input" ]; then
      break
    fi

    # Parse number=correction format
    local num correction
    num="${input%%=*}"
    correction="${input#*=}"

    if [ "$num" = "$input" ]; then
      echo "  Format: number=correction (e.g. 1=Actually it works like this)"
      continue
    fi

    # Trim whitespace (bash 3.2 compatible)
    num=$(echo "$num" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    correction=$(echo "$correction" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    if [ -n "$num" ] && [ -n "$correction" ]; then
      if [ -n "$CORRECTIONS" ]; then
        CORRECTIONS="${CORRECTIONS}
${num}. CORRECTED: ${correction}"
      else
        CORRECTIONS="${num}. CORRECTED: ${correction}"
      fi
      echo "  ✓ Correction ${num} recorded"
    fi
  done

  if [ -n "$CORRECTIONS" ]; then
    echo ""
    echo "  Corrections applied:"
    echo "$CORRECTIONS" | while IFS= read -r line; do
      echo "    ${line}"
    done
    echo ""

    # Append corrections to transcript
    echo "### Corrections" >> "$TRANSCRIPT_MD"
    echo "" >> "$TRANSCRIPT_MD"
    echo "${CORRECTIONS}" >> "$TRANSCRIPT_MD"
    echo "" >> "$TRANSCRIPT_MD"

    # Append corrections to JSON
    json_append_entry "ground" "Ground Check" "🔍" "Corrections" "corrections" 0 0 "$CORRECTIONS"
  fi
}
