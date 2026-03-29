#!/usr/bin/env bash
# ── Provocation generation ──
# Distills raw input (brief, brand, notes, project context) into
# seed provocations that drive separate thinking sessions.
# Expects globals: $SEED_COUNT (default 3), $PROJECT_CONTEXT (optional),
#                  $PROVOCATION_TONE (default "provocative"),
#                  $AUTONOMOUS_MODE, $RUNNER_UP_PROVOCATIONS (initialized)
# Sets: $PROVOCATIONS (array), $ZEITGEIST_SOURCES (array),
#       $RUNNER_UP_PROVOCATIONS (array, non-selected pool entries)

# ── Tone-specific prompt blocks ──

get_tone_prompt() {
  local tone="$1"
  case "$tone" in
    generous)
      cat <<'TONE'
Each provocation should be:
- Radically positive, not naive - find the hidden strength everyone is overlooking
- A reframe that makes existing effort look more powerful than anyone realized
- Grounded in the input material but revealing untapped potential within it
- Something that would make a cynical room pause and reconsider
- A 'what if this is actually working and we cannot see it yet?' angle

Do NOT produce:
- Flattery or empty encouragement
- Obvious positives that anyone would list as strengths
- Affirmations that avoid the hard question underneath
TONE
      ;;
    personal)
      cat <<'TONE'
Each provocation should be:
- Zoomed to one human, one moment, one sensory detail - the provocation lives in specificity, not abstraction
- A scene so concrete you can feel the texture of the moment
- Grounded in the input material but collapsed to a single person's experience of it
- Something that makes the room stop strategising and start feeling
- A 'picture this...' that turns a market into a human being

Do NOT produce:
- Broad empathy statements or persona-speak
- Demographic abstractions or anything that says 'consumers'
- Moments that could apply to any brand or any person
TONE
      ;;
    absurd)
      cat <<'TONE'
Each provocation should be:
- Surreal, lateral, alien - see this from a perspective no human would naturally take
- A what-if that breaks a fundamental assumption about how this domain works
- Grounded enough in the input material that it is not random, but strange enough to unlock new space
- Something that makes people laugh first and then go quiet as the implications land
- A reversal, inversion, scale-shift, or category error applied to the core problem

Do NOT produce:
- Random nonsense disconnected from the input material
- Jokes or cleverness for its own sake
- Surrealism that is entertaining but produces no cognitive friction
TONE
      ;;
    daydream)
      cat <<'TONE'
Each provocation should be:
- Loose, wandering, permission-giving - the kind of thought that arrives when you stop trying
- A 'what if we just...' that feels too simple or too free to say in a meeting
- Grounded in the input material but drifting past its edges into adjacent possibility
- Something that makes people exhale and say 'I mean... why not?'
- An unguarded speculation that trades rigour for openness

Do NOT produce:
- Structured strategic thinking or anything that sounds like a framework
- Provocations that try too hard or arrive too neatly
- Safe daydreams that lack real consequence or commitment
TONE
      ;;
    *)
      # provocative (default)
      cat <<'TONE'
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
TONE
      ;;
  esac
}

# Detect meta-commentary / process chatter that is not a real provocation
# Returns 0 (true) if the text is meta-commentary, 1 if it looks like a real provocation
is_meta_commentary() {
  local text="$1"

  # Starts with ERROR: or WARNING:
  case "$text" in
    ERROR:*|WARNING:*|"Error:"*|"Warning:"*) return 0 ;;
  esac

  # Known sign-off / apology / refusal patterns
  case "$text" in
    *"Thank you"*|*"Best of luck"*|*"Good luck"*|*"Hope this"*) return 0 ;;
    *"I apologize"*|*"I cannot"*|*"I'm sorry"*|*"I'm unable"*) return 0 ;;
    *"I am sorry"*|*"I am unable"*) return 0 ;;
  esac

  # Process meta-commentary patterns
  case "$text" in
    *"already delivered"*|*"already provided"*|*"already generated"*) return 0 ;;
    *"were already"*|*"no further action"*|*"No further action"*) return 0 ;;
    *"background tasks"*|*"research agent"*|*"foreground provided"*) return 0 ;;
    *GENERATION_FAILED*|*"No provocations"*|*"sign-off"*) return 0 ;;
    *"upstream step"*|*"Re-run"*|*"re-run"*|*"error message"*) return 0 ;;
    *"not a seed"*|*"not a provocation"*|*"meta-commentary"*) return 0 ;;
  esac

  # Talks ABOUT provocations rather than BEING one
  case "$text" in
    *"provocation"*"generated"*|*"provocation"*"delivered"*|*"provocation"*"provided"*) return 0 ;;
    *"provocations"*"generated"*|*"provocations"*"delivered"*|*"provocations"*"provided"*) return 0 ;;
    *"provocations were"*|*"provocation was"*) return 0 ;;
  esac

  # Multiple sentences (3+ periods) suggests explanation, not a single provocative sentence
  local period_count
  period_count=$(echo "$text" | tr -cd '.' | wc -c | tr -d ' ')
  if [ "$period_count" -ge 3 ]; then
    return 0
  fi

  return 1
}

generate_provocations() {
  local input_material="$1"
  local input_type="$2"  # "brief", "brand", "notes", "project"

  # Pool size: generate more provocations than SEED_COUNT, pick best later
  local pool_size=$(( SEED_COUNT * 3 ))
  if [ "$pool_size" -lt 3 ]; then pool_size=3; fi
  if [ "$pool_size" -gt 12 ]; then pool_size=12; fi

  # Progress emoji based on tone
  local tone_emoji="💣🌶️"
  local tone_label="${PROVOCATION_TONE:-provocative}"
  if [[ "$tone_label" == *","* ]]; then
    tone_emoji="🎲✨"
    tone_label="mixed"
  else
    case "$tone_label" in
      generous) tone_emoji="🌷🎁" ;;
      personal) tone_emoji="🤲🫀" ;;
      absurd)   tone_emoji="🦞📞" ;;
      daydream) tone_emoji="☁️💭" ;;
    esac
  fi
  start_spinner "${tone_emoji} Generating provocations (${tone_label})"

  local context_block=""
  if [ -n "$PROJECT_CONTEXT" ]; then
    context_block="
PROJECT CONTEXT (ground truth about the actual situation):
${PROJECT_CONTEXT}"
  fi

  local audience_block=""
  if [ -n "${AUDIENCE_TEXT:-}" ]; then
    audience_block="

THE AUDIENCE: ${AUDIENCE_TEXT}
Provocations should challenge how to reach, move, or transform this audience. Do not produce provocations that are only interesting to strategists - produce provocations that matter to these people."
  fi

  local research_preamble=""
  case "${ALLOWED_TOOLS:-}" in
    *WebSearch*|*WebFetch*)
      research_preamble="You have access to web search. Before generating provocations, search for current information about this ${input_type} - recent news, positioning, controversies, and cultural context. Use what you find to make provocations sharper and grounded in current reality.

"
      ;;
  esac

  local provoke_prompt=""

  # Check if multi-tone (comma-separated)
  if [[ "${PROVOCATION_TONE:-provocative}" == *","* ]]; then
    # Multi-tone: assign a specific tone to each seed via round-robin
    local tones_csv="${PROVOCATION_TONE}"
    local tone_arr=()
    IFS=',' read -ra tone_arr <<< "$tones_csv"
    local tone_count=${#tone_arr[@]}

    local tone_assignments=""
    local i
    for (( i=1; i<=pool_size; i++ )); do
      local tone_idx=$(( (i - 1) % tone_count ))
      local assigned_tone="${tone_arr[$tone_idx]}"
      local assigned_block
      assigned_block=$(get_tone_prompt "$assigned_tone")
      tone_assignments="${tone_assignments}
PROVOCATION ${i} - use a ${assigned_tone} tone:
${assigned_block}
"
    done

    provoke_prompt="${research_preamble}You are a provocateur preparing a creative thinking session. You have been given some input material. Your job is to digest it and produce exactly ${pool_size} SEED PROVOCATIONS, each in a DIFFERENT TONE as specified below. We will select the strongest ${SEED_COUNT} later, so generate a full pool of ${pool_size}.

${tone_assignments}

Format: Output ONLY the provocations, one per line, numbered 1-${pool_size}. No preamble, no explanation, no meta-commentary. Each provocation should be a single sentence. Do NOT label the tones in your output. Do NOT output error messages, apologies, or sign-off statements. If you struggle with the input, generate provocations anyway - use whatever angle you can find.

INPUT TYPE: ${input_type}

INPUT MATERIAL:
${input_material}
${context_block}${audience_block}"

  else
    # Single tone: all seeds get the same tone
    local tone_block
    tone_block=$(get_tone_prompt "${PROVOCATION_TONE:-provocative}")

    provoke_prompt="${research_preamble}You are a provocateur preparing a creative thinking session. You have been given some input material. Your job is to digest it and produce exactly ${pool_size} SEED PROVOCATIONS. We will select the strongest ${SEED_COUNT} later, so generate a full pool of ${pool_size}.

${tone_block}

Format: Output ONLY the provocations, one per line, numbered 1-${pool_size}. No preamble, no explanation, no meta-commentary. Each provocation should be a single sentence. Do NOT output error messages, apologies, or sign-off statements. If you struggle with the input, generate provocations anyway - use whatever angle you can find.

INPUT TYPE: ${input_type}

INPUT MATERIAL:
${input_material}
${context_block}${audience_block}"
  fi

  local tmpfile
  tmpfile=$(mktemp)
  echo "$provoke_prompt" > "$tmpfile"

  local raw_provocations
  VERBOSE_CALLER="provoke"
  if claude_call "$tmpfile"; then
    raw_provocations="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      stop_spinner "cap limit"
      PROVOCATIONS=()
      return 1
    fi
    stop_spinner "failed"
    echo "  Warning: could not generate provocations."
    PROVOCATIONS=()
    return 1
  fi
  rm -f "$tmpfile"

  # Parse numbered lines into array, separating sources from provocations (bash 3.2 compatible)
  PROVOCATIONS=()
  ZEITGEIST_SOURCES=()
  while IFS= read -r line; do
    # Strip leading number, period, and whitespace
    local cleaned
    cleaned=$(echo "$line" | sed 's/^[0-9]*\.\s*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [ -z "$cleaned" ]; then
      continue
    fi
    # Detect source/reference lines - capture rather than discard
    case "$cleaned" in
      "Sources:"*|"Sources"*|"References:"*|"References"*)
        continue ;;
      "- ["*|"* ["*)
        ZEITGEIST_SOURCES+=("$cleaned") ;;
      "http://"*|"https://"*)
        ZEITGEIST_SOURCES+=("$cleaned") ;;
      "- http://"*|"- https://"*)
        ZEITGEIST_SOURCES+=("$cleaned") ;;
      *)
        PROVOCATIONS+=("$cleaned") ;;
    esac
  done <<< "$raw_provocations"

  # Safety net: clamp to pool size if Claude over-generated
  if [ ${#PROVOCATIONS[@]} -gt ${pool_size} ]; then
    PROVOCATIONS=("${PROVOCATIONS[@]:0:${pool_size}}")
  fi

  # Detect meta-commentary / sign-off / error responses instead of real provocations
  if [ ${#PROVOCATIONS[@]} -gt 0 ]; then
    local clean_provs=()
    local had_meta="false"
    for prov in "${PROVOCATIONS[@]}"; do
      if is_meta_commentary "$prov"; then
        had_meta="true"
      else
        clean_provs+=("$prov")
      fi
    done
    if [ "$had_meta" = "true" ]; then
      echo "  ⚠ Provocation generation returned meta-commentary, filtering..." >&2
      PROVOCATIONS=("${clean_provs[@]+"${clean_provs[@]}"}")
    fi
  fi

  # Retry once with reinforced prompt if we got no usable provocations
  if [ ${#PROVOCATIONS[@]} -eq 0 ]; then
    local retry_prompt="CRITICAL: You must output exactly ${pool_size} numbered provocations. No meta-commentary, no error messages, no apologies, no sign-off statements. Just the provocations, one per line, numbered.

${provoke_prompt}"
    local retry_tmp
    retry_tmp=$(mktemp)
    echo "$retry_prompt" > "$retry_tmp"
    VERBOSE_CALLER="provoke:retry"
    if claude_call "$retry_tmp"; then
      while IFS= read -r line; do
        local cleaned
        cleaned=$(echo "$line" | sed 's/^[0-9]*\.\s*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        if [ -z "$cleaned" ]; then
          continue
        fi
        case "$cleaned" in
          "Sources:"*|"Sources"*|"References:"*|"References"*)
            continue ;;
          "- ["*|"* ["*)
            ZEITGEIST_SOURCES+=("$cleaned") ;;
          "http://"*|"https://"*)
            ZEITGEIST_SOURCES+=("$cleaned") ;;
          "- http://"*|"- https://"*)
            ZEITGEIST_SOURCES+=("$cleaned") ;;
          *)
            PROVOCATIONS+=("$cleaned") ;;
        esac
      done <<< "$CLAUDE_RESPONSE"
      if [ ${#PROVOCATIONS[@]} -gt ${pool_size} ]; then
        PROVOCATIONS=("${PROVOCATIONS[@]:0:${pool_size}}")
      fi
    fi
    rm -f "$retry_tmp"

    # Filter meta-commentary from retry results too
    if [ ${#PROVOCATIONS[@]} -gt 0 ]; then
      local retry_clean=()
      for prov in "${PROVOCATIONS[@]}"; do
        if ! is_meta_commentary "$prov"; then
          retry_clean+=("$prov")
        fi
      done
      PROVOCATIONS=("${retry_clean[@]+"${retry_clean[@]}"}")
    fi
  fi

  # Bail out if we still have no usable provocations after all retries
  if [ ${#PROVOCATIONS[@]} -eq 0 ]; then
    stop_spinner "failed (no usable provocations after retry)"
    echo "  ✗ Provocation generation failed - Claude returned meta-commentary instead of provocations." >&2
    echo "  Try running again, or use a direct seed: ./think.sh \"your topic here\"" >&2
    return 1
  fi

  stop_spinner "done (${#PROVOCATIONS[@]} provocations, ${#ZEITGEIST_SOURCES[@]} sources captured)"
  echo ""

  local i=1
  for prov in "${PROVOCATIONS[@]}"; do
    echo "  ${i}. ${prov}"
    i=$((i + 1))
  done
  echo ""

  if [ ${#ZEITGEIST_SOURCES[@]} -gt 0 ]; then
    echo "  📰 Known territory (${#ZEITGEIST_SOURCES[@]} sources captured):"
    for src in "${ZEITGEIST_SOURCES[@]}"; do
      echo "     ${src}"
    done
    echo ""
  fi
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

# ── Provocation review gate ──
# Reviews generated provocations for distinctness and new territory.
# Merges similar ones, reframes weak ones. Only runs when multiple provocations exist.
review_provocations() {
  [ "${#PROVOCATIONS[@]}" -le 1 ] && return
  [ "${AUTONOMOUS_MODE:-}" != "true" ] && return

  start_spinner "🔍 Reviewing provocations for distinctness"

  local prov_list=""
  local i=1
  for prov in "${PROVOCATIONS[@]}"; do
    prov_list="${prov_list}
${i}. ${prov}"
    i=$((i + 1))
  done

  local review_prompt="You are reviewing seed provocations for a creative thinking session. Each provocation will drive a separate thinking session. For the sessions to produce genuinely different output, the provocations must open genuinely different territory.

Review these provocations:
${prov_list}

For each provocation, assess:
- DISTINCTNESS: Does this provocation open territory the others cannot reach? Different angles on familiar ground is not enough - each should explore new territory.
- TENSION POTENTIAL: Does it contain a genuine tension that lenses can work with, or is it flat?
- CONVENTIONAL OVERLAP: Would two or more of these provocations lead to the same conventional answer?

Respond with a JSON object."

  local json_schema='{"type":"object","properties":{"provocations":{"type":"array","items":{"type":"object","properties":{"index":{"type":"integer"},"verdict":{"type":"string","enum":["keep","merge","reframe"]},"reason":{"type":"string"},"reframed":{"type":"string"}},"required":["index","verdict","reason"]}}},"required":["provocations"]}'

  local tmpfile
  tmpfile=$(mktemp)
  echo "$review_prompt" > "$tmpfile"

  VERBOSE_CALLER="provoke:review"
  if claude_call_json "$tmpfile" "$json_schema"; then
    local review_json="$CLAUDE_RESPONSE"

    # Process the review decisions
    local new_provocations=()
    local merged_indices=""

    # Use python to process the JSON and produce shell-safe output
    eval "$(echo "$review_json" | python3 -c "
import sys, json, shlex

d = json.load(sys.stdin)
provs = d.get('provocations', [])
merge_targets = set()
reframes = {}

for p in provs:
    idx = p.get('index', 0)
    verdict = p.get('verdict', 'keep')
    if verdict == 'merge':
        merge_targets.add(idx)
    elif verdict == 'reframe':
        reframed = p.get('reframed', '')
        if reframed:
            reframes[idx] = reframed

print('MERGE_INDICES=' + shlex.quote(','.join(str(i) for i in sorted(merge_targets))))
for idx, text in reframes.items():
    print(f'REFRAME_{idx}=' + shlex.quote(text))
" 2>/dev/null || echo "")"

    # Rebuild provocations array
    local new_provs=()
    i=1
    for prov in "${PROVOCATIONS[@]}"; do
      local skip="false"
      # Check if merged
      if [[ ",$MERGE_INDICES," == *",$i,"* ]]; then
        skip="true"
        echo "  ⊘ Provocation ${i} merged (too similar)"
      fi

      if [ "$skip" = "false" ]; then
        # Check if reframed
        local reframe_var="REFRAME_${i}"
        local reframed="${!reframe_var:-}"
        if [ -n "$reframed" ]; then
          echo "  ↻ Provocation ${i} reframed for new territory"
          new_provs+=("$reframed")
        else
          new_provs+=("$prov")
        fi
      fi
      i=$((i + 1))
    done

    if [ "${#new_provs[@]}" -gt 0 ]; then
      PROVOCATIONS=("${new_provs[@]}")
    fi
  fi

  rm -f "$tmpfile"
  stop_spinner "done (${#PROVOCATIONS[@]} provocations after review)"

  if [ "${#PROVOCATIONS[@]}" -gt 0 ]; then
    echo ""
    i=1
    for prov in "${PROVOCATIONS[@]}"; do
      echo "  ${i}. ${prov}"
      i=$((i + 1))
    done
    echo ""
  fi
}

# ── Provocation quality prosecution ──
# Prosecutes each provocation for genuine quality (not just distinctness).
# A provocation that's unusual phrasing of a common question wastes a session.
prosecute_provocations() {
  [ "${#PROVOCATIONS[@]}" -eq 0 ] && return
  [ "${AUTONOMOUS_MODE:-}" != "true" ] && return

  start_spinner "⚖️  Prosecuting provocations for quality"

  local prov_list=""
  local i=1
  for prov in "${PROVOCATIONS[@]}"; do
    prov_list="${prov_list}
${i}. ${prov}"
    i=$((i + 1))
  done

  local prose_prompt="You are prosecuting seed provocations for a creative thinking session. A provocation must force genuine divergent thinking, not just ask an unusual question.

For each provocation, test:
1. NOVELTY: Is this genuinely provocative, or is it unusual phrasing of a question any strategist would ask?
2. TENSION: Does it contain a real tension that forces a position, or is it open-ended enough to invite safe answers?
3. ACTIONABILITY: Could creative lenses actually grip this and produce thinking, or is it too abstract?

PROVOCATIONS:
${prov_list}

For each, respond: keep (genuinely provocative) or sharpen (rephrase to add real teeth).
If sharpening, provide a rewritten provocation that forces a specific, uncomfortable position."

  local json_schema='{"type":"object","properties":{"provocations":{"type":"array","items":{"type":"object","properties":{"index":{"type":"integer"},"verdict":{"type":"string","enum":["keep","sharpen"]},"sharpened":{"type":"string"},"reason":{"type":"string"}},"required":["index","verdict","reason"]}}},"required":["provocations"]}'

  local tmpfile
  tmpfile=$(mktemp)
  echo "$prose_prompt" > "$tmpfile"

  VERBOSE_CALLER="provoke:prosecute"
  if claude_call_json "$tmpfile" "$json_schema"; then
    local prose_json="$CLAUDE_RESPONSE"

    # Process sharpening decisions
    eval "$(echo "$prose_json" | python3 -c "
import sys, json, shlex

d = json.load(sys.stdin)
provs = d.get('provocations', [])

for p in provs:
    idx = p.get('index', 0)
    verdict = p.get('verdict', 'keep')
    if verdict == 'sharpen':
        sharpened = p.get('sharpened', '')
        if sharpened:
            print(f'SHARPEN_{idx}=' + shlex.quote(sharpened))
" 2>/dev/null || echo "")"

    # Apply sharpened provocations
    local new_provs=()
    i=1
    for prov in "${PROVOCATIONS[@]}"; do
      local sharpen_var="SHARPEN_${i}"
      local sharpened="${!sharpen_var:-}"
      if [ -n "$sharpened" ]; then
        echo "  ⚡ Provocation ${i} sharpened" >&2
        new_provs+=("$sharpened")
      else
        new_provs+=("$prov")
      fi
      i=$((i + 1))
    done

    if [ "${#new_provs[@]}" -gt 0 ]; then
      PROVOCATIONS=("${new_provs[@]}")
    fi

    # Post-prosecution validation: prosecution can "sharpen" into error messages
    local valid_provs=()
    for prov in "${PROVOCATIONS[@]}"; do
      if is_meta_commentary "$prov"; then
        echo "  ⚠ Prosecution produced meta-commentary, dropping" >&2
      else
        valid_provs+=("$prov")
      fi
    done
    PROVOCATIONS=("${valid_provs[@]+"${valid_provs[@]}"}")
  fi

  rm -f "$tmpfile"
  stop_spinner "done"
}

# ── Provocation selection ──
# When the pool has more provocations than SEED_COUNT, rank and pick the best.
# Stores non-selected provocations in RUNNER_UP_PROVOCATIONS for the presentation.
select_provocations() {
  [ "${#PROVOCATIONS[@]}" -le ${SEED_COUNT} ] && return
  [ "${AUTONOMOUS_MODE:-}" != "true" ] && return

  start_spinner "🎯 Selecting top ${SEED_COUNT} from ${#PROVOCATIONS[@]} provocations"

  local prov_list=""
  local i=1
  for prov in "${PROVOCATIONS[@]}"; do
    prov_list="${prov_list}
${i}. ${prov}"
    i=$((i + 1))
  done

  local select_prompt="You are selecting the strongest seed provocations for a creative thinking session. Each selected provocation will drive a separate full thinking session.

From this pool, select the TOP ${SEED_COUNT} provocations. Rank by:
1. TENSION: Which provocations contain the sharpest, most uncomfortable tension?
2. TERRITORY: Which open the most distinct, non-overlapping territory?
3. GRIP: Which give creative lenses the most to work with?

POOL:
${prov_list}

Return the indices of the ${SEED_COUNT} strongest provocations, ranked best-first."

  local json_schema='{"type":"object","properties":{"selected":{"type":"array","items":{"type":"integer"},"description":"Indices of selected provocations, ranked best-first"},"reasoning":{"type":"string","description":"Brief reasoning for selection"}},"required":["selected","reasoning"]}'

  local tmpfile
  tmpfile=$(mktemp)
  echo "$select_prompt" > "$tmpfile"

  VERBOSE_CALLER="provoke:select"
  if claude_call_json "$tmpfile" "$json_schema"; then
    local select_json="$CLAUDE_RESPONSE"

    # Parse selected indices
    local selected_indices=""
    selected_indices=$(echo "$select_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
selected = d.get('selected', [])
print(','.join(str(i) for i in selected))
" 2>/dev/null || echo "")

    if [ -n "$selected_indices" ]; then
      local new_selected=()
      local new_runners=()
      i=1
      for prov in "${PROVOCATIONS[@]}"; do
        if [[ ",$selected_indices," == *",$i,"* ]]; then
          new_selected+=("$prov")
        else
          new_runners+=("$prov")
        fi
        i=$((i + 1))
      done

      if [ "${#new_selected[@]}" -gt 0 ]; then
        PROVOCATIONS=("${new_selected[@]}")
        RUNNER_UP_PROVOCATIONS=("${new_runners[@]+"${new_runners[@]}"}")
      fi
    fi
  fi

  rm -f "$tmpfile"
  stop_spinner "done (${#PROVOCATIONS[@]} selected, ${#RUNNER_UP_PROVOCATIONS[@]} runner-ups)"

  echo ""
  i=1
  for prov in "${PROVOCATIONS[@]}"; do
    echo "  ✓ ${i}. ${prov}"
    i=$((i + 1))
  done
  if [ ${#RUNNER_UP_PROVOCATIONS[@]} -gt 0 ]; then
    echo ""
    echo "  Runner-ups (stored for presentation):"
    for prov in "${RUNNER_UP_PROVOCATIONS[@]}"; do
      echo "    ○ ${prov}"
    done
  fi
  echo ""
}

read_input_material() {
  local input_type="$1"
  local input_value="$2"
  local tone="${PROVOCATION_TONE:-provocative}"
  local is_multi="false"
  if [[ "$tone" == *","* ]]; then
    is_multi="true"
  fi

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
      local brand_suffix=""
      if [ "$is_multi" = "true" ]; then
        brand_suffix="What is their positioning, and what are the most interesting angles on it?"
      else
        case "$tone" in
          generous)
            brand_suffix="What hidden strengths exist in their positioning? What are they doing right that nobody is talking about?"
            ;;
          personal)
            brand_suffix="What does it feel like to encounter this brand in a specific moment? What is one person's real experience of it?"
            ;;
          absurd)
            brand_suffix="What would be the strangest possible lens through which to see this brand?"
            ;;
          daydream)
            brand_suffix="If this brand could become anything at all, with no constraints, what might it drift toward?"
            ;;
          *)
            brand_suffix="What tensions exist in their positioning? What are they not saying?"
            ;;
        esac
      fi
      echo "Brand: ${input_value}. Research this brand. What do they stand for? Who are they for? ${brand_suffix}"
      ;;
    notes)
      echo "Working notes: ${input_value}"
      ;;
    seed)
      local seed_suffix=""
      if [ "$is_multi" = "true" ]; then
        seed_suffix="Generate provocations that approach this seed from contrasting angles."
      else
        case "$tone" in
          generous)
            seed_suffix="Generate provocations that find hidden potential, amplify overlooked strengths, and reframe this seed from radically positive angles."
            ;;
          personal)
            seed_suffix="Generate provocations that collapse this seed into specific human moments - one person, one scene, one feeling."
            ;;
          absurd)
            seed_suffix="Generate provocations that warp, invert, and defamiliarize this seed from surreal and lateral angles."
            ;;
          daydream)
            seed_suffix="Let this seed drift - follow it loosely, see where it wanders without forcing a destination."
            ;;
          *)
            seed_suffix="Generate provocations that fracture, challenge, and reframe this seed from multiple uncomfortable angles."
            ;;
        esac
      fi
      echo "Seed topic for creative thinking: ${input_value}. This is a direct starting point. ${seed_suffix}"
      ;;
    project)
      echo "Project directory context. No specific seed provided. Generate provocations from the project context alone."
      ;;
  esac
}
