#!/usr/bin/env bash
# ── Session reviewer (adversarial) ──
# Post-composition quality gate with external anchoring.
# Uses a prosecution/defense/verdict pattern to counter self-evaluation bias.
# The prosecution assumes the session failed and searches for prior art.
# The defense concedes weak ideas and argues only for genuine divergence.
# The verdict decides restart/proceed from the adversarial exchange.
# Can trigger a restart with mutations (different mode, shuffled order, reframed seed).
# 2-run ceiling per provocation to prevent infinite loops.
# Expects globals: $THINKING_SESSION, $SEED_TOPIC, $MODE, $ALLOWED_TOOLS_FLAG
# Depends on: lib/cap_check.sh

SESSION_REVIEW_DECISION=""
SESSION_REVIEW_RUN_COUNT=0

# ── Phase 1: Prosecution ──
# Assumes the session produced conventional thinking and searches for proof.
review_prosecute() {
  local prosecution_prompt="You are a cynical strategy director who has seen every framework produce the same platitudes dressed in creative language. Your job is to find what is CONVENTIONAL in this session's output.

For each major idea or insight in the session:
1. Name the closest existing article, strategy deck, book chapter, or TED talk that says essentially the same thing
2. Explain why this is not genuinely new thinking, just repackaged wisdom
3. Search the web for similar ideas to confirm they already exist

Score the session's genuine novelty on a 1-10 scale where:
- 1-3: This is literally a summary of existing thinking
- 4-5: Any smart strategist would arrive here without a framework
- 6-7: There are genuinely unusual combinations or framings, even if individual elements exist
- 8-10: I have never seen this exact constellation of ideas before

Be harsh. Your job is not to be fair, it is to be honest about conventionality. If the session just says obvious things in unusual language, that is a 3, not a 7.

SEED TOPIC: ${SEED_TOPIC}
${ZEITGEIST_CONTEXT:+
${ZEITGEIST_CONTEXT}
These sources were captured during provocation generation. Use them as a head start - if the session is only reaching territory these articles already cover, the novelty score should reflect that.
}
THINKING SESSION:
$(get_conversation_for "mechanism")

Respond with a JSON object."

  local prosecution_schema='{"type":"object","properties":{"novelty_score":{"type":"number"},"conventional_ideas":{"type":"array","items":{"type":"object","properties":{"idea":{"type":"string"},"prior_art":{"type":"string"}},"required":["idea","prior_art"]}},"genuinely_new":{"type":"array","items":{"type":"string"}},"overall_assessment":{"type":"string"}},"required":["novelty_score","conventional_ideas","overall_assessment"]}'

  local tmpfile
  tmpfile=$(mktemp)
  echo "$prosecution_prompt" > "$tmpfile"

  local result=""
  VERBOSE_CALLER="review:prosecution"
  if claude_call_json "$tmpfile" "$prosecution_schema" ""; then
    result="$CLAUDE_RESPONSE"
  fi
  rm -f "$tmpfile"
  echo "$result"
}

# ── Phase 2: Defense ──
# Receives the prosecution's critique and defends only what genuinely diverges.
review_defend() {
  local prosecution_result="$1"

  local defense_prompt="You are defending a creative thinking session's output against a harsh prosecution. The prosecution has identified what it considers conventional about the session.

Your job is NOT to defend everything. You should:
1. CONCEDE ideas that are genuinely conventional - agree with the prosecution where it is right
2. DEFEND only what actually diverges from existing thinking - show why specific framings, combinations, or tensions are genuinely different from the prior art cited
3. Identify what the prosecution MISSED - tensions, contradictions, or emergent connections that the prosecution treated as conventional but are actually doing something new

Do not be defensive. Do not inflate. The strongest defense is one that concedes the weak ideas and fights only for what is genuinely worth keeping.

SEED TOPIC: ${SEED_TOPIC}

PROSECUTION'S CASE:
${prosecution_result}

THINKING SESSION:
$(get_conversation_for "mechanism")

Respond with a JSON object."

  local defense_schema='{"type":"object","properties":{"concessions":{"type":"array","items":{"type":"string"}},"defenses":{"type":"array","items":{"type":"object","properties":{"idea":{"type":"string"},"why_genuinely_different":{"type":"string"}},"required":["idea","why_genuinely_different"]}},"missed_by_prosecution":{"type":"array","items":{"type":"string"}},"honest_novelty_score":{"type":"number"}},"required":["concessions","defenses","honest_novelty_score"]}'

  local tmpfile
  tmpfile=$(mktemp)
  echo "$defense_prompt" > "$tmpfile"

  local result=""
  VERBOSE_CALLER="review:defense"
  if claude_call_json "$tmpfile" "$defense_schema" ""; then
    result="$CLAUDE_RESPONSE"
  fi
  rm -f "$tmpfile"
  echo "$result"
}

# ── Phase 3: Verdict ──
# Reads both prosecution and defense, makes the final call.
review_verdict() {
  local prosecution_result="$1"
  local defense_result="$2"

  local verdict_prompt="You are the final judge in an adversarial review of a creative thinking session. You have read both the prosecution (which assumed the session failed) and the defense (which conceded weak ideas and fought for genuinely novel ones).

Based on both arguments, determine:
1. VERDICT: Should this session proceed to presentation, or restart with mutations?
   - 'proceed' if the defense successfully showed genuine novelty worth presenting
   - 'restart' if the prosecution's case stands and the session needs to push further
2. BASELINE DELTA: In one sentence, what does this session say that a smart strategist without the framework would NOT say?
3. UNPUSHED TENSIONS: Which contradictions or tensions were noticed but not followed to their breaking point?
4. REFRAMED SEED: If restart is needed, provide a reframed seed that forces the session into territory it avoided

PROSECUTION:
${prosecution_result}

DEFENSE:
${defense_result}

Respond with a JSON object."

  local verdict_schema='{"type":"object","properties":{"verdict":{"type":"string","enum":["proceed","restart"]},"baseline_delta":{"type":"string"},"novelty_check":{"type":"string"},"unpushed_tensions":{"type":"array","items":{"type":"string"}},"reframed_seed":{"type":"string"}},"required":["verdict","baseline_delta","novelty_check","unpushed_tensions"]}'

  local tmpfile
  tmpfile=$(mktemp)
  echo "$verdict_prompt" > "$tmpfile"

  local result=""
  VERBOSE_CALLER="review:verdict"
  if claude_call_json "$tmpfile" "$verdict_schema" ""; then
    result="$CLAUDE_RESPONSE"
  fi
  rm -f "$tmpfile"
  echo "$result"
}

# ── Main review orchestrator ──
review_session() {
  SESSION_REVIEW_DECISION=""
  start_spinner "🔍 Reviewing session (prosecution)"

  # Temporarily ensure tools are available for the novelty search
  local saved_tools="$ALLOWED_TOOLS_FLAG"
  ALLOWED_TOOLS_FLAG="--allowedTools WebSearch,WebFetch"

  # Phase 1: Prosecution
  local prosecution_result
  prosecution_result=$(review_prosecute)

  if [ -z "$prosecution_result" ]; then
    ALLOWED_TOOLS_FLAG="$saved_tools"
    if [ "$RATE_LIMIT_HIT" = "true" ]; then
      stop_spinner "rate limit"
      return 1
    fi
    stop_spinner "failed (proceeding anyway)"
    SESSION_REVIEW_DECISION='{"verdict":"proceed"}'
    return
  fi

  stop_spinner "done"

  # Phase 2: Defense
  start_spinner "🔍 Reviewing session (defense)"
  local defense_result
  defense_result=$(review_defend "$prosecution_result")

  if [ -z "$defense_result" ]; then
    ALLOWED_TOOLS_FLAG="$saved_tools"
    if [ "$RATE_LIMIT_HIT" = "true" ]; then
      stop_spinner "rate limit"
      return 1
    fi
    stop_spinner "failed (proceeding anyway)"
    SESSION_REVIEW_DECISION='{"verdict":"proceed"}'
    return
  fi

  stop_spinner "done"

  # Phase 3: Verdict
  start_spinner "🔍 Reviewing session (verdict)"
  ALLOWED_TOOLS_FLAG="$saved_tools"

  local verdict_result
  verdict_result=$(review_verdict "$prosecution_result" "$defense_result")

  if [ -z "$verdict_result" ]; then
    if [ "$RATE_LIMIT_HIT" = "true" ]; then
      stop_spinner "rate limit"
      return 1
    fi
    stop_spinner "failed (proceeding anyway)"
    SESSION_REVIEW_DECISION='{"verdict":"proceed"}'
    return
  fi

  SESSION_REVIEW_DECISION="$verdict_result"

  local verdict
  verdict=$(echo "$SESSION_REVIEW_DECISION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('verdict','proceed'))" 2>/dev/null || echo "proceed")

  local baseline_delta
  baseline_delta=$(echo "$SESSION_REVIEW_DECISION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('baseline_delta',''))" 2>/dev/null || echo "")

  local novelty_check
  novelty_check=$(echo "$SESSION_REVIEW_DECISION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('novelty_check',''))" 2>/dev/null || echo "")

  stop_spinner "done"

  echo ""
  echo "  ━━━ SESSION REVIEW (adversarial) ━━━━━━━━━"
  echo "  Verdict: ${verdict}"
  echo "  Baseline delta: ${baseline_delta:0:120}"
  echo "  Novelty: ${novelty_check:0:120}"

  # Log prosecution score if available
  local prosecution_score
  prosecution_score=$(echo "$prosecution_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('novelty_score','?'))" 2>/dev/null || echo "?")
  local defense_score
  defense_score=$(echo "$defense_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('honest_novelty_score','?'))" 2>/dev/null || echo "?")
  echo "  Novelty scores: prosecution=${prosecution_score}/10, defense=${defense_score}/10"

  if [ "$verdict" = "restart" ]; then
    SESSION_REVIEW_RUN_COUNT=$((SESSION_REVIEW_RUN_COUNT + 1))
    if [ "$SESSION_REVIEW_RUN_COUNT" -ge 2 ]; then
      echo "  ⚠ Restart recommended but 2-run ceiling reached. Proceeding with synthesis."
      SESSION_REVIEW_DECISION=$(echo "$SESSION_REVIEW_DECISION" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['verdict'] = 'proceed'
json.dump(d, sys.stdout)
" 2>/dev/null || echo '{"verdict":"proceed"}')
    else
      echo "  ↻ Restart recommended. Will run fresh session with mutations."
      local reframed
      reframed=$(echo "$SESSION_REVIEW_DECISION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('reframed_seed',''))" 2>/dev/null || echo "")
      if [ -n "$reframed" ]; then
        echo "  Reframed seed: ${reframed:0:120}"
      fi
    fi
  else
    echo "  ✓ Session survived adversarial review. Proceeding to presentation."
  fi
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# Get the review verdict
get_review_verdict() {
  [ -z "$SESSION_REVIEW_DECISION" ] && echo "proceed" && return
  echo "$SESSION_REVIEW_DECISION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('verdict','proceed'))" 2>/dev/null || echo "proceed"
}

# Get the reframed seed (if restart recommended)
get_reframed_seed() {
  [ -z "$SESSION_REVIEW_DECISION" ] && return
  echo "$SESSION_REVIEW_DECISION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('reframed_seed',''))" 2>/dev/null || echo ""
}

# Get mutation mode - if current mode produced conventional output, suggest a different one
get_mutation_mode() {
  local current_mode="$1"
  case "$current_mode" in
    dyslexic) echo "spiral" ;;
    spiral) echo "lapidary" ;;
    lapidary) echo "dyslexic" ;;
    *) echo "spiral" ;;
  esac
}
