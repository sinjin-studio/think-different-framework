#!/usr/bin/env bash
# ── Provocation generation ──
# Distills raw input (brief, brand, notes, project context) into
# 3-5 seed provocations that drive separate thinking sessions.
# Expects globals: $PROJECT_CONTEXT (optional)
# Sets: $PROVOCATIONS (array)

generate_provocations() {
  local input_material="$1"
  local input_type="$2"  # "brief", "brand", "notes", "project"

  echo -n "  🔥 Generating provocations..."

  local context_block=""
  if [ -n "$PROJECT_CONTEXT" ]; then
    context_block="
PROJECT CONTEXT (ground truth about the actual situation):
${PROJECT_CONTEXT}"
  fi

  local provoke_prompt="You are a provocateur preparing a creative thinking session. You have been given some input material. Your job is to digest it and produce 3-5 SEED PROVOCATIONS.

Each provocation should be:
- Uncomfortable, not safe
- A statement or question that forces a position
- Grounded in the input material but pushing beyond it
- Something that would make a boardroom go quiet
- A 'what if...' that nobody wants to consider but should

Do NOT produce:
- Consulting-speak or safe strategic questions
- Obvious angles that any brief would generate
- Questions that invite agreement rather than friction

Format: Output ONLY the provocations, one per line, numbered 1-5. No preamble, no explanation, no meta-commentary. Each provocation should be a single sentence.

INPUT TYPE: ${input_type}

INPUT MATERIAL:
${input_material}
${context_block}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$provoke_prompt" > "$tmpfile"

  local raw_provocations
  raw_provocations=$(cat "$tmpfile" | claude -p 2>/dev/null) || {
    rm -f "$tmpfile"
    echo " failed"
    echo "  Warning: could not generate provocations. Using input as direct seed."
    PROVOCATIONS=()
    return 1
  }
  rm -f "$tmpfile"

  # Parse numbered lines into array (bash 3.2 compatible)
  PROVOCATIONS=()
  while IFS= read -r line; do
    # Strip leading number, period, and whitespace
    local cleaned
    cleaned=$(echo "$line" | sed 's/^[0-9]*\.\s*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [ -n "$cleaned" ]; then
      PROVOCATIONS+=("$cleaned")
    fi
  done <<< "$raw_provocations"

  echo " done (${#PROVOCATIONS[@]} provocations)"
  echo ""

  local i=1
  for prov in "${PROVOCATIONS[@]}"; do
    echo "  ${i}. ${prov}"
    i=$((i + 1))
  done
  echo ""
}

pick_provocations() {
  echo "  Select provocations to run (comma-separated, e.g. 1,3,5):"
  echo "  Or press Enter to run all."
  echo -n "  > "
  read -r selection

  if [ -z "$selection" ]; then
    return  # Keep all provocations
  fi

  local selected=()
  IFS=',' read -ra indices <<< "$selection"
  for idx in "${indices[@]}"; do
    idx=$(echo "$idx" | sed 's/[[:space:]]//g')
    local arr_idx=$((idx - 1))
    if [ "$arr_idx" -ge 0 ] && [ "$arr_idx" -lt "${#PROVOCATIONS[@]}" ]; then
      selected+=("${PROVOCATIONS[$arr_idx]}")
    fi
  done

  if [ "${#selected[@]}" -gt 0 ]; then
    PROVOCATIONS=("${selected[@]}")
    echo "  Running ${#PROVOCATIONS[@]} selected provocation(s)."
  else
    echo "  Invalid selection. Running all provocations."
  fi
  echo ""
}

read_input_material() {
  local input_type="$1"
  local input_value="$2"

  case "$input_type" in
    brief)
      if [ -f "$input_value" ]; then
        cat "$input_value"
      else
        echo "Error: brief file not found: $input_value" >&2
        return 1
      fi
      ;;
    brand)
      echo "Brand: ${input_value}. Research this brand. What do they stand for? Who are they for? What tensions exist in their positioning? What are they not saying?"
      ;;
    notes)
      echo "Working notes: ${input_value}"
      ;;
    seed)
      echo "Seed topic for creative thinking: ${input_value}. This is a direct starting point. Generate provocations that fracture, challenge, and reframe this seed from multiple uncomfortable angles."
      ;;
    project)
      echo "Project directory context. No specific seed provided. Generate provocations from the project context alone."
      ;;
  esac
}
