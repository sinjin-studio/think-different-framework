#!/usr/bin/env bash
# ── Cross-transcript synthesis ──
# Combines multiple transcript files into a single presentation.
# Uses the same presentation sections and Line generation as generate.sh.
# Includes cross-run negative space analysis when multiple transcripts are provided.
# Expects: claude CLI available, generate.sh sourced first, OUTPUT_SECTIONS set

# ── Cross-run negative space analysis ──
# Maps the negative space between multiple provocation runs.
# Constellations are defined as much by the dark space between
# the stars as by the stars themselves.
analyse_synthesis_negative_space() {
  local all_notes="$1"
  local seed_summary="$2"
  local transcript_count="$3"

  start_spinner "🔭 Mapping negative space between ${transcript_count} runs"

  local ns_prompt="You are analysing ${transcript_count} separate creative thinking sessions that all explored variations of the same seed topic. Each session took a different path through the problem space.

Your job is to map the NEGATIVE SPACE between them - the territory that no session entered.

Each session lit up certain areas: certain audiences, scales, emotions, domains, time horizons, and angles. Together they form a constellation of explored territory. But constellations are defined as much by the dark space between the stars as by the stars themselves.

Read all sessions and:

1. Name the 3-5 major territories that ALL sessions explored (the shared ground)
2. Name the 2-3 territories that only ONE session explored (the edges)
3. Name the 2-4 territories that NO session explored (the negative space)
4. For each negative space territory, explain why it matters and what might be found there
5. Name the pattern: what does the shape of the negative space tell us about the assumptions all sessions shared?

The negative space between runs is often more interesting than what any individual run found. It reveals the collective blind spot - the place where the provocation itself directed attention away from.

SEED TOPIC: ${seed_summary}

${all_notes}

Respond with a JSON object containing:
- shared_ground: array of strings naming territories all sessions explored
- edges: array of strings naming territories only one session explored
- negative_spaces: array of objects, each with territory (string) and why_it_matters (string)
- negative_space_pattern: single string naming the collective blind spot"

  local json_schema='{"type":"object","properties":{"shared_ground":{"type":"array","items":{"type":"string"}},"edges":{"type":"array","items":{"type":"string"}},"negative_spaces":{"type":"array","items":{"type":"object","properties":{"territory":{"type":"string"},"why_it_matters":{"type":"string"}},"required":["territory","why_it_matters"]}},"negative_space_pattern":{"type":"string"}},"required":["shared_ground","edges","negative_spaces","negative_space_pattern"]}'

  local tmpfile
  tmpfile=$(mktemp)
  echo "$ns_prompt" > "$tmpfile"

  local ns_analysis=""
  VERBOSE_CALLER="synthesise"
  if claude_call_json "$tmpfile" "$json_schema"; then
    ns_analysis="$CLAUDE_RESPONSE"
  fi
  rm -f "$tmpfile"

  stop_spinner "done"

  # Format for inclusion in presentation generation
  if [ -n "$ns_analysis" ]; then
    local formatted
    formatted=$(echo "$ns_analysis" | python3 -c "
import sys, json
d = json.load(sys.stdin)
parts = []
parts.append('CROSS-RUN NEGATIVE SPACE ANALYSIS')
parts.append('')
parts.append('Shared ground (all sessions explored): ' + '; '.join(d.get('shared_ground', [])))
parts.append('Edge territory (single session): ' + '; '.join(d.get('edges', [])))
parts.append('')
parts.append('THE NEGATIVE SPACE (no session explored):')
for v in d.get('negative_spaces', []):
    parts.append('- ' + v.get('territory','') + ': ' + v.get('why_it_matters',''))
parts.append('')
parts.append('Pattern of collective avoidance: ' + d.get('negative_space_pattern', ''))
print('\n'.join(parts))
" 2>/dev/null || echo "")
    echo "$formatted"
  fi
}

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
  start_spinner "📝 Reading transcripts"

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
      stop_spinner "failed"
      echo "  Warning: transcript not found: $tf"
      start_spinner "📝 Reading transcripts"
    fi
  done

  stop_spinner "done (${#transcript_files[@]} files)"

  # Cross-run negative space analysis (only when multiple transcripts)
  if [ "${#transcript_files[@]}" -gt 1 ] && [ "$NEGATIVE_SPACE_ENABLED" = "true" ]; then
    local ns_section
    ns_section=$(analyse_synthesis_negative_space "$all_notes" "$seed_summary" "${#transcript_files[@]}")
    if [ -n "$ns_section" ]; then
      all_notes="=== CROSS-RUN NEGATIVE SPACE ANALYSIS ===
${ns_section}

${all_notes}"
    fi
  fi

  # Use generate_presentation with the combined notes
  # The synthesis framing is handled by the combined notes format
  generate_presentation "$all_notes" "$seed_summary" "$words" "$output_file" "${#transcript_files[@]} transcripts synthesised"
}
