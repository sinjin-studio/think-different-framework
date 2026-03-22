#!/usr/bin/env bash
# ── Cross-transcript synthesis ──
# Combines multiple transcript files into a single presentation.
# Used when running multiple provocations or manual synthesis.
# Expects: claude CLI available

synthesise_presentations() {
  local words="$1"
  local output_file="$2"
  local seed_summary="$3"
  shift 3
  local transcript_files=("$@")

  echo ""
  echo "  ━━━ SYNTHESISING ${#transcript_files[@]} TRANSCRIPTS ━━━━━━━"
  echo "  Target: ${words} words"
  echo ""
  echo -n "  📝 Reading transcripts..."

  local all_notes=""
  local i=1
  for tf in "${transcript_files[@]}"; do
    if [ -f "$tf" ]; then
      all_notes="${all_notes}

=== RESEARCH SESSION ${i} ===
$(cat "$tf")
"
      i=$((i + 1))
    else
      echo ""
      echo "  Warning: transcript not found: $tf"
    fi
  done

  echo " done (${#transcript_files[@]} files)"
  echo -n "  📝 Synthesising into a single presentation..."

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

  local provocation_guide="3-5 sentences. Take time to set up the stakes."
  local landscape_guide="5-8 sentences. Give the reader a real sense of the journey."
  local insight_guide="6-10 sentences. Develop the argument fully."
  local tension_guide="4-6 sentences. Give the counter-position real weight."
  local experiment_guide="3-5 sentences. Be specific enough to act on."

  local numeric_words="${words%%-*}"
  if [ "$numeric_words" -gt 2000 ] 2>/dev/null; then
    provocation_guide="4-6 sentences. Build the case for why this question matters now."
    landscape_guide="8-12 sentences. Tell the story of the exploration. Let the reader feel the turns."
    insight_guide="10-15 sentences. This is the centrepiece. Develop it like a short essay section."
    tension_guide="6-10 sentences. Steelman the counter-position. Make it uncomfortable."
    experiment_guide="4-8 sentences. Multiple concrete steps if warranted."
  fi

read -r -d '' SYNTH_SYSTEM << SYNTHSYS || true
You are a writer turning multiple sets of research notes into a single, original article.

CRITICAL: You are writing as someone who HAD the insights, not someone who WATCHED multiple processes generate them. The reader must never know these ideas came from multiple sessions, multiple agents, or any structured process. No references to "sessions", "conversations", "agents", "transcripts", or any language that reveals the process. Write as if you spent a long time with this question and arrived at something worth sharing.

You have been given research notes from multiple thinking sessions on related provocations. Your job is to find the overarching shape, the insight that is stronger than any individual session produced. The synthesis should feel like one coherent argument, not a collection of highlights.

Write in first person as a creative technologist with 25+ years of experience. The voice is thoughtful, direct, and conversational. No corporate language, no filler, no hedging.

Style rules:
- Do not use em dashes. Use hyphens, commas, or full stops instead
- Do not use bullet points, numbered lists, or headers with markdown formatting
- Do not use the words "genuinely", "honestly", or "straightforward"
- No emojis
- Write in paragraphs, not lists
- Sentences should vary in length. Short ones hit harder after long ones

Structure the article with these sections, using a single bold line as the section label:

**The Provocation**
Sharpen the question. Why does this matter? What is at stake? ${provocation_guide}

**The Landscape**
The key ideas and territories, told as a narrative of your own exploration. ${landscape_guide}

**The Insight**
The core discovery. Name it. Frame it as an argument, not an observation. The best insights feel both surprising and obvious. ${insight_guide}

**The Tension**
The honest counterargument. Present it as something you wrestled with yourself. ${tension_guide}

**The Experiment**
The smallest, most specific thing someone could do tomorrow to test whether the insight is real. ${experiment_guide}

**Sources and Threads**
Specific thinkers, precedents, concepts, or cross-domain connections. Write as "I drew on..."

${length_guidance}
SYNTHSYS

  local synth_prompt="Here are research notes from multiple thinking sessions on related aspects of a topic. Read all of them and write a single original article that captures the overarching insight. The article should be stronger than any individual session. Write as if the ideas are your own.

TOPIC: ${seed_summary}

${all_notes}

---

Write one cohesive article. ${length_guidance} Six sections. First person voice. No lists, no filler. Never reference multiple sessions."

  local tmpfile
  tmpfile=$(mktemp)
  echo "$synth_prompt" > "$tmpfile"

  local synth_content
  synth_content=$(cat "$tmpfile" | claude -p --system-prompt "$SYNTH_SYSTEM" 2>/dev/null) || {
    synth_content="[Synthesis failed. Individual transcripts are available for manual review.]"
  }
  rm -f "$tmpfile"

  echo " done"

  cat > "$output_file" << SYNTHHEADER
# Think Different Presentation (Synthesis)

> **Topic:** ${seed_summary}
> **Date:** $(date '+%Y-%m-%d %H:%M')
> **Words:** ~${words}
> **Sources:** ${#transcript_files[@]} transcripts

---

SYNTHHEADER

  echo "$synth_content" >> "$output_file"
  echo "$synth_content"
}
