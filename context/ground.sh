#!/usr/bin/env bash
# ── Standalone grounding (--ground-only mode) ──
# Surfaces assumptions about the seed and verifies via web search if available.
# Used only for --ground-only. In normal sessions, grounding is embedded
# in seed prep (fracture/tune/appraise).
#
# Expects globals: $SEED_TOPIC, $PROJECT_CONTEXT, $ALLOWED_TOOLS
# Depends on: lib/json.sh, lib/md.sh, lib/cap_check.sh

# ── Grounding prompt shared between standalone and embedded modes ──
build_ground_preamble() {
  local web_available="false"
  case "${ALLOWED_TOOLS:-}" in
    *WebSearch*) web_available="true" ;;
  esac

  local verify_instruction=""
  if [ "$web_available" = "true" ]; then
    verify_instruction="You have web search. Use it to verify factual claims - market data, demographics, trends, statistics. For each assumption, note whether you verified it or not."
  else
    verify_instruction="Web search is not available. Mark all assumptions as UNVERIFIED and hold them loosely."
  fi

  cat <<PREAMBLE
Before preparing the seed, surface and check your assumptions.

${verify_instruction}

ASSUMPTIONS (3-4 assumptions about THE PROBLEM, AUDIENCE, OR SITUATION most likely to be wrong or most consequential if wrong. Do not surface descriptions of how this thinking framework works. For each, give 2-3 alternative realities that are equally plausible. Mark each VERIFIED or UNVERIFIED):
PREAMBLE
}

ground_standalone() {
  start_spinner "🔍 Grounding the seed"

  local web_available="false"
  case "${ALLOWED_TOOLS:-}" in
    *WebSearch*) web_available="true" ;;
  esac

  if [ "$web_available" != "true" ]; then
    echo ""
    echo "  ⚠ Web search unavailable - assumptions will be unverified."
    echo "  Rerun with default tools or --allowedTools 'WebSearch,WebFetch' for verified grounding."
    echo ""
  fi

  local ground_prompt="You are a rigorous analyst. Your job is to separate what is actually known from what would be assumed about this seed topic.

$(build_ground_preamble)

Surface 3-4 assumptions about THE PROBLEM, AUDIENCE, OR SITUATION BEING EXPLORED that are most likely to be wrong or most consequential if wrong. Do not surface descriptions of how this thinking framework works, its methodology, or its design philosophy.

For each assumption, give 2-3 alternative realities that are equally plausible.

Prioritise ruthlessly. Surface only what would actually change the session if it were wrong.

${PROJECT_CONTEXT:+PROJECT CONTEXT:
${PROJECT_CONTEXT}}

SEED TOPIC: ${SEED_TOPIC}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$ground_prompt" > "$tmpfile"

  local ground_output=""
  if claude_call "$tmpfile"; then
    ground_output="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      stop_spinner "cap limit"
      return 1
    fi
    stop_spinner "skipped (could not reach model)"
    return
  fi
  rm -f "$tmpfile"

  stop_spinner "done"
  echo ""
  echo "$ground_output"
  echo ""

  # Write to transcript
  md_append_section 3 "Ground Check"
  MD_BUFFER="${MD_BUFFER}
${ground_output}
"

  json_append_entry "ground" "Ground Check" "🔍" "Assumption Surfacing" "ground" 0 0 "$ground_output"
}
