#!/usr/bin/env bash
# ── Presentation generation ──
# Converts a single transcript into a structured presentation.
# Expects: claude CLI available

generate_presentation() {
  local conversation_text="$1"
  local seed="$2"
  local words="$3"
  local output_file="$4"
  local turn_info="${5:-}"

  echo ""
  echo "  ━━━ WRITING PRESENTATION ━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Target: ${words} words"
  echo ""
  echo -n "  📝 Distilling into a presentation..."

  local length_guidance=""
  case "$words" in
    *-*)
      length_guidance="Total length: ${words} words. Every word must earn its place."
      ;;
    *)
      local low=$((words - words / 10))
      local high=$((words + words / 10))
      length_guidance="Total length: approximately ${words} words (${low}-${high} range). Use the space to develop arguments fully, but do not pad. Every paragraph must earn its place."
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
    landscape_guide="5-8 sentences. Give the reader a real sense of the journey."
    insight_guide="6-10 sentences. Develop the argument fully. Use examples or analogies."
    tension_guide="4-6 sentences. Give the counter-position real weight."
    experiment_guide="3-5 sentences. Be specific enough that someone could act on it tomorrow."
  fi
  if [ "$numeric_words" -gt 2000 ] 2>/dev/null; then
    provocation_guide="4-6 sentences. Build the case for why this question matters now."
    landscape_guide="8-12 sentences. Tell the story of the exploration. Let the reader feel the turns."
    insight_guide="10-15 sentences. This is the centrepiece. Develop it like a short essay section."
    tension_guide="6-10 sentences. Steelman the counter-position. Make it uncomfortable."
    experiment_guide="4-8 sentences. Multiple concrete steps if warranted."
  fi

read -r -d '' PRES_SYSTEM << PRESSYS || true
You are a writer turning research notes into a short, original article.

CRITICAL: You are writing as someone who HAD the insight, not someone who WATCHED a process generate it. The reader must never know these ideas came from a multi-agent session. No references to "the session", "the conversation", "the agents", "the transcript", "the thinking", "the exploration", or any language that describes a process of discovery. Write as if you sat with this question for a long time and arrived at something worth sharing.

Do not be self-reflective about the act of thinking. Just deliver the ideas themselves.

Write in first person as a creative technologist with 25+ years of experience. The voice is thoughtful, direct, and conversational. No corporate language, no filler, no hedging. Every sentence should earn its place.

Style rules:
- Do not use em dashes. Use hyphens, commas, or full stops instead
- Do not use bullet points, numbered lists, or headers with markdown formatting
- Do not use the words "genuinely", "honestly", or "straightforward"
- No emojis
- Write in paragraphs, not lists
- Sentences should vary in length. Short ones hit harder after long ones

Structure the article with these sections, using a single bold line as the section label:

**The Provocation**
Sharpen the question. Why does this matter? What is at stake? Write as if posing the question yourself. ${provocation_guide}

**The Landscape**
The key ideas and territories, told as a narrative of your own exploration. Do NOT describe a process. Lay out the intellectual terrain as if recounting your own train of thought. ${landscape_guide}

**The Insight**
The core discovery. Name it. Frame it as an argument, not an observation. This is the centrepiece. The best insights feel both surprising and obvious. Aim for simplicity. ${insight_guide}

**The Tension**
The honest counterargument. Present it as something you wrestled with yourself. Good thinking includes its own critique. ${tension_guide}

**The Experiment**
The smallest, most specific thing someone could do tomorrow to test whether the insight is real. Could be something to build, prototype, try, or simply observe differently. Write it as a recommendation from personal conviction. ${experiment_guide}

After the five sections, add:

**Sources and Threads**
Specific thinkers, precedents, concepts, or cross-domain connections that informed the thinking. Write as "I drew on..." not "the agents referenced..."

${length_guidance}
PRESSYS

  local pres_prompt="Here are research notes on the following topic. Read them and write an original article based on the best ideas within. Write as if the ideas are your own.

TOPIC: ${seed}

RESEARCH NOTES:
${conversation_text}

---

Write the article. ${length_guidance} Six sections. First person voice. No lists, no filler. No meta-commentary about the research process."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$pres_prompt" > "$tmpfile"

  local pres_content
  pres_content=$(cat "$tmpfile" | claude -p --system-prompt "$PRES_SYSTEM" 2>/dev/null) || {
    pres_content="[Presentation generation failed. The transcript is available for manual review.]"
  }
  rm -f "$tmpfile"

  echo " done"

  cat > "$output_file" << PRESHEADER
# Think Different Presentation

> **Seed:** ${seed}
> **Date:** $(date '+%Y-%m-%d %H:%M')
> **Words:** ~${words}
${turn_info:+> **Source:** ${turn_info}}

---

PRESHEADER

  echo "$pres_content" >> "$output_file"
  echo "$pres_content"
}
