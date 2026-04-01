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

# ── Provocation verification and correction ──
# Verifies factual claims in the provocation and corrects fabricated stats.
# Only runs when the provocation contains quantitative/factual claims and
# web search is available. Updates $SEED_TOPIC with corrected provocation,
# stores full report in $SEED_VERIFICATION, and disables embedded grounding
# in fracture/tune/appraise (since verification already happened).
#
# Expects globals: $SEED_TOPIC, $ORIGINAL_INPUT, $GROUND_ENABLED, $ALLOWED_TOOLS
# Sets: $SEED_TOPIC (corrected), $SEED_VERIFICATION, $GROUND_ENABLED=false

verify_provocation() {
  [ "${GROUND_ENABLED:-true}" = "true" ] || return 0

  # Only verify if provocation contains quantitative/factual claims
  if ! echo "$SEED_TOPIC" | grep -qE '[0-9]+%|[0-9]+ (percent|million|billion)|study |research |report |survey |according to'; then
    return 0
  fi

  # Only verify if web search available
  case "${ALLOWED_TOOLS:-}" in
    *WebSearch*) ;;
    *) return 0 ;;
  esac

  start_spinner "🔍 Verifying provocation claims"

  local verify_prompt="You are a fact-checker preparing a creative thinking session. The provocation below was generated from user input to be deliberately provocative. Your job is to verify every factual claim it makes and correct what isn't real, so the session works with honest numbers.

For each specific statistic, percentage, named study, or factual claim in the provocation:
1. Search for verification
2. If VERIFIED: note the source
3. If UNVERIFIED: find the closest real data that serves the same argument

Output EXACTLY this format, nothing else:

CLAIMS:
[For each claim: the claim, VERIFIED or UNVERIFIED, what you actually found, source if verified]

CORRECTED PROVOCATION:
[The provocation rewritten with fabricated statistics replaced by real ones. Swap in the closest verified data that preserves the provocation's intent. If a claim has no close equivalent, reframe without a specific number. Keep the rhetorical energy - you are fixing facts, not flattening voice. If no corrections needed, return the original provocation unchanged.]

FRAMING NOTES:
[Flag 2-3 word choices in the provocation that carry rhetorical weight rather than factual claims. These are framing choices made by the provocation generator, not evidence of real-world behaviour. Note them so downstream creative work knows which words are doing rhetorical work vs. reporting reality.]

ORIGINAL USER INPUT: ${ORIGINAL_INPUT:-unknown}

PROVOCATION TO VERIFY: ${SEED_TOPIC}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$verify_prompt" > "$tmpfile"

  VERBOSE_CALLER="provocation:verify"
  if claude_call "$tmpfile"; then
    local verify_response="$CLAUDE_RESPONSE"

    # Extract corrected provocation
    local corrected
    corrected=$(echo "$verify_response" | sed -n '/^CORRECTED PROVOCATION:/,/^FRAMING NOTES:/p' | sed '1d;$d' | sed 's/^[[:space:]]*//' | sed '/^$/d')

    if [ -n "$corrected" ]; then
      # Store original provocation for the record
      local original_provocation="$SEED_TOPIC"
      SEED_TOPIC="$corrected"
      echo ""
      echo "  ✓ Provocation corrected with verified data"
    fi

    # Store full verification report
    SEED_VERIFICATION="$verify_response"

    # Disable embedded grounding in fracture/tune/appraise (we just did it)
    GROUND_ENABLED="false"
  else
    rm -f "$tmpfile"
    if [ "$RATE_LIMIT_HIT" = "true" ]; then
      stop_spinner "rate limit"
      return 1
    fi
    stop_spinner "skipped (could not reach model)"
    return 0
  fi
  rm -f "$tmpfile"

  stop_spinner "done"
  echo ""
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
  VERBOSE_CALLER="ground"
  if claude_call "$tmpfile"; then
    ground_output="$CLAUDE_RESPONSE"
  else
    rm -f "$tmpfile"
    if [ "$RATE_LIMIT_HIT" = "true" ]; then
      stop_spinner "rate limit"
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
