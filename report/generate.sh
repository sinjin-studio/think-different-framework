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

  BUDGET_BRIEF=0
  BUDGET_MANIFESTO=0
  BUDGET_INSIGHT=0
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
      # All three requested
      if [ "$total" -gt 1000 ]; then
        BUDGET_BRIEF=$((total * 35 / 100))
        BUDGET_MANIFESTO=$((total * 20 / 100))
        BUDGET_INSIGHT=$((total * 45 / 100))
      else
        BUDGET_BRIEF=$((total * 40 / 100))
        BUDGET_MANIFESTO=$((total * 25 / 100))
        BUDGET_INSIGHT=$((total * 35 / 100))
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
    # Brief + manifesto
    BUDGET_BRIEF=$((total * 65 / 100))
    BUDGET_MANIFESTO=$((total * 35 / 100))
    ACTIVE_TYPES="brief,manifesto"
    echo "  Budget (${total}w): brief + manifesto (insight dropped)" >&2
  elif [ "$total" -le 1000 ]; then
    # All three, balanced for medium
    BUDGET_BRIEF=$((total * 40 / 100))
    BUDGET_MANIFESTO=$((total * 25 / 100))
    BUDGET_INSIGHT=$((total * 35 / 100))
    ACTIVE_TYPES="brief,manifesto,insight"
  else
    # All three, insight-heavy for long form
    BUDGET_BRIEF=$((total * 35 / 100))
    BUDGET_MANIFESTO=$((total * 20 / 100))
    BUDGET_INSIGHT=$((total * 45 / 100))
    ACTIVE_TYPES="brief,manifesto,insight"
  fi
}

# ── Generate The Line ──
# Rallying lines distilled from the session.
generate_the_line() {
  local conversation_text="$1"
  local seed="$2"
  local line_count="${3:-3}"

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

What NOT to do:
- No "In a world where..." framing
- No questions
- No colons or semicolons
- No em dashes
- Nothing that sounds like a TED talk title
- Nothing that sounds like a consulting framework
- Nothing generic enough to apply to any topic
- Nothing that reflects on the process of creating it
- Do not explain the lines. Just deliver them

Write at the altitude of ${practitioners}. Not in their style. At their standard.

${line_count_instruction}
LINESYS

  local line_prompt="${AUDIENCE_TEXT:+Audience: ${AUDIENCE_TEXT}

}Here are research notes from a thinking session on: ${seed}

Find the core insight. Render it at two altitudes: the strategic platform (generative truth you can build on) and the expression (audience-facing punch).

RESEARCH NOTES:
${conversation_text}

---

Write the lines. Platform first, then expression. Each angle should carry the insight forward on its own."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$line_prompt" > "$tmpfile"

  local the_lines=""
  if claude_call "$tmpfile" "$LINE_SYSTEM"; then
    the_lines="$CLAUDE_RESPONSE"
  fi
  rm -f "$tmpfile"

  echo "$the_lines"
}

# ── Generate insight article ──
generate_insight() {
  local conversation_text="$1"
  local seed="$2"
  local words="$3"
  local prior_brief="${4:-}"

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
  local experiment_guide="2-3 sentences."

  local numeric_words="${words%%-*}"
  if [ "$numeric_words" -gt 1200 ] 2>/dev/null; then
    provocation_guide="3-5 sentences. Take time to set up the stakes."
    landscape_guide="5-8 sentences. What did you actually notice? Not a literature review."
    insight_guide="6-10 sentences. Develop the argument fully. Use examples or analogies."
    tension_guide="4-6 sentences. What keeps you up at night about this idea?"
    experiment_guide="3-5 sentences. Be specific enough that someone could act on it tomorrow."
  fi
  if [ "$numeric_words" -gt 2000 ] 2>/dev/null; then
    provocation_guide="4-6 sentences. Build the case for why this question matters now."
    landscape_guide="8-12 sentences. Tell the story of what you found. Let the reader feel the turns."
    insight_guide="10-15 sentences. This is the centrepiece. Develop it like a short essay section."
    tension_guide="6-10 sentences. Give the counter-position real weight. Make it uncomfortable."
    experiment_guide="4-8 sentences. Multiple concrete steps if warranted."
  fi

read -r -d '' INSIGHT_SYSTEM << INSIGHTSYS || true
You are a writer turning research notes into a short, original article. Your job is the ANALYTICAL dimension. Go where a brief cannot - into history, cultural theory, uncomfortable questions, systemic tensions. Do not describe the audience or write proof points. That is the brief's job. You are here to say something the brief cannot.

CRITICAL: You are writing as someone who HAD the insight, not someone who WATCHED a process generate it. The reader must never know these ideas came from a multi-agent session. No references to "the session", "the conversation", "the agents", "the transcript", "the thinking", "the exploration", or any language that describes a process of discovery. Write as if you sat with this question for a long time and arrived at something worth sharing.

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

**The Experiment**
What would you actually build or try? Be concrete enough that someone could start tomorrow morning. ${experiment_guide}

After the five sections, add:

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
- Diagram type: a journey/flow showing Provocation -> Landscape -> Insight -> Tension -> Experiment as connected nodes, with the core insight node visually emphasised
- Short labels only (2-4 words per node, extracted from your actual content)
- No decorative elements - clean, minimal, functional

${length_guidance}
INSIGHTSYS

  local dedup_block=""
  if [ -n "$prior_brief" ]; then
    dedup_block="
TERRITORY ALREADY COVERED:
A creative brief has already been written covering audience, proposition, and proof points. Your article MUST NOT repeat the same arguments, examples, or proof points. Find DIFFERENT angles - cultural implications, historical parallels, systemic tensions the brief couldn't reach.

BRIEF (already written):
${prior_brief}

---

"
  fi

  local insight_prompt="Here are research notes on the following topic. Read them and write an original article based on the best ideas within. Write as if the ideas are your own.

TOPIC: ${seed}

RESEARCH NOTES:
${conversation_text}

---
${dedup_block}
Write the article. ${length_guidance} Six sections. First person voice. No lists, no filler. No meta-commentary about the research process."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$insight_prompt" > "$tmpfile"

  local result=""
  if claude_call "$tmpfile" "$INSIGHT_SYSTEM"; then
    result="$CLAUDE_RESPONSE"
  else
    result="[Insight generation failed. The transcript is available for manual review.]"
  fi
  rm -f "$tmpfile"

  echo "$result"
}

# ── Generate creative brief ──
generate_brief() {
  local conversation_text="$1"
  local seed="$2"
  local words="$3"

  local numeric_words="${words%%-*}"
  local low=$((numeric_words - numeric_words / 10))
  local high=$((numeric_words + numeric_words / 10))
  local length_guidance="Stay within ${low}-${high} words. A brief that runs long is not a brief."
  if [ "$numeric_words" -gt 1200 ] 2>/dev/null; then
    length_guidance="Stay within ${low}-${high} words. You have room to develop each section. Use it, but stay sharp."
  fi

read -r -d '' BRIEF_SYSTEM << BRIEFSYS || true
You are a strategist writing a creative brief. Not a deck. Not a document. A brief. Your job is the ACTIONABLE dimension. Who to reach, what to say, why it's true, and how to execute. Stay in the world of the brief - what a creative team needs to do their job. Leave the cultural analysis and theory for elsewhere.

CRITICAL: Write as if you arrived at these conclusions yourself. No references to sessions, agents, transcripts, or any process. You spent time with this problem and you know what needs to happen.
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

${length_guidance}
BRIEFSYS

  local brief_prompt="Here are research notes on the following topic. Distill them into a creative brief.

TOPIC: ${seed}

RESEARCH NOTES:
${conversation_text}

---

Write the brief. Be direct. Every word earns its place."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$brief_prompt" > "$tmpfile"

  local result=""
  if claude_call "$tmpfile" "$BRIEF_SYSTEM"; then
    result="$CLAUDE_RESPONSE"
  else
    result="[Brief generation failed. The transcript is available for manual review.]"
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
  local prior_brief="${5:-}"
  local low=$((words - words / 10))
  local high=$((words + words / 10))

read -r -d '' MANIFESTO_SYSTEM << MANIFESTOSYS || true
You are a writer crafting a manifesto. Not a mission statement. Not a vision document. A declaration of belief.

Stay within ${low}-${high} words.

CRITICAL: Write as if these are your deepest convictions. No references to sessions, agents, research, or process. You believe this. You are putting a stake in the ground.
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
  if [ -n "$prior_brief" ]; then
    dedup_block="
TERRITORY ALREADY CLAIMED:
A creative brief has already been written. It painted specific characters, scenes, and emotional ground. Your manifesto MUST NOT re-use the same characters, re-play the same scenes, or cover the same emotional territory. The brief describes who they are. You declare what we believe. Find DIFFERENT emotional ground - escalate from conviction, not from character portraits.

BRIEF (already written):
${prior_brief}

---
"
  fi

  local manifesto_prompt="Here are research notes on a topic, and a rallying line distilled from them. Write a manifesto that opens with this line and builds conviction around it.

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
  if claude_call "$tmpfile" "$MANIFESTO_SYSTEM"; then
    result="$CLAUDE_RESPONSE"
  else
    result="[Manifesto generation failed. The transcript is available for manual review.]"
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
    echo "  Budget: brief=${BUDGET_BRIEF}w manifesto=${BUDGET_MANIFESTO}w insight=${BUDGET_INSIGHT}w"
  fi
  echo ""

  # ── Step 1: Generate The Line(s) ──
  local line_count="${LINE_COUNT:-3}"
  start_spinner "💡 Distilling The Line (${line_count} angles)"
  local the_lines
  the_lines=$(generate_the_line "$conversation_text" "$seed" "$line_count")
  stop_spinner "done"

  # Extract the first Expression for use in manifesto opening
  local first_line=""
  if [ -n "$the_lines" ]; then
    # Find the first EXPRESSION: line and extract its value
    first_line=$(echo "$the_lines" | grep -m 1 '^EXPRESSION:' | sed 's/^EXPRESSION:[[:space:]]*//')
    # Strip wrapping quotes
    first_line="${first_line#\"}"
    first_line="${first_line%\"}"
    # Fallback: if no EXPRESSION: prefix found, use first non-empty line
    if [ -z "$first_line" ]; then
      first_line=$(echo "$the_lines" | head -1 | sed 's/^[0-9]*\.\s*//')
      first_line="${first_line#\"}"
      first_line="${first_line%\"}"
    fi
  fi

  # ── Step 2: Generate in fixed order (brief -> manifesto -> insight) ──
  # Brief first so its content can be passed to insight for dedup
  local insight_content=""
  local brief_content=""
  local manifesto_content=""

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

  # Brief (always first - feeds into insight dedup)
  if [ -n "$do_brief" ] && [ "$BUDGET_BRIEF" -gt 0 ]; then
    start_spinner "📋 Writing creative brief (~${BUDGET_BRIEF}w)"
    brief_content=$(generate_brief "$conversation_text" "$seed" "$BUDGET_BRIEF")
    stop_spinner "done"
  fi

  # Manifesto
  if [ -n "$do_manifesto" ] && [ "$BUDGET_MANIFESTO" -gt 0 ]; then
    start_spinner "🔥 Writing manifesto (~${BUDGET_MANIFESTO}w)"
    manifesto_content=$(generate_manifesto "$conversation_text" "$seed" "$first_line" "$BUDGET_MANIFESTO" "$brief_content")
    stop_spinner "done"
  fi

  # Insight (last - receives brief content for dedup)
  if [ -n "$do_insight" ] && [ "$BUDGET_INSIGHT" -gt 0 ]; then
    start_spinner "📝 Writing insight article (~${BUDGET_INSIGHT}w)"
    insight_content=$(generate_insight "$conversation_text" "$seed" "$BUDGET_INSIGHT" "$brief_content")
    stop_spinner "done"
  fi

  # ── Step 3: Assemble output ──
  cat > "$output_file" << PRESHEADER
# Think Different Presentation

> **Seed:** ${seed}
> **Date:** $(date '+%Y-%m-%d %H:%M')
> **Words:** ~${words}
${turn_info:+> **Source:** ${turn_info}}
${BRAND_NAME:+> **Brand:** ${BRAND_NAME}}
${AUDIENCE_TEXT:+> **Audience:** ${AUDIENCE_TEXT}}
${MODE:+> **Mode:** ${MODE}}

---

PRESHEADER

  # The Line(s) - always first if we have them
  if [ -n "$the_lines" ]; then
    echo "" >> "$output_file"
    echo "## The Line" >> "$output_file"
    echo "" >> "$output_file"
    echo "$the_lines" >> "$output_file"
    echo "" >> "$output_file"
    echo "---" >> "$output_file"
  fi

  # Creative brief (audience-actionable)
  if [ -n "$brief_content" ]; then
    echo "" >> "$output_file"
    echo "## Creative Brief" >> "$output_file"
    echo "" >> "$output_file"
    echo "$brief_content" >> "$output_file"
    echo "" >> "$output_file"
  fi

  # Manifesto (audience-facing declaration)
  if [ -n "$manifesto_content" ]; then
    echo "---" >> "$output_file"
    echo "" >> "$output_file"
    echo "## Manifesto" >> "$output_file"
    echo "" >> "$output_file"
    echo "$manifesto_content" >> "$output_file"
    echo "" >> "$output_file"
  fi

  # Insight article (analytical deep-dive)
  if [ -n "$insight_content" ]; then
    echo "---" >> "$output_file"
    echo "" >> "$output_file"
    echo "## Insight" >> "$output_file"
    echo "" >> "$output_file"
    echo "$insight_content" >> "$output_file"
    echo "" >> "$output_file"
  fi

  # Branded footer
  cat >> "$output_file" << 'FOOTER'

---

<p align="center"><sub>Document prepared using the <a href="https://www.npmjs.com/package/@sinjin/think-different-framework">Think Different Framework</a> by <a href="https://sinjin.studio">Sinjin Studio</a></sub></p>
FOOTER

  # Return combined content for transcript embedding
  local combined=""
  if [ -n "$the_lines" ]; then
    combined="THE LINE(S):
${the_lines}"
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
  if [ -n "$insight_content" ]; then
    combined="${combined}

---

INSIGHT:

${insight_content}"
  fi
  echo "$combined"
}
