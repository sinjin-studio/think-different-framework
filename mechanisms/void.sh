#!/usr/bin/env bash
# ── Negative space mapping (Hubble Deep Field) ──
# Cartographer of absence: maps the territory no lens has explored.
# Every lens response illuminates some ground. This mechanism maps
# the dark patches between the lit areas and asks what is in there.
# Returns structured decision in $VOID_DECISION (JSON).
# Expects globals: $CONVERSATION, $TRANSCRIPT_MD, $TRANSCRIPT_JSON,
#                  $TURN_COUNT, $UNIT_LABEL, $SEED_TOPIC
# Depends on: lib/json.sh, lib/cap_check.sh

VOID_DECISION=""

map_negative_space() {
  [ "$VOID_ENABLED" != "true" ] && return
  local unit_num="$1"
  VOID_DECISION=""
  start_spinner "🔭 Mapping negative space"

  local mechanism_history
  mechanism_history=$(build_mechanism_history)

  local void_prompt="You are a cartographer of absence. Your job is not to evaluate what has been said - other mechanisms do that. Your job is to map what has NOT been said.

Think of it like this: every lens response illuminates some territory. Friction finds where the lit areas contradict each other. Transcendence asks whether the lit areas touch something that matters. You are different. You are pointing the telescope at the dark spaces between the lit areas and asking: what is in there?

The Hubble Deep Field was discovered by pointing the telescope at a patch of sky that appeared empty - no bright stars, no known galaxies. The absence of foreground noise was the condition for seeing further. That is your method.

Read the conversation and the seed topic. Then:

1. Map the territory the conversation HAS covered. What domains, scales, audiences, emotions, time horizons, and stakeholders have been addressed?

2. Now map what is missing. Not what is wrong - what is ABSENT. Think about:
   - Scales not visited (if everything is personal, what about institutional? If everything is strategic, what about the moment of use?)
   - Audiences not considered (who has not been imagined as the person at the centre?)
   - Time horizons not explored (if everything is immediate, what about generational? If everything is aspirational, what about right now?)
   - Emotions not touched (if the conversation is all urgency, where is tenderness? If all hope, where is grief?)
   - Domains not crossed into (what adjacent fields could illuminate this but have not been mentioned?)
   - The uncomfortable question nobody has asked

3. For each void territory (2-4 territories), suggest which lens key is best equipped to explore it. A void in empathy calls for the empath. A void in scale calls for the scaler. A void in what is literally there calls for the observer.

4. Use web search to check: is this territory genuinely unexplored in broader discourse, or has the conversation simply not reached it yet? The most interesting voids are the ones that are also absent from the existing conversation around this topic.

5. Name the pattern of avoidance. WHY is the conversation not going there? This pattern is itself a finding.

SEED TOPIC: ${SEED_TOPIC}
${ZEITGEIST_CONTEXT:+
${ZEITGEIST_CONTEXT}
Use these sources as a baseline. If the conversation is only covering territory these articles already occupy, that is itself a void - the session has not yet gone beyond what is already known. The most valuable voids are the ones absent from BOTH the conversation AND the broader discourse.
}
Respond with a JSON object containing:
- territories: array of 2-4 objects, each with name (short label), description (what could be found there), suggested_lens (lens key to explore it), and web_check (what you found searching for this territory in broader discourse - empty string if no search)
- pattern_of_avoidance: single sentence naming why the conversation has avoided these areas
- recommendation: one of 'redirect_to_void' (the unexplored territory is the most interesting place to go next), 'note_and_continue' (voids are noted but current direction is productive), or 'void_is_intentional' (the conversation has deliberately narrowed, which is appropriate for this stage)
${mechanism_history}
CONVERSATION:
${CONVERSATION}"

  local tmpfile
  tmpfile=$(mktemp)
  echo "$void_prompt" > "$tmpfile"

  # Resume skip
  if [ "$TURN_COUNT" -lt "$RESUME_FROM_TURN" ]; then
    rm -f "$tmpfile"
    stop_spinner "skipped (resuming)"
    TURN_COUNT=$((TURN_COUNT + 1))
    return
  fi

  local json_schema='{"type":"object","properties":{"territories":{"type":"array","items":{"type":"object","properties":{"name":{"type":"string"},"description":{"type":"string"},"suggested_lens":{"type":"string"},"web_check":{"type":"string"}},"required":["name","description","suggested_lens"]}},"pattern_of_avoidance":{"type":"string"},"recommendation":{"type":"string","enum":["redirect_to_void","note_and_continue","void_is_intentional"]}},"required":["territories","pattern_of_avoidance","recommendation"]}'

  # Temporarily ensure web search is available for void territory checking
  local saved_tools="$ALLOWED_TOOLS_FLAG"
  ALLOWED_TOOLS_FLAG="--allowedTools WebSearch,WebFetch"

  local territories decision_json
  VERBOSE_CALLER="mechanism:void"
  if claude_call_json "$tmpfile" "$json_schema"; then
    decision_json="$CLAUDE_RESPONSE"
    VOID_DECISION="$decision_json"
    # Extract territory descriptions as prose for conversation
    territories=$(echo "$decision_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for t in d.get('territories', []):
    name = t.get('name', '')
    desc = t.get('description', '')
    lens = t.get('suggested_lens', '')
    web = t.get('web_check', '')
    print(f'{name}: {desc} (suggested lens: {lens})')
    if web:
        print(f'  Web check: {web}')
print()
print('Pattern of avoidance: ' + d.get('pattern_of_avoidance', ''))
" 2>/dev/null || echo "No negative space mapped.")
    # Append to mechanism memory
    local void_rec_mem void_summary
    void_rec_mem=$(echo "$decision_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('recommendation','note_and_continue'))" 2>/dev/null || echo "note_and_continue")
    void_summary=$(echo "$decision_json" | python3 -c "import sys,json; d=json.load(sys.stdin); ts=d.get('territories',[]); print(d.get('pattern_of_avoidance','') + ' | ' + ', '.join(t.get('name','') for t in ts[:3]))" 2>/dev/null || echo "")
    append_mechanism_memory "void" "$unit_num" "$void_rec_mem" "$void_summary"
  else
    rm -f "$tmpfile"
    ALLOWED_TOOLS_FLAG="$saved_tools"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      stop_spinner "cap limit"
      return 1
    fi
    territories="No negative space mapped."
  fi
  rm -f "$tmpfile"
  ALLOWED_TOOLS_FLAG="$saved_tools"

  stop_spinner "done"

  CONVERSATION="${CONVERSATION}

=== NEGATIVE SPACE (${UNIT_LABEL} ${unit_num}) ===
The conversation has illuminated some territory and left the rest dark. These are the patches where no lens has pointed yet - the darkness between the lit areas.
${territories}"

  md_append_section 3 "🔭 Negative Space (${UNIT_LABEL} ${unit_num})"
  MD_BUFFER="${MD_BUFFER}
${territories}
"

  json_append_entry "void_mapper" "Negative Space" "🔭" "Absence Cartography" "void" "$unit_num" "$TURN_COUNT" "$territories"
  TURN_COUNT=$((TURN_COUNT + 1))

  json_flush
  md_flush
  save_state
}
