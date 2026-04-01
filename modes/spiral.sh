#!/usr/bin/env bash
# ── Spiral composition ──
# Deepening spirals: diverge, analogise, integrate, reseed
# Perceivers: empath, provocateur, observer, skeptic, includer, achala, mortal, mouth
# 3 spirals, each ~10 turns + ground = ~34 steps
#
# Depends on:
#   lenses/cognitions/deepening/*.sh
#   lenses/perceivers/empath.sh, provocateur.sh, observer.sh, skeptic.sh
#   context/gather.sh, context/tune.sh
#   mechanisms/friction.sh, mechanisms/reseed.sh, mechanisms/bias.sh

run_session() {
  UNIT_LABEL="spiral"

  # Source lenses - conditional on is_lens_active
  is_lens_active "diverger" && source "${SCRIPT_DIR}/lenses/cognitions/deepening/diverger.sh"
  is_lens_active "analogiser" && source "${SCRIPT_DIR}/lenses/cognitions/deepening/analogiser.sh"
  is_lens_active "integrator" && source "${SCRIPT_DIR}/lenses/cognitions/deepening/integrator.sh"
  is_lens_active "empath" && source "${SCRIPT_DIR}/lenses/perceivers/empath.sh"
  is_lens_active "provocateur" && source "${SCRIPT_DIR}/lenses/perceivers/provocateur.sh"
  is_lens_active "observer" && source "${SCRIPT_DIR}/lenses/perceivers/observer.sh"
  is_lens_active "skeptic" && source "${SCRIPT_DIR}/lenses/perceivers/skeptic.sh"
  is_lens_active "includer" && source "${SCRIPT_DIR}/lenses/perceivers/includer.sh"
  is_lens_active "achala" && source "${SCRIPT_DIR}/lenses/perceivers/achala.sh"
  is_lens_active "mortal" && source "${SCRIPT_DIR}/lenses/perceivers/mortal.sh"
  is_lens_active "mouth" && source "${SCRIPT_DIR}/lenses/perceivers/mouth.sh"

  # Source context and mechanisms
  source "${SCRIPT_DIR}/context/gather.sh"
  source "${SCRIPT_DIR}/context/ground.sh"
  source "${SCRIPT_DIR}/context/tune.sh"
  source "${SCRIPT_DIR}/mechanisms/friction.sh"
  source "${SCRIPT_DIR}/mechanisms/reseed.sh"
  source "${SCRIPT_DIR}/mechanisms/bias.sh"
  source "${SCRIPT_DIR}/mechanisms/transcendence.sh"
  source "${SCRIPT_DIR}/mechanisms/negative_space.sh"

  # Gather context, then tune (grounding is embedded in tuning)
  gather_project_context || true
  [ "$RATE_LIMIT_HIT" = "true" ] && return 0
  tune_seed || true
  [ "$RATE_LIMIT_HIT" = "true" ] && return 0

  # Determine spiral count (default 3)
  local total_spirals="${SPIRAL_COUNT:-5}"

  # ── SPIRAL 1 ──
  if [ "$total_spirals" -ge 1 ]; then
    mark_spiral 1

    mark_phase "Diverge" "Opening Territory"
    dispatch_round \
      "diverger:diverge:1:This is the DRIFT phase. Open up the territory. Follow the most surprising thread, not the most sensible one. Be maximally divergent. If the lens context suggests interesting starting points, use them only if they genuinely pull you." \
      "analogiser:diverge:1:The Diverger has opened a door. Walk through it but veer in your own direction. What structural rhyme do you see between what they are describing and something from a completely different domain?" \
      "diverger:diverge:1:Still drifting. Build on what has emerged but take it somewhere nobody expects. Make an associative leap. Connect through texture, feeling, or sensation rather than logic."
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Bridge" "Finding Analogies"
    dispatch_round \
      "analogiser:bridge:1:Find the deepest structural analogy you can between what has been discussed and something from a domain nobody has mentioned yet. The analogy should work at the level of deep structure, not surface resemblance." \
      "diverger:bridge:1:The Analogiser has built a bridge to a new domain. Cross it. What is on the other side that even they did not expect?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Feel" "Human Reality"
    dispatch_round \
      "empath:feel:1:REALITY CHECK. The conversation has been drifting and bridging. Before we go deeper, bring everyone back to the human being at the centre. What do they actually feel? What would they make of this so far?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Include" "Who's Not Here"
    dispatch_round \
      "includer:include:1:The Empath just anchored to a human being at the centre. Now look at the chairs around them. Who else is affected? Who is absent from this conversation that would change its direction if they were here?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Provoke" "Uncomfortable Truth"
    dispatch_round \
      "provocateur:provoke:1:Take the strongest emerging idea from the conversation and compress it into something uncomfortable. What is the version nobody wants to hear? Say it plainly."
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Observe" "What's Actually There"
    dispatch_round \
      "observer:observe:1:What has actually been said versus what has been implied? What specific claims were made that nobody checked? What is literally true here?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Integrate" "Naming the Unnamed"
    dispatch_round \
      "integrator:integrate:1:CRYSTALLISE. Name the thing that is forming in the negative space between these positions. Find the insight none of the individual lenses could have reached. If you can coin a term or identify a productive paradox, do it. This will be used to re-seed the next spiral."
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

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
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Bridge" "Cross-Spiral Analogy"
    dispatch_round \
      "analogiser:bridge:2:Two spirals of material. Find a structural rhyme that spans both, something that connects the early drift to the current territory through a domain nobody has touched." \
      "diverger:bridge:2:What is on the far side of the Analogiser's bridge that surprises even you?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Feel" "Deep Human Reality"
    dispatch_round \
      "empath:feel:2:Two spirals in. What would the person at the centre actually do with any of this? Is there a radical simplification that compresses the best thinking into something someone would actually use, do, or feel?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Devote" "What's Worth Giving Yourself To"
    dispatch_round \
      "achala:devotion:2:The Empath anchored to feelings. Go deeper. What would the person at the centre sacrifice for? What are they devoted to that the conversation has been treating as a mere preference? What is the love that powers this situation?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Urgency" "The Cost of Waiting"
    dispatch_round \
      "mortal:urgency:2:Achala named what is sacred. Now name the cost of not acting on it. Two spirals of exploration - what is being deferred while the conversation deepens? If the person at the centre had one year, not a career, which ideas survive?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Provoke" "Demolish Foundations"
    dispatch_round \
      "provocateur:provoke:2:The conversation has been building something across two spirals. What if the entire direction of travel is wrong? Say it plainly."
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Integrate" "Cross-Spiral Pattern"
    dispatch_round \
      "integrator:integrate:2:Two spirals of thinking. What has emerged that nobody planned? What pattern is forming across the spirals themselves, not just within them? Name it precisely."
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    # Friction + void + transcendence + reseed
    detect_prediction_errors 2 || true
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0
    handle_friction_decision 2
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0
    map_negative_space 2 || true
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0
    handle_negative_space_decision 2
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0
    # Transcendence moved to after spiral 3 in extended spirals loop
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
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Bridge" "Final Bridge"
    dispatch_round \
      "analogiser:bridge:3:Final bridge. Find the single analogy that ties the entire session together across all three spirals." \
      "diverger:bridge:3:What is the landscape on the far side of this final bridge? What can you see now that was invisible from where we started?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Feel" "Final Human Reality"
    dispatch_round \
      "empath:feel:3:Three spirals of exploration. Forget the metaphors. What does the person at the centre of this seed actually need? What is the one-sentence reframe? Compress ruthlessly."
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Devote" "What Makes This Worth Doing"
    dispatch_round \
      "achala:devotion:3:Three spirals of exploration. Everything is connected to everything else. Name the connection that matters most, the one that makes this worth doing, not just worth solving."
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Urgency" "The Price of Delay"
    dispatch_round \
      "mortal:urgency:3:Three spirals of exploration. Achala named what matters most. Now name what is lost with every week this stays theoretical. If everything the conversation has uncovered is true, what is the cost of waiting measured in lived human time?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Question" "Incongruence Check"
    dispatch_round \
      "skeptic:question:3:After three spirals, what is the one assumption that has survived every challenge unchallenged? The thing everyone has taken for granted? What is in plain sight but invisible because of how everyone is looking?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Register" "Is It Alive"
    dispatch_round \
      "mouth:register:3:Three spirals of thinking. Read the emerging insight aloud in your head. Is it alive? Does it sound like something a person would say to another person, or does it sound like a deck? If the spiralling has produced safe, sanitised language, say it again the way it needs to sound."
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    # Bias check before integration
    detect_cognitive_bias 3 || true
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Integrate" "Final Crystallisation"
    dispatch_round \
      "integrator:integrate:3:Three spirals complete. The full arc is visible. What is the deepest insight, the one that could only have emerged from this specific sequence of collisions? Name it. Can you state it simply enough that the person at the centre would recognise their own experience?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Register" "Final Voice Check"
    dispatch_round \
      "mouth:register:3:The Integrator just crystallised three spirals into an insight. Listen to it. Is it alive or has the crystallisation killed the voice? If it sounds like a conclusion instead of a conviction, re-voice it. If it sounds like something someone would actually say out loud to another person, bless it and move on."
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0
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
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Bridge" "Extended Bridge"
    dispatch_round \
      "analogiser:bridge:${s}:Find a structural rhyme that spans all ${s} spirals." \
      "diverger:bridge:${s}:Cross the bridge. What is on the other side?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Feel" "Human Reality"
    dispatch_round \
      "empath:feel:${s}:What does the person at the centre actually need? Compress ruthlessly."
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    mark_phase "Question" "Incongruence Check"
    dispatch_round \
      "skeptic:question:${s}:What assumption has survived unchallenged? What is everyone walking past?"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    detect_prediction_errors "$s" || true
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0
    handle_friction_decision "$s"
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0
    detect_cognitive_bias "$s" || true
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    # Transcendence + void checks from spiral 3 onwards
    if [ "$s" -ge 3 ]; then
      if [ "$NEGATIVE_SPACE_ENABLED" = "true" ]; then
        map_negative_space "$s" || true
        [ "$RATE_LIMIT_HIT" = "true" ] && return 0
        handle_negative_space_decision "$s"
        [ "$RATE_LIMIT_HIT" = "true" ] && return 0
      fi
      if [ "$TRANSCENDENCE_ENABLED" = "true" ]; then
        transcendence_check "$s" || true
        [ "$RATE_LIMIT_HIT" = "true" ] && return 0
        handle_transcendence_decision
        if [ "$MECHANISM_SKIP_TO_GROUND" = "true" ]; then
          s=$((s + 1))
          break
        fi
      fi
    fi

    mark_phase "Integrate" "Crystallisation"
    dispatch_round \
      "integrator:integrate:${s}:Name the deepest insight from this spiral. State it simply."
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0

    s=$((s + 1))
  done

  # ── GROUND ──
  echo ""
  echo "  ━━━ GROUNDING ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  md_append_section 2 "Grounding"

  local final_spiral="$total_spirals"
  mark_phase "Ground" "Landing the Insight"
  if is_lens_active "empath"; then
    call_lens "empath" "ground" "$final_spiral" "The session is ending. What is new here? What would actually change behaviour? Strip away every metaphor and say what remains. Identify the 1-3 ideas that pass the simplicity test. For each one: what is the smallest experiment someone could do tomorrow?" || true
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0
  fi
  if is_lens_active "mouth"; then
    call_lens "mouth" "ground" "$final_spiral" "Final register gate. The Empath has grounded the insight. Listen. Did the grounding kill the voice? Did making it actionable make it dead? If the register survived, leave it alone. If the grounding sanded off the edge that was the whole point, re-voice it with the edge intact. This is the last gate before output." || true
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0
  fi
  if is_lens_active "integrator"; then
    call_lens "integrator" "ground" "$final_spiral" "Final word. Name the single most important insight. State it simply. Then state it even more simply. Make it count." || true
    [ "$RATE_LIMIT_HIT" = "true" ] && return 0
  fi
}
