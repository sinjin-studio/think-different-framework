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

  local ground_prompt="You are a rigorous analyst preparing a creative thinking session. Your job is to separate what is actually known from what would be assumed - but surface only what matters most, not everything.

Given the seed topic (and any project context) below, classify into three categories. Be ruthless about the distinction between stated and inferred.

Use CONTINUOUS numbering across all sections (1-7). Output EXACTLY this format, nothing else:

STATED:
[Exactly 2 items, numbered 1-2. Quote or closely paraphrase only things explicitly said in the seed or project context. Cite the source - seed or context.]

INFERRED:
[Exactly 3 items, numbered 3-5. The 3 assumptions most likely to be wrong OR most consequential if wrong. For each, give 2-3 alternative realities that are equally plausible. Format: N. [assumption] -- Alternatives: a) ... b) ... c) ...]

UNKNOWN:
[Exactly 2 items, numbered 6-7. The 2 questions whose answers would most change the direction of thinking.]

Prioritise ruthlessly. The user will review these in under a minute. Surface only what would actually change the session if it were wrong.

${PROJECT_CONTEXT:+PROJECT CONTEXT:
${PROJECT_CONTEXT}}

SEED TOPIC: ${SEED_TOPIC}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$ground_prompt" > "$tmpfile"

  if claude_call "$tmpfile"; then
    GROUND_CONTEXT="$CLAUDE_RESPONSE"
  else
    GROUND_CONTEXT=""
    rm -f "$tmpfile"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      echo " cap limit reached"
      return 1
    fi
    echo " skipped (could not reach model)"
    return
  fi
  rm -f "$tmpfile"

  echo " done"
  echo ""

  # Display ground check
  echo "$GROUND_CONTEXT"
  echo ""

  # Write to transcript buffer
  md_append_section 3 "Ground Check"
  MD_BUFFER="${MD_BUFFER}
${GROUND_CONTEXT}
"

  # Write to JSON
  json_append_entry "ground" "Ground Check" "🔍" "Assumption Surfacing" "ground" 0 0 "$GROUND_CONTEXT"

  # Interactive review
  review_assumptions
}

review_assumptions() {
  if [ -z "$GROUND_CONTEXT" ]; then
    return
  fi

  echo "  Correct anything (number=correction), Enter when done:"

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

    # Append corrections to transcript buffer
    md_append_section 3 "Corrections"
    MD_BUFFER="${MD_BUFFER}
${CORRECTIONS}
"

    # Append corrections to JSON
    json_append_entry "ground" "Ground Check" "🔍" "Corrections" "corrections" 0 0 "$CORRECTIONS"
  fi
}
