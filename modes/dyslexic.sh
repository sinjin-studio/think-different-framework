#!/usr/bin/env bash
# ── Dyslexic composition ──
# Fragmentary thinking: decompose, associate, scale, reify
# Perceivers: empath, provocateur, observer, mortal, child, includer
# Skeptic excluded by default but can be force-included (placed in Round 3)
# ~25 lens turns + 3 friction + 1 sensory + 1 bias = ~30 steps
#
# Depends on:
#   lenses/cognitions/fragmentary/*.sh
#   lenses/hybrids/logician.sh
#   lenses/perceivers/empath.sh, provocateur.sh, observer.sh, mortal.sh, child.sh
#   context/gather.sh, context/fracture.sh
#   mechanisms/friction.sh, mechanisms/sensory.sh, mechanisms/bias.sh
#   lib/call_lens.sh, lib/markers.sh

run_session() {
  UNIT_LABEL="round"

  # Source lenses - conditional on is_lens_active
  is_lens_active "decomposer" && source "${SCRIPT_DIR}/lenses/cognitions/fragmentary/decomposer.sh"
  is_lens_active "associator" && source "${SCRIPT_DIR}/lenses/cognitions/fragmentary/associator.sh"
  is_lens_active "scaler" && source "${SCRIPT_DIR}/lenses/cognitions/fragmentary/scaler.sh"
  is_lens_active "reifier" && source "${SCRIPT_DIR}/lenses/cognitions/fragmentary/reifier.sh"
  is_lens_active "empath" && source "${SCRIPT_DIR}/lenses/perceivers/empath.sh"
  is_lens_active "provocateur" && source "${SCRIPT_DIR}/lenses/perceivers/provocateur.sh"
  is_lens_active "observer" && source "${SCRIPT_DIR}/lenses/perceivers/observer.sh"
  is_lens_active "mortal" && source "${SCRIPT_DIR}/lenses/perceivers/mortal.sh"
  is_lens_active "child" && source "${SCRIPT_DIR}/lenses/perceivers/child.sh"
  is_lens_active "includer" && source "${SCRIPT_DIR}/lenses/perceivers/includer.sh"
  is_lens_active "achala" && source "${SCRIPT_DIR}/lenses/perceivers/achala.sh"
  is_lens_active "logician" && source "${SCRIPT_DIR}/lenses/hybrids/logician.sh"

  # Skeptic: excluded by default in dyslexic, but --include skeptic overrides
  local skeptic_included="false"
  if [ ${#INCLUDE_LENSES[@]} -gt 0 ]; then
  for inc in "${INCLUDE_LENSES[@]}"; do
    [ "$inc" = "skeptic" ] && skeptic_included="true"
  done
  fi
  if [ "$skeptic_included" = "true" ]; then
    source "${SCRIPT_DIR}/lenses/perceivers/skeptic.sh"
  fi

  # Source context and mechanisms
  source "${SCRIPT_DIR}/context/gather.sh"
  source "${SCRIPT_DIR}/context/ground.sh"
  source "${SCRIPT_DIR}/context/fracture.sh"
  source "${SCRIPT_DIR}/mechanisms/friction.sh"
  source "${SCRIPT_DIR}/mechanisms/sensory.sh"
  source "${SCRIPT_DIR}/mechanisms/bias.sh"
  source "${SCRIPT_DIR}/mechanisms/transcendence.sh"
  source "${SCRIPT_DIR}/mechanisms/void.sh"

  # Gather context, then fracture (grounding is embedded in fracture)
  gather_project_context || true
  [ "$CAP_LIMIT_HIT" = "true" ] && return 0
  fracture_seed || true
  [ "$CAP_LIMIT_HIT" = "true" ] && return 0

  # Determine round count (default 4)
  local total_rounds="${ROUND_COUNT:-7}"

  # ── ROUND 1: First Fragments ──
  if [ "$total_rounds" -ge 1 ]; then
    mark_round 1 "First Fragments"

    dispatch_round \
      "decomposer:decompose:1:This is the first round. This is your moment. The conversation needs your wildest fragments more than anything else right now. Look at the seed and grab ONE fragment, one detail, one word, one edge. Examine it as if it IS the whole problem. What do you see when you look at the problem from inside this one piece?" \
      "empath:empathise:1:First reality anchor. Fragments are on the table. What does the actual person at the centre of this seed feel right now? Not what the analysis says. What does their Wednesday afternoon actually look like?" \
      "associator:associate:1:The Decomposer has pulled out a piece. Now connect it to something from a completely different world. Not an analogy. An adjacency. Something that sits next to this problem in a dimension nobody usually looks at." \
      "observer:observe:1:Look at what has actually been said. Not the interpretations. What specific words were chosen? What was described but not named? What is literally happening that the metaphors are obscuring?" \
      "includer:include:1:The conversation has started framing the problem. Before it sets, look at who has been placed at the centre and notice who has not. Who is affected by this seed but has not been imagined yet? Who did the framing forget?" \
      "decomposer:decompose:1:Grab a DIFFERENT fragment from the seed. A piece that nobody would think is important. Look at the problem from inside it. What's visible from here that's invisible from the centre?"
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0

    # Friction between rounds 1 and 2
    detect_prediction_errors 1 || true
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0
    handle_friction_decision 1
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0
  fi

  # ── ROUND 2: Scale Shift ──
  if [ "$total_rounds" -ge 2 ]; then
    mark_round 2 "Scale Shift"

    dispatch_round \
      "scaler:scale:2:This is your moment. Friction from the last round has been identified. Work with the snags, not the agreements. Change altitude radically. If it's been personal, go civilisational. If it's been abstract, drop into one specific second of one specific interaction." \
      "child:naivety:2:Look at everything the conversation has assumed so far. Ask the question nobody is asking because they think the answer is obvious. Why can't you just...? What if you didn't? What would happen if you did it backwards?" \
      "associator:associate:2:The Scaler just showed us the problem at a new altitude. What connections are visible now that were invisible before, especially connections that work with the contradictions?" \
      "provocateur:provoke:2:The conversation has been building something. Strip it. What is the uncomfortable simplification? What is everyone avoiding saying because it is too direct? Say it in as few words as possible." \
      "achala:devotion:2:The conversation has been fragmenting and scaling. Before it goes further, name the thing people would sacrifice for here. Not the stated need. The sacred thing underneath. What do people actually love about this situation, and what would it mean to honour that rather than optimise it?" \
      "logician:trace:2:The Scaler just shifted altitude twice. At this new scale, what causal chains are visible that were hidden before? Trace one forward - if this is true, what necessarily follows? Trace one backward - what is the structural root cause that nobody has named yet?" \
      "scaler:scale:2:Zoom again. The other direction. If you zoomed out last time, zoom in to the microscopic. If you zoomed in, pull up to the cosmic. The problem should look completely different from here."
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0

    # Friction + sensory check
    detect_prediction_errors 2 || true
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0
    sensory_check
  fi

  # ── ROUND 3: Deep Fragments ──
  if [ "$total_rounds" -ge 3 ]; then
    mark_round 3 "Deep Fragments"

    # Build round 3 lenses - skeptic placed here if force-included
    local round3_lenses=(
      "decomposer:decompose:3:Two rounds of thinking are loaded and friction has been identified twice. Go back to the original seed and fragment it again, but this time you see differently. The blind spots and contradictions from previous rounds are your guide. What piece of the seed looks completely different now?"
      "mortal:urgency:3:Three rounds of thinking. What is being deferred? What is the conversation assuming there is time for that there might not be? If the person at the centre had one year to act on this, which of these ideas would survive and which would fall away? Name the cost of waiting in lived time."
      "associator:associate:3:Three rounds of fragments, scale shifts, and reality checks. Two rounds of friction. What is the most daring connection you can make? Connect something from round 1 to something from round 3 through a domain nobody has mentioned."
      "observer:observe:3:Three rounds in. What has been said repeatedly that nobody has questioned? What specific claim was made that might not be literally true? What gap exists between how the situation was described and how it would actually look if you were standing there watching?"
      "empath:empathise:3:Third and most important reality check. Three rounds of fragmenting, connecting, and scaling. Two rounds of friction. Forget the cleverness. What does the person at the centre of this actually need? What's the one-sentence reframe that would make them say 'yes, that is it'?"
      "logician:trace:3:Three rounds of fragments, connections, and collisions. What is the causal structure underneath all of it? Trace the consequences of what has been uncovered - if the key insights from this session are true, what must necessarily follow that nobody has said yet? What prediction can you make?"
    )

    # Insert skeptic in Round 3 if force-included
    if [ "$skeptic_included" = "true" ]; then
      round3_lenses+=("skeptic:question:3:The conversation has been building for three rounds. You see what doesn't fit. What incongruence is everyone walking past? What is in plain sight but invisible because of how they are looking?")
    fi

    dispatch_round "${round3_lenses[@]}"
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0

    # Friction + void + bias check
    detect_prediction_errors 3 || true
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0
    map_negative_space 3 || true
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0
    handle_void_decision 3
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0
    detect_cognitive_bias 3 || true
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0
    # Transcendence moved to after round 5 in extended rounds loop
  fi

  # ── Additional middle rounds if --rounds > 4 ──
  local r=4
  while [ "$r" -lt "$total_rounds" ]; do
    mark_round "$r" "Extended Fragments"

    dispatch_round \
      "decomposer:decompose:${r}:Round ${r}. Return to the seed with everything you have learned. What fragment looks different now? What piece has been ignored?" \
      "associator:associate:${r}:Round ${r}. Connect across all previous rounds. Find the most unexpected link." \
      "scaler:scale:${r}:Round ${r}. Change altitude again. Show the problem from a distance nobody has tried." \
      "empath:empathise:${r}:Round ${r}. Reality check. What does the person at the centre actually need right now?"
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0

    detect_prediction_errors "$r" || true
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0

    # Transcendence + void checks from round 5 onwards
    if [ "$r" -ge 5 ]; then
      if [ "$VOID_ENABLED" = "true" ]; then
        map_negative_space "$r" || true
        [ "$CAP_LIMIT_HIT" = "true" ] && return 0
        handle_void_decision "$r"
        [ "$CAP_LIMIT_HIT" = "true" ] && return 0
      fi
      if [ "$TRANSCENDENCE_ENABLED" = "true" ]; then
        transcendence_check "$r" || true
        [ "$CAP_LIMIT_HIT" = "true" ] && return 0
        handle_transcendence_decision
        if [ "$MECHANISM_SKIP_TO_GROUND" = "true" ]; then
          r=$((r + 1))
          break
        fi
      fi
    fi

    r=$((r + 1))
  done

  # ── Final Round: Constellation ──
  # Always runs as the last round
  local final_round="$total_rounds"
  mark_round "$final_round" "Constellation"

  dispatch_round \
    "reifier:reify:${final_round}:This is your moment. Multiple rounds of fragments, connections, scale shifts, and reality checks. The mismatches between lenses' views are the most important signal. Step back and look at all of it. What is the constellation? What shape connects the most surprising CONTRADICTIONS, not just the agreements? Name the thing." \
    "associator:associate:${final_round}:The Reifier just drew a constellation. What adjacent thing does that constellation look like? What else in the world has this same shape? One final connection that makes the named insight feel inevitable rather than invented." \
    "achala:devotion:${final_round}:The constellation has been named. Now ask: is this worthy of devotion? Would someone give their time, their reputation, their sleep to this? If not, what would make it worthy?" \
    "mortal:urgency:${final_round}:Achala named what is sacred. Now name the cost of not acting on it. What is being lost while this remains an idea instead of a thing in the world? If this constellation is true, what is the price of another quarter of deliberation?" \
    "provocateur:provoke:${final_round}:The constellation has been named and connected. Now compress it. What is the five-word version? The version that makes the room go quiet? Not a tagline. The truth, compressed."
  [ "$CAP_LIMIT_HIT" = "true" ] && return 0

  # ── GROUND ──
  echo ""
  echo "  ━━━ GROUNDING ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  md_append_section 2 "Grounding"

  mark_phase "Ground" "Landing the Insight"
  if is_lens_active "empath"; then
    call_lens "empath" "ground" "$final_round" "This is the end. Deliver the verdict. What is new here? What would actually change behaviour, create value, solve a real problem? Strip away the metaphors. Say what remains. Identify the 1-3 ideas that pass the simplicity test. For each one: what is the smallest experiment someone could take tomorrow?" || true
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0
  fi
  if is_lens_active "reifier"; then
    call_lens "reifier" "ground" "$final_round" "Final word. State the single most important insight from this entire session. State it once with nuance. Then state it again in one sentence a child could understand. Both versions should be true. Make it portable enough to carry into real work." || true
    [ "$CAP_LIMIT_HIT" = "true" ] && return 0
  fi
}
