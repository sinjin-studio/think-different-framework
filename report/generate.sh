#!/usr/bin/env bash
# ── Presentation generation ──
# Converts a single transcript into a structured presentation.
# Supports multiple output types: insight, brief, manifesto.
# Generates "The Line" - punchy rallying lines that work across strategy, creative, and branding.
# Expects: claude CLI available, OUTPUT_TYPE set

# ── Shared style rules applied to all prompts ──
STYLE_RULES='Style rules:
- Do not use em dashes. Use hyphens, commas, or full stops instead
- Do not use bullet points, numbered lists, or headers with markdown formatting
- Do not use the words "genuinely", "honestly", "straightforward", "nuanced", "multifaceted", "paradigm", "ecosystem", "holistic", "stakeholder", or "leverage" (as verb)
- Do not use "landscape", "framework", or "space" as metaphors
- Do not use "sacred", "prayer", "altar", "pilgrimage", "devotion", or "worship" as metaphors for non-religious subjects. Find secular language for the same intensity
- No emojis
- Write in paragraphs, not lists
- Short paragraphs. Two to four sentences each. If a paragraph exceeds four sentences, split it. This is not a suggestion. White space is your friend
- Sentences should vary in length. Short ones hit harder after long ones
- If a paragraph could appear in any strategy deck for any client, delete it and try again'

# ── Default practitioner pool ──
DEFAULT_PRACTITIONERS="Paul Arden,Dave Trott,Bill Bernbach,John Hegarty,David Abbott,George Lois,Rory Sutherland,Mary Wells Lawrence"

# ── Pick 3 random practitioners from a pool (bash 3.2 compatible) ──
pick_practitioners() {
  local pool="$1"
  local count="${2:-3}"
  local result=""

  # Split pool into array
  local IFS=','
  local items=()
  for item in $pool; do
    items+=("$(echo "$item" | sed 's/^ *//;s/ *$//')")
  done

  # If pool has 3 or fewer, use all of them
  if [ ${#items[@]} -le "$count" ]; then
    local first="true"
    for item in "${items[@]}"; do
      if [ "$first" = "true" ]; then
        result="$item"
        first="false"
      else
        result="${result}, ${item}"
      fi
    done
    echo "$result"
    return
  fi

  # Fisher-Yates shuffle (partial, pick count items)
  local len=${#items[@]}
  local i=0
  while [ "$i" -lt "$count" ]; do
    local j=$(( (RANDOM * 32768 + RANDOM) % (len - i) + i ))
    # Swap items[i] and items[j]
    local tmp="${items[$i]}"
    items[$i]="${items[$j]}"
    items[$j]="$tmp"
    i=$((i + 1))
  done

  # Build result from first 'count' items
  local first="true"
  i=0
  while [ "$i" -lt "$count" ]; do
    if [ "$first" = "true" ]; then
      result="${items[$i]}"
      first="false"
    else
      result="${result}, ${items[$i]}"
    fi
    i=$((i + 1))
  done

  echo "$result"
}

# ── Allocate word budget across sections ──
# Sets BUDGET_BRIEF, BUDGET_MANIFESTO, BUDGET_INSIGHT globals
# Also updates ACTIVE_TYPES to reflect which sections survive the budget
allocate_budget() {
  local words="$1"
  local output_type="$2"

  # Parse range format ("500-800" -> midpoint)
  local total=0
  case "$words" in
    *-*)
      local low="${words%%-*}"
      local high="${words##*-}"
      total=$(( (low + high) / 2 ))
      ;;
    *)
      total="$words"
      ;;
  esac

  # Count which types are requested
  local has_brief="" has_manifesto="" has_insight=""
  local IFS=','
  for t in $output_type; do
    case "$t" in
      brief) has_brief="true" ;;
      manifesto) has_manifesto="true" ;;
      insight) has_insight="true" ;;
    esac
  done
  IFS=$' \t\n'

  BUDGET_BRIEF=0
  BUDGET_MANIFESTO=0
  BUDGET_INSIGHT=0
  BUDGET_EXPERIMENT=0
  ACTIVE_TYPES=""

  # If user explicitly set --type, respect all their choices
  if [ "${TYPE_EXPLICIT:-}" = "true" ]; then
    local type_count=0
    [ -n "$has_brief" ] && type_count=$((type_count + 1))
    [ -n "$has_manifesto" ] && type_count=$((type_count + 1))
    [ -n "$has_insight" ] && type_count=$((type_count + 1))

    if [ "$type_count" -eq 1 ]; then
      [ -n "$has_brief" ] && BUDGET_BRIEF=$total
      [ -n "$has_manifesto" ] && BUDGET_MANIFESTO=$total
      [ -n "$has_insight" ] && BUDGET_INSIGHT=$total
    elif [ "$type_count" -eq 2 ]; then
      if [ -n "$has_brief" ] && [ -n "$has_insight" ]; then
        BUDGET_BRIEF=$((total * 45 / 100))
        BUDGET_INSIGHT=$((total * 55 / 100))
      elif [ -n "$has_brief" ] && [ -n "$has_manifesto" ]; then
        BUDGET_BRIEF=$((total * 65 / 100))
        BUDGET_MANIFESTO=$((total * 35 / 100))
      else
        BUDGET_MANIFESTO=$((total * 35 / 100))
        BUDGET_INSIGHT=$((total * 65 / 100))
      fi
    else
      # All three requested (experiment always gets 10%, taken from insight)
      if [ "$total" -gt 1000 ]; then
        BUDGET_EXPERIMENT=$((total * 10 / 100))
        BUDGET_BRIEF=$((total * 35 / 100))
        BUDGET_MANIFESTO=$((total * 20 / 100))
        BUDGET_INSIGHT=$((total * 35 / 100))
      else
        BUDGET_EXPERIMENT=$((total * 10 / 100))
        BUDGET_BRIEF=$((total * 40 / 100))
        BUDGET_MANIFESTO=$((total * 25 / 100))
        BUDGET_INSIGHT=$((total * 25 / 100))
      fi
    fi

    # Warn if any section budget is thin
    local min_budget=150
    if { [ -n "$has_brief" ] && [ "$BUDGET_BRIEF" -lt "$min_budget" ]; } || \
       { [ -n "$has_manifesto" ] && [ "$BUDGET_MANIFESTO" -lt "$min_budget" ]; } || \
       { [ -n "$has_insight" ] && [ "$BUDGET_INSIGHT" -lt "$min_budget" ]; }; then
      echo "  Warning: ${total} words across ${type_count} types may produce thin output" >&2
    fi

    ACTIVE_TYPES="$output_type"
    return
  fi

  # Default: auto-drop sections at low budgets
  if [ "$total" -lt 300 ]; then
    # Brief only
    BUDGET_BRIEF=$total
    ACTIVE_TYPES="brief"
    echo "  Budget (${total}w): brief only" >&2
  elif [ "$total" -lt 600 ]; then
    # Brief + experiment
    BUDGET_EXPERIMENT=$((total * 20 / 100))
    BUDGET_BRIEF=$((total * 80 / 100))
    ACTIVE_TYPES="brief"
    echo "  Budget (${total}w): experiment + brief (insight, manifesto dropped)" >&2
  elif [ "$total" -le 1000 ]; then
    # All sections, balanced for medium
    BUDGET_EXPERIMENT=$((total * 10 / 100))
    BUDGET_BRIEF=$((total * 40 / 100))
    BUDGET_MANIFESTO=$((total * 25 / 100))
    BUDGET_INSIGHT=$((total * 25 / 100))
    ACTIVE_TYPES="brief,manifesto,insight"
  else
    # All sections, insight gets more room for long form
    BUDGET_EXPERIMENT=$((total * 10 / 100))
    BUDGET_BRIEF=$((total * 35 / 100))
    BUDGET_MANIFESTO=$((total * 20 / 100))
    BUDGET_INSIGHT=$((total * 35 / 100))
    ACTIVE_TYPES="brief,manifesto,insight"
  fi
}

# ── Distil session findings ──
# Extracts the most novel findings from the conversation, ranked by divergence.
distil_session_findings() {
  local conversation_text="$1"
  local seed="$2"

read -r -d '' DISTIL_SYSTEM << 'DISTILSYS' || true
You are extracting findings, not summarizing. A finding is something the session discovered that was not in the original seed and would not be obvious to a senior strategist working alone on this topic.

Read the full conversation. Identify the 5-7 most novel findings. Rank them by how far they diverge from conventional thinking on this subject.

For each finding, write 2-3 sentences: name the specific mechanism or insight, and explain why it is novel (what would a strategist miss without this session?).

Format as a numbered list. No preamble, no summary paragraph. Just the findings.

Do not reward beautiful writing. Reward surprising, specific, usable ideas. If a finding could apply to any brand or topic, it is not specific enough.
DISTILSYS

  local distil_prompt="Here is a full thinking session transcript on the topic: ${seed}

Extract the most novel findings. What did this session discover that was not in the seed and would not be obvious to a senior strategist?

TRANSCRIPT:
${conversation_text}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$distil_prompt" > "$tmpfile"

  local result=""
  VERBOSE_CALLER="report:distil"
  if claude_call_no_cap "$tmpfile" "$DISTIL_SYSTEM"; then
    result="$CLAUDE_RESPONSE"
  fi
  rm -f "$tmpfile"

  echo "$result"
}

# ── Generate creative asset description ──
# A sensory/spatial/tactile description of an asset that embodies the insight.
generate_asset() {
  local distillation="$1"
  local winning_line="$2"
  local seed="$3"
  local conversation_text="$4"

read -r -d '' ASSET_SYSTEM << 'ASSETSYS' || true
You describe a single creative asset that embodies an insight. Not an ad concept. A thing someone could make.

The asset can be any medium: a photograph, a short film, a sound piece, an installation, a physical object, a performance, a piece of music, a garment, a space. Choose whichever medium carries this specific insight best.

Describe it as if someone needs to make it tomorrow. Be specific about:
- Medium and format (e.g. "60-second film, single fixed camera, no edit")
- Materials, textures, sensory qualities
- Duration or dimensions
- What the viewer/listener/participant experiences
- What is deliberately absent
- Artistic style reference (e.g. "shot in the style of Rinko Kawauchi", "rendered as a maquette", "illustrated in risograph")

The description must be producible as described. If a photograph, a photographer could take it. If a film, a director could shoot it. If an installation, a fabricator could build it. Do not rely on impossible physics, abstract metaphors a camera cannot capture, or visual paradoxes that only work as sentences. If the description would produce poor results as an AI image generation prompt, simplify until it would succeed.

Stay within 100-150 words. No preamble. No explanation of why. Just describe the thing.

This is for minds that think in space rather than sequence. The description should make someone see it, hear it, or feel it before they understand it.
ASSETSYS

  local asset_prompt="THE LINE: ${winning_line}

TOPIC: ${seed}

SESSION'S MOST NOVEL FINDINGS:
${distillation}

Describe one creative asset that embodies the deepest finding from this session. Choose the medium that carries this insight best."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$asset_prompt" > "$tmpfile"

  local result=""
  VERBOSE_CALLER="report:asset"
  if claude_call_no_cap "$tmpfile" "$ASSET_SYSTEM"; then
    result="$CLAUDE_RESPONSE"
  fi
  rm -f "$tmpfile"

  echo "$result"
}

# ── Generate The Line ──
# Rallying lines distilled from the session.
generate_the_line() {
  local conversation_text="$1"
  local seed="$2"
  local line_count="${3:-3}"
  local distillation="${4:-}"

  # Progress messaging moved to generate_presentation caller
  # to avoid leaking into $() capture

  # Pick practitioners
  local pool="${LINE_PRACTITIONERS:-$DEFAULT_PRACTITIONERS}"
  local practitioners
  practitioners=$(pick_practitioners "$pool" 3)

  local line_count_instruction=""
  if [ "$line_count" -eq 1 ]; then
    line_count_instruction="Output exactly 1 angle. Format:

PLATFORM: [the strategic truth]
EXPRESSION: [the audience-facing line]

Nothing else."
  else
    line_count_instruction="Output exactly ${line_count} angles, numbered. Format for each:

[N]
PLATFORM: [the strategic truth]
EXPRESSION: [the audience-facing line]

Each angle is a different facet of the same core insight. Nothing else."
  fi

  local audience_line_block=""
  if [ -n "${AUDIENCE_TEXT:-}" ]; then
    audience_line_block="
The audience is: ${AUDIENCE_TEXT}.

The Platform should open territory that matters to these people. The Expression should land in their mouth - something they would say, share, or feel."
  fi

read -r -d '' LINE_SYSTEM << LINESYS || true
You distil thinking into two altitudes. Strategic territory and its sharpest expression. The expression may well become a slogan - that is fine, as long as it carries depth and genuine meaning, not shallow aspiration.

You will receive research notes from a deep thinking session. Your job is to find the core insight and render it at two altitudes.
${audience_line_block}

ALTITUDE 1 - THE PLATFORM
A generative strategic truth. The kind of line you can make decisions against, brief campaigns from, and build products on. A platform opens territory. You can brief campaigns from it, build products on it, make decisions against it. If it merely describes a quality ("Empowering creativity"), it closes territory instead of opening it. The best platforms enter culture - they get quoted by people who never saw the brief.

A good platform:
- Opens more doors than it closes
- Makes some things obviously right and others obviously wrong
- Could anchor a brand for a decade, not just a campaign
- Is specific to THIS insight - if you could swap in another brand, it is too generic
- Sounds like a belief, not a benefit

ALTITUDE 2 - THE EXPRESSION
The audience-facing punch. Shorter, sharper, more visceral. If the platform names the tension, the expression resolves it in the fewest possible words. The best expressions escape the campaign and become language - the kind of line people say to themselves before doing the hard thing. The expression must SERVE the platform, not replace it.

A good expression:
- Could be said by a real person in conversation
- Carries an emotion, not just an idea
- Works on a wall, in a headline, or whispered to yourself before doing the hard thing
- Is rhythmically tight - syllable count matters, every word earns its place
- Speaks outward to the world, not inward to the brief. It should read like something that exists on a wall, in a headline, or in someone's mouth - not like a line from a strategy deck addressing a stakeholder

What NOT to do:
- No "In a world where..." framing
- No questions
- No colons or semicolons
- No em dashes
- Nothing that sounds like a TED talk title
- Nothing that sounds like a consulting framework
- Nothing generic enough to apply to any topic
- Nothing that reflects on the process of creating it
- Nothing that reads like a strategist addressing a client. The expression lives in the world, not in the deck
- Do not explain the lines. Just deliver them

Write at the altitude of ${practitioners}. Not in their style. At their standard.

${line_count_instruction}
LINESYS

  local distil_block=""
  if [ -n "$distillation" ]; then
    distil_block="SESSION'S MOST NOVEL FINDINGS (ranked by divergence):
${distillation}

---

"
  fi

  local line_prompt="${AUDIENCE_TEXT:+Audience: ${AUDIENCE_TEXT}

}${distil_block}Here are research notes from a thinking session on: ${seed}

Find the core insight. Render it at two altitudes: the strategic platform (generative truth you can build on) and the expression (audience-facing punch). Prioritise the deepest, most novel findings - not the most repeated or accessible ones.

RESEARCH NOTES:
${conversation_text}

---

Write the lines. Platform first, then expression. Each angle should carry the insight forward on its own."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$line_prompt" > "$tmpfile"

  local the_lines=""
  VERBOSE_CALLER="report:generate"
  if claude_call_no_cap "$tmpfile" "$LINE_SYSTEM"; then
    the_lines="$CLAUDE_RESPONSE"
  else
    echo "    ! The Line generation failed (exit=${LAST_CLAUDE_EXIT_CODE})" >&2
    [ -n "$LAST_CLAUDE_ERROR" ] && echo "    ! stderr: $(echo "$LAST_CLAUDE_ERROR" | head -c 200)" >&2
  fi
  rm -f "$tmpfile"

  echo "$the_lines"
}

# ── Pick the strongest expression from multiple angles ──
pick_strongest_line() {
  local the_lines="$1"

  # Count angles
  local count
  count=$(echo "$the_lines" | grep -c '^EXPRESSION:' || true)

  # Single line or none - return first expression directly
  if [ "$count" -le 1 ]; then
    echo "$the_lines" | grep -m 1 '^EXPRESSION:' | sed 's/^EXPRESSION:[[:space:]]*//'
    return
  fi

  # Multiple lines - ask Claude to pick the strongest
  local pick_prompt="You are judging creative lines. Below are ${count} angles, each with a PLATFORM and EXPRESSION.

Pick the single strongest EXPRESSION - the one with the most tension, specificity, and memorability. Respond with ONLY the number (e.g. 1, 2, or 3). Nothing else.

${the_lines}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$pick_prompt" > "$tmpfile"

  local pick=""
  VERBOSE_CALLER="report:pick_line"
  if claude_call_no_cap "$tmpfile"; then
    pick=$(echo "$CLAUDE_RESPONSE" | tr -dc '0-9' | head -c 1)
  fi
  rm -f "$tmpfile"

  # Extract the picked expression (fall back to 1 if parse fails)
  [ -z "$pick" ] && pick="1"
  local winner
  winner=$(echo "$the_lines" | grep '^EXPRESSION:' | sed -n "${pick}p" | sed 's/^EXPRESSION:[[:space:]]*//')
  [ -z "$winner" ] && winner=$(echo "$the_lines" | grep -m 1 '^EXPRESSION:' | sed 's/^EXPRESSION:[[:space:]]*//')

  echo "$winner"
}

# ── Prosecute the winning line and iterate if weak ──
# Takes the winning PLATFORM+EXPRESSION pair and tests it adversarially.
# If weak, generates improved alternatives and re-judges. Max 2 iterations.
prosecute_line() {
  local winning_platform="$1"
  local winning_expression="$2"
  local seed="$3"
  local distillation="${4:-}"
  local the_lines="${5:-}"

  local max_iterations=2
  local iteration=0
  local current_platform="$winning_platform"
  local current_expression="$winning_expression"

  local prosecution_schema='{"type":"object","properties":{"verdict":{"type":"string","enum":["strong","weak"]},"briefable":{"type":"string"},"cold_readable":{"type":"string"},"specific":{"type":"string"},"weaknesses":{"type":"array","items":{"type":"string"}}},"required":["verdict","briefable","cold_readable","specific"]}'

  while [ "$iteration" -lt "$max_iterations" ]; do
    # Step 1: Prosecute
    local prose_prompt="You are judging a strategic platform and its expression. Be ruthless.

PLATFORM: ${current_platform}
EXPRESSION: ${current_expression}
TOPIC: ${seed}

Test each against three criteria:
1. BRIEFABLE: Could a creative team brief work from this platform without a 2000-word explainer? Does it open territory (generative) or just describe a quality (closed)?
2. COLD-READABLE: If someone read the expression on a wall with zero context, would it land? Would they feel something? Would they say it to themselves?
3. SPECIFICITY: Could you swap in another brand/topic and the line still works? If yes, it is too generic.

If all three pass, verdict is strong. If any fail, verdict is weak with specific weaknesses."

    local tmpfile
    tmpfile=$(mktemp)
    echo "$prose_prompt" > "$tmpfile"

    VERBOSE_CALLER="report:prosecute_line"
    local prose_result=""
    if claude_call_json "$tmpfile" "$prosecution_schema" ""; then
      prose_result="$CLAUDE_RESPONSE"
    fi
    rm -f "$tmpfile"

    if [ -z "$prose_result" ]; then
      break  # Prosecution failed, keep current
    fi

    # Check verdict
    local verdict
    verdict=$(echo "$prose_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('verdict','strong'))" 2>/dev/null || echo "strong")

    if [ "$verdict" = "strong" ]; then
      echo "    ✓ Line passed prosecution (iteration $((iteration + 1)))" >&2
      break
    fi

    echo "    ⚡ Line prosecution: weak (iteration $((iteration + 1))), generating alternatives..." >&2

    # Extract weaknesses
    local weaknesses
    weaknesses=$(echo "$prose_result" | python3 -c "import sys,json; ws=json.load(sys.stdin).get('weaknesses',[]); print(chr(10).join(f'- {w}' for w in ws))" 2>/dev/null || echo "- Needs improvement")

    # Step 2: Generate improved alternatives
    local distil_block=""
    if [ -n "$distillation" ]; then
      distil_block="SESSION'S MOST NOVEL FINDINGS:
${distillation}

---

"
    fi

    local improve_prompt="${distil_block}A strategic line was prosecuted and found wanting. Improve it.

ORIGINAL PLATFORM: ${current_platform}
ORIGINAL EXPRESSION: ${current_expression}
TOPIC: ${seed}

PROSECUTION FINDINGS:
${weaknesses}

Generate 2 improved alternatives. Each must fix the identified weaknesses while keeping the core insight. Format:

[1]
PLATFORM: [the strategic truth - must be briefable without explanation]
EXPRESSION: [the audience-facing line - must work cold on a wall]

[2]
PLATFORM: [different angle on the same insight]
EXPRESSION: [different expression]

Nothing else."

    tmpfile=$(mktemp)
    echo "$improve_prompt" > "$tmpfile"

    local alternatives=""
    VERBOSE_CALLER="report:improve_line"
    if claude_call_no_cap "$tmpfile" ""; then
      alternatives="$CLAUDE_RESPONSE"
    fi
    rm -f "$tmpfile"

    if [ -z "$alternatives" ]; then
      break  # Improvement failed, keep current
    fi

    # Step 3: Re-judge between original and alternatives
    local judge_prompt="Pick the single strongest Platform+Expression pair. Consider: briefability (can a team build from it?), cold-readability (lands on a wall with no context?), and specificity (only works for this topic?).

[ORIGINAL]
PLATFORM: ${current_platform}
EXPRESSION: ${current_expression}

${alternatives}

Respond with ONLY the label: ORIGINAL, 1, or 2. Nothing else."

    tmpfile=$(mktemp)
    echo "$judge_prompt" > "$tmpfile"

    local pick=""
    VERBOSE_CALLER="report:judge_line"
    if claude_call_no_cap "$tmpfile" ""; then
      pick=$(echo "$CLAUDE_RESPONSE" | tr -d '[:space:]')
    fi
    rm -f "$tmpfile"

    # Extract the chosen pair
    if [ "$pick" = "1" ] || [ "$pick" = "2" ]; then
      local new_platform new_expression
      new_platform=$(echo "$alternatives" | awk -v n="$pick" '/^\[/ { block_num++ } block_num==n && /^PLATFORM:/ { sub(/^PLATFORM:[[:space:]]*/, ""); print; exit }')
      new_expression=$(echo "$alternatives" | awk -v n="$pick" '/^\[/ { block_num++ } block_num==n && /^EXPRESSION:/ { sub(/^EXPRESSION:[[:space:]]*/, ""); print; exit }')
      if [ -n "$new_platform" ] && [ -n "$new_expression" ]; then
        current_platform="$new_platform"
        current_expression="$new_expression"
        echo "    ↻ Line improved: picked alternative ${pick}" >&2
      fi
    else
      echo "    ✓ Original line retained after alternatives" >&2
    fi

    iteration=$((iteration + 1))
  done

  # Return platform and expression separated by a marker
  echo "PLATFORM: ${current_platform}"
  echo "EXPRESSION: ${current_expression}"
}

# ── Generate experiment (standalone section with hypothesis + success signal) ──
generate_experiment() {
  local conversation_text="$1"
  local seed="$2"
  local words="$3"
  local the_lines="${4:-}"
  local distillation="${5:-}"

  local low=$((words - words / 10))
  local high=$((words + words / 10))

read -r -d '' EXPERIMENT_SYSTEM << EXPERIMENTSYS || true
You are a strategist distilling a creative thinking session into one concrete experiment. Not a strategy. Not a campaign. One thing someone could start tomorrow. Consider the full scope of the subject, not just the narrow angle the seed touched. If the seed explored one facet of a larger topic, the experiment should reflect the deeper truth, not the narrowest interpretation.

CRITICAL: Write as if you arrived at this yourself. No references to sessions, lenses, transcripts, or any process. You sat with this problem and you know what to try.

${STYLE_RULES}

Structure (no section headers, just flow):

1. A hypothesis line: "We believe [X] because [Y]." One sentence. What you think will happen and why.

2. The experiment itself: the smallest brave thing you could do tomorrow. Specific enough to act on, wild enough to be worth doing. 2-4 sentences. Be concrete - name the channel, the format, the audience, the gesture. Not a roadmap, not a phased plan. One thing.

3. A success signal: "You would know it is working if [Z]." One sentence. What you would observe, not a KPI. A human signal, not a dashboard metric.

Stay within ${low}-${high} words. The whole thing should fit on a postcard.
EXPERIMENTSYS

  local dedup_block=""
  if [ -n "$the_lines" ]; then
    dedup_block="
THE LINE(S) (already written - do not repeat these phrases):
${the_lines}

---

"
  fi

  local distil_block=""
  if [ -n "$distillation" ]; then
    distil_block="SESSION'S MOST NOVEL FINDINGS:
${distillation}

---

"
  fi

  local experiment_prompt="${distil_block}Here are research notes on the following topic. Distil them into one concrete experiment worth trying. Prioritise the deepest findings.

TOPIC: ${seed}

RESEARCH NOTES:
${conversation_text}

---
${dedup_block}
Write the experiment. Hypothesis, the thing to try, success signal. No headers."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$experiment_prompt" > "$tmpfile"

  local result=""
  VERBOSE_CALLER="report:generate"
  if claude_call_no_cap "$tmpfile" "$EXPERIMENT_SYSTEM"; then
    result="$CLAUDE_RESPONSE"
  else
    local err_detail=""
    [ -n "$LAST_CLAUDE_ERROR" ] && err_detail=" $(echo "$LAST_CLAUDE_ERROR" | head -c 200)"
    result="[Experiment generation failed (exit=${LAST_CLAUDE_EXIT_CODE}).${err_detail} The transcript is available for manual review.]"
  fi
  rm -f "$tmpfile"

  echo "$result"
}

# ── Generate insight article ──
generate_insight() {
  local conversation_text="$1"
  local seed="$2"
  local words="$3"
  local prior_sections="${4:-}"
  local distillation="${5:-}"

  local length_guidance=""
  case "$words" in
    *-*)
      length_guidance="Total length: ${words} words. Every word must earn its place."
      ;;
    *)
      local low=$((words - words / 10))
      local high=$((words + words / 10))
      length_guidance="Stay within ${low}-${high} words. Use the space to develop arguments fully, but do not pad. Every paragraph must earn its place."
      ;;
  esac

  local provocation_guide="2-3 sentences."
  local landscape_guide="3-5 sentences."
  local insight_guide="4-6 sentences."
  local tension_guide="2-4 sentences."

  local numeric_words="${words%%-*}"
  if [ "$numeric_words" -gt 1200 ] 2>/dev/null; then
    provocation_guide="3-5 sentences. Take time to set up the stakes."
    landscape_guide="5-8 sentences. What did you actually notice? Not a literature review."
    insight_guide="6-10 sentences. Develop the argument fully. Use examples or analogies."
    tension_guide="4-6 sentences. What keeps you up at night about this idea?"
  fi
  if [ "$numeric_words" -gt 2000 ] 2>/dev/null; then
    provocation_guide="4-6 sentences. Build the case for why this question matters now."
    landscape_guide="8-12 sentences. Tell the story of what you found. Let the reader feel the turns."
    insight_guide="10-15 sentences. This is the centrepiece. Develop it like a short essay section."
    tension_guide="6-10 sentences. Give the counter-position real weight. Make it uncomfortable."
  fi

read -r -d '' INSIGHT_SYSTEM << INSIGHTSYS || true
You are a writer turning research notes into a short, original article. Your job is the ANALYTICAL dimension. Go where a brief cannot - into history, cultural theory, uncomfortable questions, systemic tensions. Do not describe the audience or write proof points. That is the brief's job. You are here to say something the brief cannot.

CRITICAL: You are writing as someone who HAD the insight, not someone who WATCHED a process generate it. The reader must never know these ideas came from a multi-lens session. No references to "the session", "the conversation", "the lenses", "the transcript", "the thinking", "the exploration", or any language that describes a process of discovery. Write as if you sat with this question for a long time and arrived at something worth sharing.

Do not be self-reflective about the act of thinking. Just deliver the ideas themselves.
${AUDIENCE_TEXT:+
The audience for this work is: ${AUDIENCE_TEXT}. Write for someone who needs to understand what matters to this audience and why. Illuminate something about these people, not just the topic in the abstract.}

Write in first person. You have been in the room, not the lecture hall. You write like you talk to smart people over drinks, not like you are defending a thesis. No corporate language, no filler, no hedging.

${STYLE_RULES}

Structure the article with these sections, using a single bold line as the section label:

**The Provocation**
Sharpen the question. Why does this matter? What is at stake? ${provocation_guide}

**The Landscape**
What did you actually notice? Map the territory as your own train of thought, not a survey of the field. ${landscape_guide}

**The Insight**
The core discovery. Say it plainly. If you need a parenthetical to explain what you mean, you have not said it plainly enough. Frame it as an argument, not an observation. The best insights feel both surprising and obvious. ${insight_guide}

**The Tension**
The honest objection. What keeps you up at night about this idea? Present it as something you wrestled with yourself. ${tension_guide}

After the four sections, add:

**Sources and Threads**
Distinguish between established knowledge and your own analogical leaps. For real sources (published thinkers, named research, historical precedents), write "I drew on [source]." For your own cross-domain connections or original analogies, write "I found a useful frame in [concept] - [what it illuminated]." Do not present original synthesis at the same epistemic weight as published work.

After the six text sections, include a single SVG diagram that visualises the insight journey or key relationships. This diagram appears in the HTML presentation and will be animated.

SVG rules:
- Output raw <svg> markup (no markdown fencing, no wrapping HTML)
- Use viewBox attribute, no fixed width/height
- Colours: only #169B62 (green, for nodes/accents), #FF8200 (orange, for highlights), #e8e8e8 (light text), #999999 (secondary), #181818 (background fills)
- Font: font-family="Literata, Georgia, serif"
- Add class="diagram-node" on clickable shapes (circles, rects), class="diagram-edge" on connecting lines/paths, class="diagram-label" on text elements
- Add data-node-id="unique-id" on each node, data-from="id" data-to="id" on each edge, data-label-for="id" on labels
- Keep the diagram under 5KB total
- Diagram type: a journey/flow showing Provocation -> Landscape -> Insight -> Tension as connected nodes, with the core insight node visually emphasised
- Short labels only (2-4 words per node, extracted from your actual content)
- No decorative elements - clean, minimal, functional
- Circle text fitting: min radius 55 for text nodes. Each text line must be 10 chars or fewer; if a label needs more, increase the radius (add 6px per extra char) before abbreviating
- Font-size inside circles: r=55 max 11, r=65 max 13, r=80 max 16. Never exceed radius x 0.2
- Two text lines max per circle: primary label (larger, light) and optional subtitle (smaller, dimmer)
- Layout consistency: all circles at the same hierarchy level must share the same radius. Size the largest label first, then apply that radius to its siblings

${length_guidance}
INSIGHTSYS

  local dedup_block=""
  if [ -n "$prior_sections" ]; then
    dedup_block="
ALREADY USED - DO NOT REPEAT:
The following sections have already been written. Scan them for specific images, characters, scenes, phrases, and arguments.

HARD RULE: Do not repeat any phrase of three or more words from prior sections. Do not reuse any specific metaphor, example, character, or scene. Do not make the same argument with different words. Find completely different evidence from the transcript for the same underlying point. Your article must add genuinely new territory - cultural implications, historical parallels, systemic tensions the other sections could not reach.

${prior_sections}

---

"
  fi

  local distil_block=""
  if [ -n "$distillation" ]; then
    distil_block="SESSION'S MOST NOVEL FINDINGS:
${distillation}

---

"
  fi

  local insight_prompt="${distil_block}Here are research notes on the following topic. Read them and write an original article based on the best ideas within. Write as if the ideas are your own. Prioritise the deepest, most novel findings.

TOPIC: ${seed}

RESEARCH NOTES:
${conversation_text}

---
${dedup_block}
Write the article. ${length_guidance} Four sections plus sources. First person voice. No lists, no filler. No meta-commentary about the research process."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$insight_prompt" > "$tmpfile"

  local result=""
  VERBOSE_CALLER="report:generate"
  if claude_call_no_cap "$tmpfile" "$INSIGHT_SYSTEM"; then
    result="$CLAUDE_RESPONSE"
  else
    local err_detail=""
    [ -n "$LAST_CLAUDE_ERROR" ] && err_detail=" $(echo "$LAST_CLAUDE_ERROR" | head -c 200)"
    result="[Insight generation failed (exit=${LAST_CLAUDE_EXIT_CODE}).${err_detail} The transcript is available for manual review.]"
  fi
  rm -f "$tmpfile"

  echo "$result"
}

# ── Generate creative brief ──
generate_brief() {
  local conversation_text="$1"
  local seed="$2"
  local words="$3"
  local distillation="${4:-}"

  local numeric_words="${words%%-*}"
  local low=$((numeric_words - numeric_words / 10))
  local high=$((numeric_words + numeric_words / 10))
  local length_guidance="Stay within ${low}-${high} words. A brief that runs long is not a brief."
  if [ "$numeric_words" -gt 1200 ] 2>/dev/null; then
    length_guidance="Stay within ${low}-${high} words. You have room to develop each section. Use it, but stay sharp."
  fi

read -r -d '' BRIEF_SYSTEM << BRIEFSYS || true
You are a strategist writing a creative brief. Not a deck. Not a document. A brief. Your job is the ACTIONABLE dimension. Who to reach, what to say, why it's true, and how to execute. Stay in the world of the brief - what a creative team needs to do their job. Leave the cultural analysis and theory for elsewhere.

CRITICAL: Write as if you arrived at these conclusions yourself. No references to sessions, lenses, transcripts, or any process. You spent time with this problem and you know what needs to happen.
${AUDIENCE_TEXT:+
The target audience is: ${AUDIENCE_TEXT}. Ground everything in reaching them. The Audience section should start from this and go deeper.}

A good brief is a weapon. It gives a creative team everything they need and nothing they do not.

${STYLE_RULES}

Structure with these sections, using a single bold line as the section label:

**The Audience**
Who are we talking to? Not demographics. Psychographics. What do they believe? What are they afraid of? What do they want but will not say out loud? Be specific enough that a creative could picture a single person.

**The Territory**
Where does this brand or idea live in culture? What conversations is it adjacent to? What tensions exist in this space? Map the cultural context, not the competitive landscape.

**The Proposition**
Exactly one sentence. If you wrote two, delete the weaker one. The single most compelling thing we can say. The strategic truth that everything else hangs from.

**Proof Points**
Why should anyone believe the proposition? What evidence, behaviour, or cultural signal supports it? Three to five concrete proof points, written as short declarative paragraphs.

**The Mandatories**
What must be true of any execution? Tone, channels, constraints, non-negotiables. Be prescriptive where it matters, open where creativity needs room.

After the five text sections, include a single SVG diagram that visualises the relationship between the audience and the territory - what connects them, what tensions exist, what the proposition resolves. This diagram appears in the HTML presentation and will be animated.

SVG rules:
- Output raw <svg> markup (no markdown fencing, no wrapping HTML)
- Use viewBox attribute, no fixed width/height
- Colours: only #169B62 (green, for nodes/accents), #FF8200 (orange, for highlights), #e8e8e8 (light text), #999999 (secondary), #181818 (background fills)
- Font: font-family="Literata, Georgia, serif"
- Add class="diagram-node" on clickable shapes, class="diagram-edge" on connecting lines/paths, class="diagram-label" on text elements
- Add data-node-id="unique-id" on each node, data-from="id" data-to="id" on each edge, data-label-for="id" on labels
- Keep the diagram under 5KB total
- Diagram type: show the audience and the territory as two poles, with the proposition as the bridge or resolution between them. Use labels drawn from your actual content, not the section names. The proposition node should be visually emphasised (larger, orange)
- Short labels only (2-4 words per node, extracted from your actual content)
- No decorative elements - clean, minimal, functional
- Circle text fitting: min radius 55 for text nodes. Each text line must be 10 chars or fewer; if a label needs more, increase the radius (add 6px per extra char) before abbreviating
- Font-size inside circles: r=55 max 11, r=65 max 13, r=80 max 16. Never exceed radius x 0.2
- Two text lines max per circle: primary label (larger, light) and optional subtitle (smaller, dimmer)
- Layout consistency: all circles at the same hierarchy level must share the same radius. Size the largest label first, then apply that radius to its siblings

${length_guidance}
BRIEFSYS

  local distil_block=""
  if [ -n "$distillation" ]; then
    distil_block="SESSION'S MOST NOVEL FINDINGS:
${distillation}

---

"
  fi

  local brief_prompt="${distil_block}Here are research notes on the following topic. Distill them into a creative brief. Ground the brief in the deepest findings.

TOPIC: ${seed}

RESEARCH NOTES:
${conversation_text}

---

Write the brief. Be direct. Every word earns its place."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$brief_prompt" > "$tmpfile"

  local result=""
  VERBOSE_CALLER="report:generate"
  if claude_call_no_cap "$tmpfile" "$BRIEF_SYSTEM"; then
    result="$CLAUDE_RESPONSE"
  else
    local err_detail=""
    [ -n "$LAST_CLAUDE_ERROR" ] && err_detail=" $(echo "$LAST_CLAUDE_ERROR" | head -c 200)"
    result="[Brief generation failed (exit=${LAST_CLAUDE_EXIT_CODE}).${err_detail} The transcript is available for manual review.]"
  fi
  rm -f "$tmpfile"

  echo "$result"
}

# ── Generate manifesto ──
generate_manifesto() {
  local conversation_text="$1"
  local seed="$2"
  local the_line="$3"
  local words="${4:-400}"
  local prior_sections="${5:-}"
  local distillation="${6:-}"
  local low=$((words - words / 10))
  local high=$((words + words / 10))

read -r -d '' MANIFESTO_SYSTEM << MANIFESTOSYS || true
You are a writer crafting a manifesto. Not a mission statement. Not a vision document. A declaration of belief.

Stay within ${low}-${high} words.

CRITICAL: Write as if these are your deepest convictions. No references to sessions, lenses, research, or process. You believe this. You are putting a stake in the ground.
${AUDIENCE_TEXT:+
This manifesto speaks to: ${AUDIENCE_TEXT}. Write as if they are reading it. The conviction must be about something they care about.}

The manifesto opens with a single bold line you have been given. Everything that follows must serve that line, amplify it, make it undeniable.

${STYLE_RULES}

Additional rules for the manifesto:
- Write 3-5 paragraphs of conviction after the opening line
- Each paragraph should build on the last, escalating commitment
- End with a single clear call to action: one concrete thing the reader should do, start, stop, or demand
- The whole thing should feel like it could be printed on a wall, read at a rally, or sent as a dare
- Bold the opening line

Do not use section headers. This is one continuous piece. The structure is: the line, the conviction, the call to action.
MANIFESTOSYS

  local dedup_block=""
  if [ -n "$prior_sections" ]; then
    dedup_block="
ALREADY USED - DO NOT REPEAT:
The following sections have already been written. Scan them for specific images, characters, scenes, phrases, and arguments.

HARD RULE: Do not repeat any phrase of three or more words from prior sections. Do not reuse any specific metaphor, example, character, or scene. Do not make the same argument with different words. Find completely different evidence from the transcript for the same underlying point. Your manifesto declares what we believe - find DIFFERENT emotional ground from what has already been covered.

${prior_sections}

---
"
  fi

  local distil_block=""
  if [ -n "$distillation" ]; then
    distil_block="SESSION'S MOST NOVEL FINDINGS:
${distillation}

---

"
  fi

  local manifesto_prompt="${distil_block}Here are research notes on a topic, and a rallying line distilled from them. Write a manifesto that opens with this line and builds conviction around it. Draw on the deepest findings.

THE LINE: ${the_line}

TOPIC: ${seed}

RESEARCH NOTES:
${conversation_text}

---
${dedup_block}
Write the manifesto. Open with the line in bold. Build conviction. End with a call to action."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$manifesto_prompt" > "$tmpfile"

  local result=""
  VERBOSE_CALLER="report:generate"
  if claude_call_no_cap "$tmpfile" "$MANIFESTO_SYSTEM"; then
    result="$CLAUDE_RESPONSE"
  else
    local err_detail=""
    [ -n "$LAST_CLAUDE_ERROR" ] && err_detail=" $(echo "$LAST_CLAUDE_ERROR" | head -c 200)"
    result="[Manifesto generation failed (exit=${LAST_CLAUDE_EXIT_CODE}).${err_detail} The transcript is available for manual review.]"
  fi
  rm -f "$tmpfile"

  echo "$result"
}

# ── Main presentation generator ──
generate_presentation() {
  local conversation_text="$1"
  local seed="$2"
  local words="$3"
  local output_file="$4"
  local turn_info="${5:-}"
  local output_type="${OUTPUT_TYPE:-insight,brief,manifesto}"

  # ── Step 0: Allocate word budget across sections ──
  allocate_budget "$words" "$output_type"
  output_type="$ACTIVE_TYPES"

  echo ""
  echo "  ━━━ WRITING PRESENTATION ━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Target: ${words} words (total)"
  echo "  Types: ${output_type}"
  if [ "$BUDGET_BRIEF" -gt 0 ] || [ "$BUDGET_MANIFESTO" -gt 0 ] || [ "$BUDGET_INSIGHT" -gt 0 ]; then
    echo "  Budget: experiment=${BUDGET_EXPERIMENT}w brief=${BUDGET_BRIEF}w insight=${BUDGET_INSIGHT}w manifesto=${BUDGET_MANIFESTO}w"
  fi
  echo ""

  # ── Step 0.5: Distil session findings ──
  start_spinner "🔬 Distilling session findings"
  local distillation
  distillation=$(distil_session_findings "$conversation_text" "$seed")
  stop_spinner "done"

  # ── Step 1: Generate The Line(s) ──
  local line_count="${LINE_COUNT:-3}"
  start_spinner "💡 Distilling The Line (${line_count} angles)"
  local the_lines
  the_lines=$(generate_the_line "$conversation_text" "$seed" "$line_count" "$distillation")
  stop_spinner "done"

  # Pick the strongest Expression for use in manifesto opening
  local first_line=""
  if [ -n "$the_lines" ]; then
    start_spinner "🎯 Picking strongest expression"
    first_line=$(pick_strongest_line "$the_lines")
    stop_spinner "done"
    # Strip wrapping quotes
    first_line="${first_line#\"}"
    first_line="${first_line%\"}"
    # Fallback: if extraction failed, use first non-empty line
    if [ -z "$first_line" ]; then
      first_line=$(echo "$the_lines" | head -1 | sed 's/^[0-9]*\.\s*//')
      first_line="${first_line#\"}"
      first_line="${first_line%\"}"
    fi
  fi

  # ── Step 1.5: Prosecute the winning line ──
  if [ -n "$first_line" ] && [ -n "$the_lines" ]; then
    # Extract the winning platform
    local winning_platform
    winning_platform=$(echo "$the_lines" | awk -v expr="$first_line" '
      /^\[/ { plat=""; next }
      /^PLATFORM:/ { sub(/^PLATFORM:[[:space:]]*/, ""); plat=$0 }
      /^EXPRESSION:/ && index($0, expr) > 0 { print plat; exit }
    ')
    if [ -n "$winning_platform" ]; then
      start_spinner "⚖️  Prosecuting The Line"
      local prosecuted_pair
      prosecuted_pair=$(prosecute_line "$winning_platform" "$first_line" "$seed" "$distillation" "$the_lines")
      stop_spinner "done"
      # Extract updated platform and expression
      local new_platform new_expression
      new_platform=$(echo "$prosecuted_pair" | grep '^PLATFORM:' | sed 's/^PLATFORM:[[:space:]]*//')
      new_expression=$(echo "$prosecuted_pair" | grep '^EXPRESSION:' | sed 's/^EXPRESSION:[[:space:]]*//')
      if [ -n "$new_expression" ]; then
        first_line="$new_expression"
      fi
      # Update the_lines with the prosecuted pair if it changed
      if [ -n "$new_platform" ] && [ "$new_platform" != "$winning_platform" ]; then
        the_lines="${the_lines}

[PROSECUTED]
PLATFORM: ${new_platform}
EXPRESSION: ${new_expression}"
      fi
    fi
  fi

  # ── Step 2: Generate sections ──
  # Order: Experiment -> Brief -> Insight -> Manifesto (each receives prior content for dedup)
  local experiment_content=""
  local brief_content=""
  local insight_content=""
  local manifesto_content=""
  local prior_sections=""

  # Check which types are active
  local do_brief="" do_manifesto="" do_insight=""
  local IFS=','
  for t in $output_type; do
    case "$t" in
      brief) do_brief="true" ;;
      manifesto) do_manifesto="true" ;;
      insight) do_insight="true" ;;
    esac
  done
  IFS=$' \t\n'

  # Experiment (always generated when budget allows)
  if [ "$BUDGET_EXPERIMENT" -gt 0 ]; then
    start_spinner "🧪 Writing experiment (~${BUDGET_EXPERIMENT}w)"
    experiment_content=$(generate_experiment "$conversation_text" "$seed" "$BUDGET_EXPERIMENT" "$the_lines" "$distillation")
    stop_spinner "done"
    [ -n "$experiment_content" ] && prior_sections="EXPERIMENT:
${experiment_content}"
  fi

  # Brief
  if [ -n "$do_brief" ] && [ "$BUDGET_BRIEF" -gt 0 ]; then
    start_spinner "📋 Writing creative brief (~${BUDGET_BRIEF}w)"
    brief_content=$(generate_brief "$conversation_text" "$seed" "$BUDGET_BRIEF" "$distillation")
    stop_spinner "done"
    [ -n "$brief_content" ] && prior_sections="${prior_sections:+${prior_sections}

---

}BRIEF:
${brief_content}"
  fi

  # Insight (receives experiment + brief for dedup)
  if [ -n "$do_insight" ] && [ "$BUDGET_INSIGHT" -gt 0 ]; then
    start_spinner "📝 Writing insight article (~${BUDGET_INSIGHT}w)"
    insight_content=$(generate_insight "$conversation_text" "$seed" "$BUDGET_INSIGHT" "$prior_sections" "$distillation")
    stop_spinner "done"
    [ -n "$insight_content" ] && prior_sections="${prior_sections:+${prior_sections}

---

}INSIGHT:
${insight_content}"
  fi

  # Manifesto (receives all prior for dedup)
  if [ -n "$do_manifesto" ] && [ "$BUDGET_MANIFESTO" -gt 0 ]; then
    start_spinner "🔥 Writing manifesto (~${BUDGET_MANIFESTO}w)"
    manifesto_content=$(generate_manifesto "$conversation_text" "$seed" "$first_line" "$BUDGET_MANIFESTO" "$prior_sections" "$distillation")
    stop_spinner "done"
  fi

  # Asset (always generated - sensory/tactile description of an object that embodies the insight)
  local asset_content=""
  if [ -n "$first_line" ] && [ -n "$distillation" ]; then
    start_spinner "🎨 Describing the asset"
    asset_content=$(generate_asset "$distillation" "$first_line" "$seed" "$conversation_text")
    stop_spinner "done"
  fi

  # ── Step 3: Assemble output ──
  local mode_label="$(mode_emoji "${MODE:-dyslexic}") ${MODE:-dyslexic}"

  cat > "$output_file" << PRESHEADER
# Think Different Presentation

> **Seed:** ${seed}
> **Date:** $(date '+%Y-%m-%d %H:%M')
> **Words:** ~${words}
${turn_info:+> **Source:** ${turn_info}}
${BRAND_NAME:+> **Brand:** ${BRAND_NAME}}
${AUDIENCE_TEXT:+> **Audience:** ${AUDIENCE_TEXT}}
${MODE:+> **Mode:** ${mode_label}}

---

PRESHEADER

  # The Line - winning line only (all lines go to session transcript)
  if [ -n "$the_lines" ]; then
    echo "" >> "$output_file"
    echo "## The Line" >> "$output_file"
    echo "" >> "$output_file"
    # Extract the winning PLATFORM + EXPRESSION pair
    local winning_pair=""
    if [ -n "$first_line" ]; then
      # Find which angle contains the winning expression and extract its PLATFORM + EXPRESSION
      winning_pair=$(echo "$the_lines" | awk -v expr="$first_line" '
        /^\[/ { block=""; next }
        { block = block "\n" $0 }
        /^EXPRESSION:/ && index($0, expr) > 0 {
          # Print the block for this angle (strip leading newline)
          sub(/^\n/, "", block)
          print block
          exit
        }
      ')
    fi
    if [ -n "$winning_pair" ]; then
      echo "$winning_pair" >> "$output_file"
    else
      echo "$the_lines" >> "$output_file"
    fi
    echo "" >> "$output_file"
    echo "---" >> "$output_file"
  fi

  # The Experiment - hypothesis + what to try + success signal
  if [ -n "$experiment_content" ]; then
    echo "" >> "$output_file"
    echo "## The Experiment" >> "$output_file"
    echo "" >> "$output_file"
    echo "$experiment_content" >> "$output_file"
    echo "" >> "$output_file"
    echo "---" >> "$output_file"
  fi

  # The Asset - sensory/tactile description
  if [ -n "$asset_content" ]; then
    echo "" >> "$output_file"
    echo "## The Asset" >> "$output_file"
    echo "" >> "$output_file"
    echo "$asset_content" >> "$output_file"
    echo "" >> "$output_file"
    echo "---" >> "$output_file"
  fi

  # Insight article - the analytical why
  if [ -n "$insight_content" ]; then
    echo "" >> "$output_file"
    echo "## Insight" >> "$output_file"
    echo "" >> "$output_file"
    echo "$insight_content" >> "$output_file"
    echo "" >> "$output_file"
  fi

  # Creative brief - the how
  if [ -n "$brief_content" ]; then
    echo "---" >> "$output_file"
    echo "" >> "$output_file"
    echo "## Creative Brief" >> "$output_file"
    echo "" >> "$output_file"
    echo "$brief_content" >> "$output_file"
    echo "" >> "$output_file"
  fi

  # Manifesto - emotional declaration / the close
  if [ -n "$manifesto_content" ]; then
    echo "---" >> "$output_file"
    echo "" >> "$output_file"
    echo "## Manifesto" >> "$output_file"
    echo "" >> "$output_file"
    echo "$manifesto_content" >> "$output_file"
    echo "" >> "$output_file"
  fi

  # Session Findings - distilled novel ideas for inspiration
  if [ -n "$distillation" ]; then
    echo "---" >> "$output_file"
    echo "" >> "$output_file"
    echo "## Session Findings" >> "$output_file"
    echo "" >> "$output_file"
    echo "*The most novel ideas from the thinking session, ranked by divergence from conventional thinking.*" >> "$output_file"
    echo "" >> "$output_file"
    echo "$distillation" >> "$output_file"
    echo "" >> "$output_file"
  fi

  # Runner-up lines - non-winning PLATFORM+EXPRESSION pairs
  if [ -n "$the_lines" ] && [ -n "$first_line" ]; then
    local runner_ups=""
    runner_ups=$(echo "$the_lines" | awk -v winner="$first_line" '
      /^\[/ { block=""; next }
      /^$/ { next }
      { block = block (block ? "\n" : "") $0 }
      /^EXPRESSION:/ {
        if (index($0, winner) == 0) {
          print block
          print ""
        }
        block=""
      }
    ')
    runner_ups=$(echo "$runner_ups" | sed '/^$/d' | sed '$ { /^$/d; }')
    if [ -n "$runner_ups" ]; then
      echo "" >> "$output_file"
      echo "### Runner-Up Lines" >> "$output_file"
      echo "" >> "$output_file"
      echo "$runner_ups" >> "$output_file"
      echo "" >> "$output_file"
    fi
  fi

  # Branded footer
  cat >> "$output_file" << 'FOOTER'

---

*Document prepared using the [Think Different Framework](https://www.npmjs.com/package/@sinjin/think-different-framework) by [Sinjin Studio](https://sinjin.studio)*
FOOTER

  # Return combined content for transcript embedding
  local combined=""
  if [ -n "$the_lines" ]; then
    combined="THE LINE(S):
${the_lines}"
  fi
  if [ -n "$experiment_content" ]; then
    combined="${combined}

---

THE EXPERIMENT:

${experiment_content}"
  fi
  if [ -n "$insight_content" ]; then
    combined="${combined}

---

INSIGHT:

${insight_content}"
  fi
  if [ -n "$brief_content" ]; then
    combined="${combined}

---

CREATIVE BRIEF:

${brief_content}"
  fi
  if [ -n "$manifesto_content" ]; then
    combined="${combined}

---

MANIFESTO:

${manifesto_content}"
  fi
  if [ -n "$asset_content" ]; then
    combined="${combined}

---

THE ASSET:

${asset_content}"
  fi
  echo "$combined"
}
