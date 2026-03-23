#!/usr/bin/env bash
# ── Spiral composition ──
# Deepening spirals: diverge, analogise, integrate, reseed
# Perceivers: empath, provocateur, observer, skeptic, includer
# 3 spirals, each ~10 turns + ground = ~34 steps
#
# Depends on:
#   agents/cognitions/deepening/*.sh
#   agents/perceivers/empath.sh, provocateur.sh, observer.sh, skeptic.sh
#   context/gather.sh, context/tune.sh
#   mechanisms/friction.sh, mechanisms/reseed.sh, mechanisms/bias.sh

run_session() {
  UNIT_LABEL="spiral"

  # Source agents - conditional on is_agent_active
  is_agent_active "diverger" && source "${SCRIPT_DIR}/agents/cognitions/deepening/diverger.sh"
  is_agent_active "analogiser" && source "${SCRIPT_DIR}/agents/cognitions/deepening/analogiser.sh"
  is_agent_active "integrator" && source "${SCRIPT_DIR}/agents/cognitions/deepening/integrator.sh"
  is_agent_active "empath" && source "${SCRIPT_DIR}/agents/perceivers/empath.sh"
  is_agent_active "provocateur" && source "${SCRIPT_DIR}/agents/perceivers/provocateur.sh"
  is_agent_active "observer" && source "${SCRIPT_DIR}/agents/perceivers/observer.sh"
  is_agent_active "skeptic" && source "${SCRIPT_DIR}/agents/perceivers/skeptic.sh"
  is_agent_active "includer" && source "${SCRIPT_DIR}/agents/perceivers/includer.sh"

  # Source context and mechanisms
  source "${SCRIPT_DIR}/context/gather.sh"
  source "${SCRIPT_DIR}/context/ground.sh"
  source "${SCRIPT_DIR}/context/tune.sh"
  source "${SCRIPT_DIR}/mechanisms/friction.sh"
  source "${SCRIPT_DIR}/mechanisms/reseed.sh"
  source "${SCRIPT_DIR}/mechanisms/bias.sh"

  # Gather, ground, then tune
  gather_project_context
  ground_seed
  tune_seed

  # Determine spiral count (default 3)
  local total_spirals="${SPIRAL_COUNT:-3}"

  # ── SPIRAL 1 ──
  if [ "$total_spirals" -ge 1 ]; then
    mark_spiral 1

    mark_phase "Diverge" "Opening Territory"
    dispatch_round \
      "diverger:diverge:1:This is the DRIFT phase. Open up the territory. Follow the most surprising thread, not the most sensible one. Be maximally divergent. If the lens context suggests interesting starting points, use them only if they genuinely pull you." \
      "analogiser:diverge:1:The Diverger has opened a door. Walk through it but veer in your own direction. What structural rhyme do you see between what they are describing and something from a completely different domain?" \
      "diverger:diverge:1:Still drifting. Build on what has emerged but take it somewhere nobody expects. Make an associative leap. Connect through texture, feeling, or sensation rather than logic."

    mark_phase "Bridge" "Finding Analogies"
    dispatch_round \
      "analogiser:bridge:1:Find the deepest structural analogy you can between what has been discussed and something from a domain nobody has mentioned yet. The analogy should work at the level of deep structure, not surface resemblance." \
      "diverger:bridge:1:The Analogiser has built a bridge to a new domain. Cross it. What is on the other side that even they did not expect?"

    mark_phase "Feel" "Human Reality"
    dispatch_round \
      "empath:feel:1:REALITY CHECK. The conversation has been drifting and bridging. Before we go deeper, bring everyone back to the human being at the centre. What do they actually feel? What would they make of this so far?"

    mark_phase "Include" "Who's Not Here"
    dispatch_round \
      "includer:include:1:The Empath just anchored to a human being at the centre. Now look at the chairs around them. Who else is affected? Who is absent from this conversation that would change its direction if they were here?"

    mark_phase "Provoke" "Uncomfortable Truth"
    dispatch_round \
      "provocateur:provoke:1:Take the strongest emerging idea from the conversation and compress it into something uncomfortable. What is the version nobody wants to hear? Say it plainly."

    mark_phase "Observe" "What's Actually There"
    dispatch_round \
      "observer:observe:1:What has actually been said versus what has been implied? What specific claims were made that nobody checked? What is literally true here?"

    mark_phase "Integrate" "Naming the Unnamed"
    dispatch_round \
      "integrator:integrate:1:CRYSTALLISE. Name the thing that is forming in the negative space between these positions. Find the insight none of the individual agents could have reached. If you can coin a term or identify a productive paradox, do it. This will be used to re-seed the next spiral."

    # Reseed
    if [ "$total_spirals" -ge 2 ]; then
      local RESEED_1
      RESEED_1=$(extract_reseed 1)
      reseed 2 "$RESEED_1"
    fi
  fi

  # ── SPIRAL 2 ──
  if [ "$total_spirals" -ge 2 ]; then
    mark_spiral 2

    mark_phase "Diverge" "Deeper Territory"
    dispatch_round \
      "diverger:diverge:2:New spiral. A re-seed has been provided from the previous spiral's synthesis. Let it pull you somewhere entirely unexpected. Do not continue the previous direction. Use the re-seed as a springboard to new territory." \
      "skeptic:diverge:2:How is this conversation thinking? What lens is it using without realising? What would look completely different if you stopped looking at it the way everyone else is?" \
      "diverger:diverge:2:Keep drifting. What is the strangest, most lateral connection you can make from everything across both spirals?"

    mark_phase "Bridge" "Cross-Spiral Analogy"
    dispatch_round \
      "analogiser:bridge:2:Two spirals of material. Find a structural rhyme that spans both, something that connects the early drift to the current territory through a domain nobody has touched." \
      "diverger:bridge:2:What is on the far side of the Analogiser's bridge that surprises even you?"

    mark_phase "Feel" "Deep Human Reality"
    dispatch_round \
      "empath:feel:2:Two spirals in. What would the person at the centre actually do with any of this? Is there a radical simplification that compresses the best thinking into something someone would actually use, do, or feel?"

    mark_phase "Provoke" "Demolish Foundations"
    dispatch_round \
      "provocateur:provoke:2:The conversation has been building something across two spirals. What if the entire direction of travel is wrong? Say it plainly."

    mark_phase "Integrate" "Cross-Spiral Pattern"
    dispatch_round \
      "integrator:integrate:2:Two spirals of thinking. What has emerged that nobody planned? What pattern is forming across the spirals themselves, not just within them? Name it precisely."

    # Friction + reseed
    detect_prediction_errors 2
    if [ "$total_spirals" -ge 3 ]; then
      local RESEED_2
      RESEED_2=$(extract_reseed 2)
      reseed 3 "$RESEED_2"
    fi
  fi

  # ── SPIRAL 3 ──
  if [ "$total_spirals" -ge 3 ]; then
    mark_spiral 3

    mark_phase "Diverge" "Deepest Territory"
    dispatch_round \
      "diverger:diverge:3:Third and final spiral. Go deeper than before. What has been hiding underneath everything? What is the thing beneath the thing?" \
      "analogiser:diverge:3:Third spiral. The pattern has had time to develop across two full cycles. What deep structure do you see now that was invisible in spiral 1?" \
      "diverger:diverge:3:Final drift. Make the most daring, potentially wrong associative leap you can. Risk being ridiculous."

    mark_phase "Bridge" "Final Bridge"
    dispatch_round \
      "analogiser:bridge:3:Final bridge. Find the single analogy that ties the entire session together across all three spirals." \
      "diverger:bridge:3:What is the landscape on the far side of this final bridge? What can you see now that was invisible from where we started?"

    mark_phase "Feel" "Final Human Reality"
    dispatch_round \
      "empath:feel:3:Three spirals of exploration. Forget the metaphors. What does the person at the centre of this seed actually need? What is the one-sentence reframe? Compress ruthlessly."

    mark_phase "Question" "Incongruence Check"
    dispatch_round \
      "skeptic:question:3:After three spirals, what is the one assumption that has survived every challenge unchallenged? The thing everyone has taken for granted? What is in plain sight but invisible because of how everyone is looking?"

    # Bias check before integration
    detect_cognitive_bias 3

    mark_phase "Integrate" "Final Crystallisation"
    dispatch_round \
      "integrator:integrate:3:Three spirals complete. The full arc is visible. What is the deepest insight, the one that could only have emerged from this specific sequence of collisions? Name it. Can you state it simply enough that the person at the centre would recognise their own experience?"
  fi

  # ── Additional spirals if --spirals > 3 ──
  local s=4
  while [ "$s" -le "$total_spirals" ]; do
    mark_spiral "$s"

    local PREV_RESEED
    PREV_RESEED=$(extract_reseed $((s - 1)))
    reseed "$s" "$PREV_RESEED"

    mark_phase "Diverge" "Extended Territory"
    dispatch_round \
      "diverger:diverge:${s}:Spiral ${s}. The re-seed from the previous spiral is your springboard. Go somewhere nobody has been." \
      "analogiser:diverge:${s}:Spiral ${s}. What deep structure is visible now that was invisible before?" \
      "diverger:diverge:${s}:Keep drifting. Risk being ridiculous."

    mark_phase "Bridge" "Extended Bridge"
    dispatch_round \
      "analogiser:bridge:${s}:Find a structural rhyme that spans all ${s} spirals." \
      "diverger:bridge:${s}:Cross the bridge. What is on the other side?"

    mark_phase "Feel" "Human Reality"
    dispatch_round \
      "empath:feel:${s}:What does the person at the centre actually need? Compress ruthlessly."

    mark_phase "Question" "Incongruence Check"
    dispatch_round \
      "skeptic:question:${s}:What assumption has survived unchallenged? What is everyone walking past?"

    detect_prediction_errors "$s"
    detect_cognitive_bias "$s"

    mark_phase "Integrate" "Crystallisation"
    dispatch_round \
      "integrator:integrate:${s}:Name the deepest insight from this spiral. State it simply."

    s=$((s + 1))
  done

  # ── GROUND ──
  echo ""
  echo "  ━━━ GROUNDING ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  md_append_section 2 "Grounding"

  local final_spiral="$total_spirals"
  mark_phase "Ground" "Landing the Insight"
  if is_agent_active "empath"; then
    call_agent "empath" "ground" "$final_spiral" "The session is ending. What is new here? What would actually change behaviour? Strip away every metaphor and say what remains. Identify the 1-3 ideas that pass the simplicity test. For each one: what is the smallest experiment someone could do tomorrow?"
  fi
  if is_agent_active "integrator"; then
    call_agent "integrator" "ground" "$final_spiral" "Final word. Name the single most important insight. State it simply. Then state it even more simply. Make it count."
  fi
}
