#!/usr/bin/env bash
# ── Progressive conversation compression ──
# Generates compressed views of the conversation for different callers.
# The conductor needs territory mapping; lenses need creative texture.
# Raw $CONVERSATION is never modified - views are derived from it.
#
# Tiers:
#   full  (turns 1-10)  - everyone gets raw conversation
#   mid   (turns 11-20) - conductor gets territory digest + recent turns
#   late  (turns 21+)   - both get compressed views
#
# Separate from --compact (which replaces $CONVERSATION itself).
# Always on by default. Disable with --no-progressive.

PROGRESSIVE_ENABLED="${PROGRESSIVE_ENABLED:-true}"
PROGRESSIVE_TIER="full"
LAST_PROGRESSIVE_TURN=0
CONDUCTOR_VIEW=""
LENS_VIEW=""
PROGRESSIVE_STALE_THRESHOLD=5

# Tier thresholds
PROGRESSIVE_MID_TURN=11
PROGRESSIVE_LATE_TURN=21

# ── Determine current tier ──
get_progressive_tier() {
  if [ "$TURN_COUNT" -lt "$PROGRESSIVE_MID_TURN" ]; then
    echo "full"
  elif [ "$TURN_COUNT" -lt "$PROGRESSIVE_LATE_TURN" ]; then
    echo "mid"
  else
    echo "late"
  fi
}

# ── Extract last N lens turns from conversation ──
# Uses the "--- " delimiter pattern that separates lens responses
extract_recent_turns() {
  local text="$1"
  local count="${2:-3}"

  echo "$text" | python3 -c "
import sys
text = sys.stdin.read()
parts = text.split('\n--- ')
if len(parts) > int(${count}):
    recent = '\n--- '.join(parts[-int(${count}):])
    print('--- ' + recent)
else:
    print(text)
" 2>/dev/null || echo "$text"
}

# ── Build compressed views via a single Claude call ──
# Produces both conductor and lens digests as JSON
run_compression_call() {
  local tier="$1"

  local compress_system="You compress creative thinking sessions into working-memory views. The full transcript is preserved elsewhere. Create two digests:

CONDUCTOR DIGEST (300-400 words):
Territory-focused. Map what domains, scales, emotions, audiences, temporal frames have been explored. Name what has NOT been explored. List key tensions and contradictions precisely. Describe the phase of thinking (early divergence, mid-exploration, convergence). Do not preserve creative phrasing - preserve the map. Preserve FRAMING NOTES and PROVOCATION VERIFICATION markers if present - these prevent downstream logical drift.

LENS DIGEST (500-700 words):
Phrasing-focused. Preserve EXACT quotes from breakthrough moments (the phrases that crackle). Name the metaphors and frames that are alive. Capture active contradictions in the language they were stated in. Note which lenses opened which territory. This digest will be read by creative thinkers who need to feel the texture of what has been said. Preserve FRAMING NOTES and PROVOCATION VERIFICATION markers if present.

Respond with a JSON object containing conductor_digest and lens_digest."

  local compress_message="SEED TOPIC: ${SEED_TOPIC}

FULL CONVERSATION (${TURN_COUNT} turns):
${CONVERSATION}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$compress_message" > "$tmpfile"

  local compress_schema='{"type":"object","properties":{"conductor_digest":{"type":"string"},"lens_digest":{"type":"string"}},"required":["conductor_digest","lens_digest"]}'

  start_spinner "📐 Compressing views (${tier})"

  VERBOSE_CALLER="progressive_compress"
  if claude_call_json "$tmpfile" "$compress_schema" "$compress_system"; then
    local conductor_digest lens_digest
    conductor_digest=$(echo "$CLAUDE_RESPONSE" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['conductor_digest'])" 2>/dev/null)
    lens_digest=$(echo "$CLAUDE_RESPONSE" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['lens_digest'])" 2>/dev/null)

    if [ -n "$conductor_digest" ]; then
      local recent_3
      recent_3=$(extract_recent_turns "$CONVERSATION" 3)
      CONDUCTOR_VIEW="=== TERRITORY DIGEST (compressed at turn ${TURN_COUNT}) ===
${conductor_digest}

=== RECENT TURNS ===
${recent_3}"
    fi

    if [ -n "$lens_digest" ]; then
      local recent_5
      recent_5=$(extract_recent_turns "$CONVERSATION" 5)
      LENS_VIEW="=== SESSION DIGEST (compressed at turn ${TURN_COUNT}) ===
${lens_digest}

=== RECENT TURNS ===
${recent_5}"
    fi

    LAST_PROGRESSIVE_TURN=$TURN_COUNT
    stop_spinner "done"
    rm -f "$tmpfile"

    # Log to transcript
    if type md_append_section &>/dev/null; then
      md_append_section "3" "📐 Progressive compression at turn ${TURN_COUNT} (${tier} tier)"
      MD_BUFFER="${MD_BUFFER}
Conductor view: ${#CONDUCTOR_VIEW} chars, Lens view: ${#LENS_VIEW} chars (full: ${#CONVERSATION} chars)
"
      md_flush
    fi

    return 0
  else
    rm -f "$tmpfile"
    stop_spinner "fallback"
    # On failure, views stay as raw conversation
    CONDUCTOR_VIEW=""
    LENS_VIEW=""
    return 1
  fi
}

# ── Check if views need refreshing, compress if needed ──
# Called once per turn before the lens speaks
maybe_refresh_views() {
  [ "${PROGRESSIVE_ENABLED:-true}" != "true" ] && return

  local current_tier
  current_tier=$(get_progressive_tier)

  # Full tier: no compression needed
  if [ "$current_tier" = "full" ]; then
    PROGRESSIVE_TIER="full"
    return
  fi

  local turns_since=$((TURN_COUNT - LAST_PROGRESSIVE_TURN))
  local tier_changed="false"
  [ "$current_tier" != "$PROGRESSIVE_TIER" ] && tier_changed="true"

  # Refresh at tier boundaries or when views are stale
  if [ "$tier_changed" = "true" ] || [ "$turns_since" -ge "$PROGRESSIVE_STALE_THRESHOLD" ]; then
    PROGRESSIVE_TIER="$current_tier"
    run_compression_call "$current_tier"
  fi
}

# ── Return the appropriate conversation view for a caller type ──
# Usage: local conv; conv=$(get_conversation_for "conductor")
get_conversation_for() {
  local caller_type="$1"

  # If progressive compression is off, always return full conversation
  if [ "${PROGRESSIVE_ENABLED:-true}" != "true" ]; then
    echo "$CONVERSATION"
    return
  fi

  local current_tier
  current_tier=$(get_progressive_tier)

  case "$caller_type" in
    conductor)
      # Full tier: raw conversation
      # Mid/Late tier: conductor view (territory digest)
      if [ "$current_tier" = "full" ] || [ -z "$CONDUCTOR_VIEW" ]; then
        echo "$CONVERSATION"
      else
        # Append any turns that happened since last compression
        if [ "$TURN_COUNT" -gt "$LAST_PROGRESSIVE_TURN" ]; then
          local new_turns
          new_turns=$(extract_new_turns_since "$LAST_PROGRESSIVE_TURN")
          if [ -n "$new_turns" ]; then
            echo "${CONDUCTOR_VIEW}

${new_turns}"
          else
            echo "$CONDUCTOR_VIEW"
          fi
        else
          echo "$CONDUCTOR_VIEW"
        fi
      fi
      ;;
    lens|mechanism)
      # Full/Mid tier: raw conversation (lenses get full until late tier)
      # Late tier: lens view (phrasing digest)
      if [ "$current_tier" != "late" ] || [ -z "$LENS_VIEW" ]; then
        echo "$CONVERSATION"
      else
        # Append any turns since last compression
        if [ "$TURN_COUNT" -gt "$LAST_PROGRESSIVE_TURN" ]; then
          local new_turns
          new_turns=$(extract_new_turns_since "$LAST_PROGRESSIVE_TURN")
          if [ -n "$new_turns" ]; then
            echo "${LENS_VIEW}

${new_turns}"
          else
            echo "$LENS_VIEW"
          fi
        else
          echo "$LENS_VIEW"
        fi
      fi
      ;;
    *)
      echo "$CONVERSATION"
      ;;
  esac
}

# ── Extract turns that happened after a given turn number ──
# Counts "--- " delimiters to find turns after the threshold
extract_new_turns_since() {
  local since_turn="$1"

  echo "$CONVERSATION" | python3 -c "
import sys
text = sys.stdin.read()
parts = text.split('\n--- ')
# parts[0] is text before first delimiter (possibly empty)
# parts[1..N] are the lens turns
total_turns = len(parts) - 1
turns_to_skip = int(${since_turn})
if turns_to_skip < total_turns:
    new_parts = parts[turns_to_skip + 1:]
    if new_parts:
        print('--- ' + '\n--- '.join(new_parts))
" 2>/dev/null || true
}
