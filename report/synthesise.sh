#!/usr/bin/env bash
# ── Cross-transcript synthesis ──
# Combines multiple transcript files into a single presentation.
# Uses the same output types and Line generation as generate.sh.
# Expects: claude CLI available, generate.sh sourced first, OUTPUT_TYPE set

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

  # Use generate_presentation with the combined notes
  # The synthesis framing is handled by the combined notes format
  generate_presentation "$all_notes" "$seed_summary" "$words" "$output_file" "${#transcript_files[@]} transcripts synthesised"
}
