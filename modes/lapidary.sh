#!/usr/bin/env bash
# ── Lapidary composition ──
# Iterative refinement: cuts, polishes, and facets raw material through
# repeated passes, each more precise than the last.
# From the Latin lapidarius - one who works with stones.
#
# Cognitions: Evaluative (appraiser, historian, editor)
# Perceivers: empath, connoisseur, provocateur, observer, skeptic
# Child and Anxious excluded by default (mature judgement, not wild generation)
# 3 passes + ground = ~23 steps
#
# Depends on:
#   agents/cognitions/evaluative/*.sh
#   agents/hybrids/logician.sh
#   agents/perceivers/empath.sh, connoisseur.sh, provocateur.sh, observer.sh, skeptic.sh
#   context/gather.sh, context/appraise.sh
#   mechanisms/friction.sh, mechanisms/polish.sh, mechanisms/bias.sh
#   lib/call_agent.sh, lib/markers.sh

run_session() {
  UNIT_LABEL="pass"

  # Source evaluative cognitions - conditional on is_agent_active
  is_agent_active "appraiser" && source "${SCRIPT_DIR}/agents/cognitions/evaluative/appraiser.sh"
  is_agent_active "historian" && source "${SCRIPT_DIR}/agents/cognitions/evaluative/historian.sh"
  is_agent_active "editor" && source "${SCRIPT_DIR}/agents/cognitions/evaluative/editor.sh"

  # Source perceivers
  is_agent_active "empath" && source "${SCRIPT_DIR}/agents/perceivers/empath.sh"
  is_agent_active "connoisseur" && source "${SCRIPT_DIR}/agents/perceivers/connoisseur.sh"
  is_agent_active "provocateur" && source "${SCRIPT_DIR}/agents/perceivers/provocateur.sh"
  is_agent_active "observer" && source "${SCRIPT_DIR}/agents/perceivers/observer.sh"
  is_agent_active "skeptic" && source "${SCRIPT_DIR}/agents/perceivers/skeptic.sh"
  is_agent_active "logician" && source "${SCRIPT_DIR}/agents/hybrids/logician.sh"

  # Source context and mechanisms
  source "${SCRIPT_DIR}/context/gather.sh"
  source "${SCRIPT_DIR}/context/ground.sh"
  source "${SCRIPT_DIR}/context/appraise.sh"
  source "${SCRIPT_DIR}/mechanisms/friction.sh"
  source "${SCRIPT_DIR}/mechanisms/polish.sh"
  source "${SCRIPT_DIR}/mechanisms/bias.sh"

  # Gather, ground, then appraise
  gather_project_context
  ground_seed
  appraise_seed

  # Determine pass count (default 3)
  local total_passes="${PASS_COUNT:-3}"

  # ── PASS 1: Rough Cut ──
  # Establish the material, first quality judgement
  if [ "$total_passes" -ge 1 ]; then
    mark_pass 1 "Rough Cut"

    dispatch_round \
      "appraiser:weigh:1:This is the first pass. Assess the raw material. What is the weight of this seed? Where is the density? Where is it thin? Not whether it is right or wrong but whether it is substantial. Give your initial felt sense of quality and proportion." \
      "historian:root:1:What traditions does this seed sit within, whether it knows it or not? See the thousand-year-old root under the surface. Not nostalgia - lineage. What would someone who has spent decades in the relevant tradition notice that everyone else would miss?" \
      "empath:empathise:1:Before the cutting begins, anchor to the person at the centre. What do they actually feel? Not what the analysis says they should feel. What does their Wednesday afternoon look like in the middle of this problem?" \
      "observer:observe:1:What is literally here? Not interpretations. What specific words were chosen? What was described but not named? What is actually happening that the framing might be obscuring?" \
      "editor:pare:1:First cut. Look at everything that has been said so far. What is already unnecessary? What word, assumption, or framing is clutter rather than structure? Make the first removal. Show what the material looks like with less." \
      "connoisseur:evaluate:1:First quality assessment. Is this material worth making well? Not every seed is. Be honest. What is the quality of the raw material after this first rough cut? Where do you sense potential for something that could sing?"

    # Polish between passes 1 and 2
    polish 1
  fi

  # ── PASS 2: Shape ──
  # Work the surviving material harder
  if [ "$total_passes" -ge 2 ]; then
    mark_pass 2 "Shape"

    dispatch_round \
      "historian:root:2:Deeper now. The first pass revealed the material. What precedent exists for what is emerging? What has been tried before in this tradition and what was learned? See the lineage more precisely - not the obvious ancestors but the hidden ones." \
      "appraiser:weigh:2:Re-assess proportion after the first cut. Has the weight shifted? Is the material finding its natural shape or is something forcing it into a shape that does not fit? What needs more density? What is still too heavy?" \
      "provocateur:provoke:2:The material has been cut once and shaped. Challenge the politeness. What is everyone avoiding saying because they are being too careful with the material? What is the uncomfortable truth about this seed that two passes of refinement have been too gentle to state?" \
      "logician:trace:2:The material has been cut and provoked. Now trace the structure. Which elements are genuinely load-bearing and which are ornamental? If you removed each piece, what would collapse and what would stand? Follow the causal chain: what is the first-principles reason this material matters?" \
      "editor:pare:2:Second cut, sharper. The rough cut removed the obvious clutter. Now remove the less obvious. The qualification that hedges. The second example that weakens the first. The structural element that is decorative. Cut until every remaining element is load-bearing." \
      "connoisseur:evaluate:2:Is this getting better? Not just different - better. Has the shaping improved the proportions or distorted them? Is the material finding its voice or losing it? Be precise about the quality trajectory."

    # Friction + polish between passes 2 and 3
    detect_prediction_errors 2
    polish 2
  fi

  # ── PASS 3: Facet ──
  # Final precision
  if [ "$total_passes" -ge 3 ]; then
    mark_pass 3 "Facet"

    dispatch_round \
      "appraiser:weigh:3:Final proportion check. Three passes of working this material. Is the balance right? Does it have the weight of conviction or the lightness of convenience? State your assessment with the precision this final pass demands." \
      "historian:root:3:Take the ten-year view. Where does what has emerged sit in the longer arc? Not just what tradition it comes from but where it points. Is this something that will matter in a decade or is it a fashion? Root the final assessment in time." \
      "skeptic:question:3:Three passes of refinement. What assumption has survived every pass unchallenged? What is everyone walking past because the cutting has been too respectful of it? What is in plain sight but invisible because of how the material has been worked?" \
      "editor:pare:3:Final cut. Every word must be load-bearing. Every element structural. This is the pass where good becomes accomplished. Remove the last thing that is not the thing. Show the finished shape." \
      "connoisseur:evaluate:3:Final verdict. Is this finished or merely stopped? Not perfect - finished. Does it have the quality of something made with care and attention? Would you want to live with it? Is it ready to leave the workshop?"

    # Bias check before ground
    detect_cognitive_bias 3
  fi

  # ── Additional passes if --passes > 3 ──
  local p=4
  while [ "$p" -le "$total_passes" ]; do
    mark_pass "$p" "Extended Refinement"

    dispatch_round \
      "appraiser:weigh:${p}:Pass ${p}. Re-assess the material with fresh eyes. What has changed? What needs more work?" \
      "historian:root:${p}:Pass ${p}. What deeper precedent is visible now?" \
      "editor:pare:${p}:Pass ${p}. Another cut. What can still be removed without losing meaning?" \
      "connoisseur:evaluate:${p}:Pass ${p}. Quality check. Is the material still improving or has it begun to lose life?"

    detect_prediction_errors "$p"
    polish "$p"
    p=$((p + 1))
  done

  # ── GROUND ──
  # Empath -> Editor: warm landing, then final precision
  echo ""
  echo "  ━━━ GROUNDING ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  md_append_section 2 "Grounding"

  local final_pass="$total_passes"
  mark_phase "Ground" "Landing the Insight"
  if is_agent_active "empath"; then
    call_agent "empath" "ground" "$final_pass" "The session is ending. Three passes of refinement have shaped this material. Forget the craft for a moment. What does the person at the centre of this actually need? What would change their behaviour? Strip away everything and say what remains. Identify the 1-3 ideas that pass the simplicity test. For each: what is the smallest experiment someone could do tomorrow?"
  fi
  if is_agent_active "editor"; then
    call_agent "editor" "ground" "$final_pass" "Final word. The Empath has landed the insight in human terms. Now give it its final form. State the single most important insight from this session in the most precise, economical language you can. Then state it again even more simply. Both versions should be true. Make every word load-bearing."
  fi
}
