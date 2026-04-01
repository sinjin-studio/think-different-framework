#!/usr/bin/env bash
# ── Rate limit detection, state management, and session resumability ──
# Centralised wrapper for all `claude -p` calls.
# Detects API rate limits, saves session state for resume.
# Expects globals: $OUTPUT_DIR, $TIMESTAMP, $SEED_TOPIC, $MODE,
#                  $WORD_COUNT, $CONVERSATION, $TURN_COUNT,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON,
#                  $FRICTION_ENABLED, $BIAS_ENABLED, $SENSORY_ENABLED,
#                  $SHUFFLE_ENABLED, $CMD_NAME

# ── Rate limit detection globals ──
RATE_LIMIT_HIT=""
CLAUDE_RESPONSE=""
ALLOWED_TOOLS_FLAG=""
LAST_CLAUDE_ERROR=""
LAST_CLAUDE_EXIT_CODE=0

# ── Verbose session log globals ──
VERBOSE_LOG=""       # Path to log.jsonl - set after session dir creation
VERBOSE_CALLER=""    # Set by callers before invoking claude_call* (e.g. "lens:empath")

# ── Append a JSONL entry to the verbose log ──
# Captures: caller, call type, prompt excerpt, full response, exit code, rate limited
verbose_log_entry() {
  [ -z "$VERBOSE_LOG" ] && return
  local call_type="$1"
  local prompt_file="$2"
  local response="$3"
  local exit_code="$4"
  local rate_limited="$5"

  local prompt_excerpt=""
  if [ -f "$prompt_file" ]; then
    prompt_excerpt=$(head -c 500 "$prompt_file")
  fi

  python3 -c "
import sys, json, datetime
entry = {
    'ts': datetime.datetime.now().isoformat(timespec='seconds'),
    'caller': sys.argv[1],
    'type': sys.argv[2],
    'prompt_excerpt': sys.argv[3],
    'response': sys.argv[4],
    'exit_code': int(sys.argv[5]),
    'rate_limited': sys.argv[6] == 'true'
}
print(json.dumps(entry))
" "${VERBOSE_CALLER:-unknown}" "$call_type" "$prompt_excerpt" "$response" "$exit_code" "$rate_limited" >> "$VERBOSE_LOG" 2>/dev/null || true
}

# ── Build --allowedTools flag from ALLOWED_TOOLS global ──
build_tools_flag() {
  ALLOWED_TOOLS_FLAG=""
  if [ -n "${ALLOWED_TOOLS:-}" ]; then
    ALLOWED_TOOLS_FLAG="--allowedTools ${ALLOWED_TOOLS}"
  fi
}

# ── Resume globals ──
RESUME_FROM_TURN=0
RESUME_MODE=""
STATE_FILE=""

# ── Heuristic: does this response look like an API rate limit? ──
is_rate_limited() {
  local exit_code="$1"
  local response="$2"
  local stderr="$3"

  # Check for rate-limit strings in response or stderr (bash 3.2 compatible)
  local lower_response lower_stderr
  lower_response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
  lower_stderr=$(echo "$stderr" | tr '[:upper:]' '[:lower:]')

  local pattern
  for pattern in "rate limit" "usage limit" "extra usage" "quota" "capacity" "too many requests" "429" "overloaded" "token limit" "exceeded"; do
    case "$lower_response" in *"$pattern"*) return 0 ;; esac
    case "$lower_stderr" in *"$pattern"*) return 0 ;; esac
  done

  # Non-zero exit code with empty response suggests rate limit
  # But only if stderr also doesn't indicate a non-rate-limit error
  if [ "$exit_code" -ne 0 ]; then
    local trimmed
    trimmed=$(echo "$response" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [ -z "$trimmed" ]; then
      # Empty response + non-zero exit = likely rate limited, unless stderr says otherwise
      local has_non_rl_error="false"
      for pattern in "invalid" "parse error" "syntax" "unexpected" "permission" "not found" "timeout" "timed out" "connection"; do
        case "$lower_stderr" in *"$pattern"*) has_non_rl_error="true" ;; esac
      done
      if [ "$has_non_rl_error" = "true" ]; then
        return 1  # Non-rate-limit error
      fi
      return 0  # Empty response + exit code + no clear non-rl signal = assume rate limited
    fi
    # Non-zero exit but we got a response - not rate limited
    return 1
  fi

  # Empty or whitespace-only response with zero exit - only rate limited if stderr has content
  local trimmed
  trimmed=$(echo "$response" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  if [ -z "$trimmed" ]; then
    local trimmed_stderr
    trimmed_stderr=$(echo "$stderr" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [ -n "$trimmed_stderr" ]; then
      return 0  # Empty response + stderr content = likely rate limited
    fi
    return 1  # Empty response but no error signal - not rate limited
  fi

  return 1
}

# ── Wait for rate limit reset (polling with backoff) ──
# Called when rate limit detected and WAIT_FOR_RATE_LIMIT is enabled.
# Saves state, then polls with increasing intervals until Claude responds or 4h timeout.
# Returns: 0 if rate limit cleared, 1 if timed out (RATE_LIMIT_HIT set)
wait_for_rate_limit_reset() {
  local wait_interval=300   # Start at 5 minutes
  local max_interval=600    # Max at 10 minutes
  local interval_step=120   # +2 minutes per attempt
  local max_total=14400     # 4 hours max
  local elapsed=0
  local attempt=0
  local start_ts
  start_ts=$(date +%s)

  # Save state before entering wait loop (safe for Ctrl+C)
  save_state 2>/dev/null || true

  echo ""
  echo "  [$(date '+%H:%M:%S')] Rate limit hit. Polling for reset (max 4h)..."
  verbose_log_entry "wait_enter" "/dev/null" "entering wait loop" "0" "true"

  while [ "$elapsed" -lt "$max_total" ]; do
    attempt=$((attempt + 1))
    local wait_min=$((wait_interval / 60))
    echo "  [$(date '+%H:%M:%S')] Attempt ${attempt} - waiting ${wait_min}m..."

    sleep "$wait_interval" || true

    # Probe with minimal call
    local probe_response=""
    local probe_exit=0
    local probe_stderr_file
    probe_stderr_file=$(mktemp)
    probe_response=$(echo "ping" | claude -p --system-prompt "Reply with exactly: pong" 2>"$probe_stderr_file") || probe_exit=$?
    local probe_stderr
    probe_stderr=$(cat "$probe_stderr_file")
    rm -f "$probe_stderr_file"

    elapsed=$(( $(date +%s) - start_ts ))
    local elapsed_min=$((elapsed / 60))

    if ! is_rate_limited "$probe_exit" "$probe_response" "$probe_stderr"; then
      echo "  [$(date '+%H:%M:%S')] Probe succeeded! Resuming session. Total wait: ${elapsed_min}m, ${attempt} attempts."
      echo ""
      verbose_log_entry "wait_success" "/dev/null" "rate limit reset after ${elapsed_min}m" "0" "false"
      LAST_CLAUDE_ERROR=""
      LAST_CLAUDE_EXIT_CODE=0
      return 0
    fi

    # Calculate next interval
    local next_interval=$((wait_interval + interval_step))
    if [ "$next_interval" -gt "$max_interval" ]; then
      next_interval="$max_interval"
    fi
    local next_min=$((next_interval / 60))
    echo "  [$(date '+%H:%M:%S')] Probe failed. Elapsed: ${elapsed_min}m. Next in ${next_min}m."

    wait_interval="$next_interval"
  done

  # Timed out
  local total_min=$((max_total / 60))
  echo "  [$(date '+%H:%M:%S')] Waited ${total_min}m. Giving up."
  verbose_log_entry "wait_timeout" "/dev/null" "timed out after ${total_min}m" "1" "true"
  RATE_LIMIT_HIT="true"
  return 1
}

# ── Wrapper for claude -p calls with structured JSON output ──
# Usage: claude_call_json "$tmpfile" "$json_schema" ["$system_prompt"]
# Sets: CLAUDE_RESPONSE (raw JSON string)
# Returns: 0 on success, 1 on failure
claude_call_json() {
  local tmpfile="$1"
  local json_schema="$2"
  local system_prompt="${3:-}"
  local _retried=0

  while true; do
    local stderr_file
    stderr_file=$(mktemp)

    local exit_code=0
    local raw_response=""
    if [ -n "$system_prompt" ]; then
      raw_response=$(cat "$tmpfile" | claude -p --system-prompt "$system_prompt" --json-schema "$json_schema" --output-format json $ALLOWED_TOOLS_FLAG 2>"$stderr_file") || exit_code=$?
    else
      raw_response=$(cat "$tmpfile" | claude -p --json-schema "$json_schema" --output-format json $ALLOWED_TOOLS_FLAG 2>"$stderr_file") || exit_code=$?
    fi

    local stderr_content
    stderr_content=$(cat "$stderr_file")
    rm -f "$stderr_file"

    # Extract structured_output from the wrapper JSON envelope
    CLAUDE_RESPONSE=""
    if [ "$exit_code" -eq 0 ] && [ -n "$raw_response" ]; then
      CLAUDE_RESPONSE=$(echo "$raw_response" | python3 -c "import sys,json; so=json.load(sys.stdin).get('structured_output'); print(json.dumps(so) if so else '')" 2>/dev/null || echo "")
    fi

    if is_rate_limited "$exit_code" "$CLAUDE_RESPONSE" "$stderr_content"; then
      LAST_CLAUDE_ERROR="$stderr_content"
      LAST_CLAUDE_EXIT_CODE="$exit_code"
      if [ "${WAIT_FOR_RATE_LIMIT:-}" = "true" ] && [ "$_retried" -eq 0 ]; then
        if wait_for_rate_limit_reset; then
          _retried=1
          continue  # Retry the call
        fi
      else
        RATE_LIMIT_HIT="true"
      fi
      verbose_log_entry "claude_call_json" "$tmpfile" "" "$exit_code" "true"
      CLAUDE_RESPONSE=""
      return 1
    fi

    verbose_log_entry "claude_call_json" "$tmpfile" "$CLAUDE_RESPONSE" "0" "false"
    LAST_CLAUDE_ERROR=""
    LAST_CLAUDE_EXIT_CODE=0
    return 0
  done
}

# ── Wrapper for claude -p calls ──
# Usage: claude_call "$tmpfile" ["$system_prompt"]
# Sets: CLAUDE_RESPONSE
# Returns: 0 on success, 1 on failure (check RATE_LIMIT_HIT for rate limit vs transient)
claude_call() {
  local tmpfile="$1"
  local system_prompt="${2:-}"
  local _retried=0

  while true; do
    local stderr_file
    stderr_file=$(mktemp)

    local exit_code=0
    if [ -n "$system_prompt" ]; then
      CLAUDE_RESPONSE=$(cat "$tmpfile" | claude -p --system-prompt "$system_prompt" $ALLOWED_TOOLS_FLAG 2>"$stderr_file") || exit_code=$?
    else
      CLAUDE_RESPONSE=$(cat "$tmpfile" | claude -p $ALLOWED_TOOLS_FLAG 2>"$stderr_file") || exit_code=$?
    fi

    local stderr_content
    stderr_content=$(cat "$stderr_file")
    rm -f "$stderr_file"

    if is_rate_limited "$exit_code" "$CLAUDE_RESPONSE" "$stderr_content"; then
      LAST_CLAUDE_ERROR="$stderr_content"
      LAST_CLAUDE_EXIT_CODE="$exit_code"
      if [ "${WAIT_FOR_RATE_LIMIT:-}" = "true" ] && [ "$_retried" -eq 0 ]; then
        if wait_for_rate_limit_reset; then
          _retried=1
          continue  # Retry the call
        fi
      else
        RATE_LIMIT_HIT="true"
      fi
      verbose_log_entry "claude_call" "$tmpfile" "" "$exit_code" "true"
      CLAUDE_RESPONSE=""
      return 1
    fi

    # Non-rate-limit failure: exit code non-zero but not rate limited
    if [ "$exit_code" -ne 0 ]; then
      LAST_CLAUDE_ERROR="$stderr_content"
      LAST_CLAUDE_EXIT_CODE="$exit_code"
      verbose_log_entry "claude_call" "$tmpfile" "$CLAUDE_RESPONSE" "$exit_code" "false"
      # If we got a response despite the error, treat it as success
      local trimmed_resp
      trimmed_resp=$(echo "$CLAUDE_RESPONSE" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      if [ -n "$trimmed_resp" ]; then
        return 0
      fi
      # No response and non-zero exit = real failure
      CLAUDE_RESPONSE=""
      return 1
    fi

    # Success
    verbose_log_entry "claude_call" "$tmpfile" "$CLAUDE_RESPONSE" "0" "false"
    LAST_CLAUDE_ERROR=""
    LAST_CLAUDE_EXIT_CODE=0
    return 0
  done
}


# ── Normalize a variable to JSON boolean ──
_json_bool() { [ "${1:-}" = "true" ] && echo "true" || echo "false"; }

# ── Save session state to file (atomic via temp+mv) ──
save_state() {
  [ -z "${STATE_FILE:-}" ] && return

  local tmp_state
  tmp_state=$(mktemp "$(dirname "$STATE_FILE")/.tmp_state.XXXXXX")

  local escaped_conversation escaped_seed escaped_context escaped_lens escaped_mechanism_memory
  local escaped_conductor_view escaped_lens_view
  escaped_conversation=$(echo "$CONVERSATION" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  escaped_seed=$(echo "$SEED_TOPIC" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))")
  escaped_context=$(echo "${PROJECT_CONTEXT:-}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  escaped_lens=$(echo "${LENS_CONTEXT:-}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  escaped_conductor_view=$(echo "${CONDUCTOR_VIEW:-}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  escaped_lens_view=$(echo "${LENS_VIEW:-}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

  # Serialize mechanism memory array as JSON
  escaped_mechanism_memory="[]"
  if [ ${#MECHANISM_MEMORY[@]} -gt 0 ]; then
    escaped_mechanism_memory=$(printf '%s\n' "${MECHANISM_MEMORY[@]}" | python3 -c "import sys,json; print(json.dumps([l.rstrip() for l in sys.stdin]))")
  fi

  # Normalize all boolean flags to valid JSON true/false
  local f_friction f_bias f_sensory f_shuffle f_compact f_autonomous f_skip_strict
  local f_negative_space f_transcendence f_wait_for_rate_limit f_progressive
  f_friction=$(_json_bool "${FRICTION_ENABLED:-true}")
  f_bias=$(_json_bool "${BIAS_ENABLED:-true}")
  f_sensory=$(_json_bool "${SENSORY_ENABLED:-true}")
  f_shuffle=$(_json_bool "${SHUFFLE_ENABLED:-}")
  f_compact=$(_json_bool "${COMPACT_ENABLED:-}")
  f_autonomous=$(_json_bool "${AUTONOMOUS_MODE:-true}")
  f_skip_strict=$(_json_bool "${SKIP_STRICT:-}")
  f_negative_space=$(_json_bool "${NEGATIVE_SPACE_ENABLED:-true}")
  f_transcendence=$(_json_bool "${TRANSCENDENCE_ENABLED:-true}")
  f_wait_for_rate_limit=$(_json_bool "${WAIT_FOR_RATE_LIMIT:-true}")
  f_progressive=$(_json_bool "${PROGRESSIVE_ENABLED:-true}")

  cat > "$tmp_state" << STATEEOF
{
  "version": 2,
  "seed": ${escaped_seed},
  "mode": "${MODE}",
  "conversation": ${escaped_conversation},
  "turn_count": ${TURN_COUNT},
  "word_count": "${WORD_COUNT}",
  "timestamp": "${TIMESTAMP}",
  "project_context": ${escaped_context},
  "lens_context": ${escaped_lens},
  "mechanism_memory": ${escaped_mechanism_memory},
  "status": "in_progress",
  "last_compact_turn": ${LAST_COMPACT_TURN:-0},
  "progressive": {
    "enabled": ${f_progressive},
    "tier": "${PROGRESSIVE_TIER:-full}",
    "last_turn": ${LAST_PROGRESSIVE_TURN:-0},
    "conductor_view": ${escaped_conductor_view},
    "lens_view": ${escaped_lens_view}
  },
  "flags": {
    "friction_enabled": ${f_friction},
    "bias_enabled": ${f_bias},
    "sensory_enabled": ${f_sensory},
    "shuffle_enabled": ${f_shuffle},
    "compact_enabled": ${f_compact},
    "allowed_tools": "${ALLOWED_TOOLS:-}",
    "autonomous_mode": ${f_autonomous},
    "skip_strict": ${f_skip_strict},
    "negative_space_enabled": ${f_negative_space},
    "transcendence_enabled": ${f_transcendence},
    "wait_for_rate_limit": ${f_wait_for_rate_limit}
  }
}
STATEEOF

  mv "$tmp_state" "$STATE_FILE"
}

# ── Mark state as complete ──
complete_state() {
  [ -z "${STATE_FILE:-}" ] && return
  [ ! -f "${STATE_FILE}" ] && return

  # Rewrite with status complete
  local tmp_state
  tmp_state=$(mktemp "$(dirname "$STATE_FILE")/.tmp_state.XXXXXX")

  python3 -c "
import json, sys
with open('${STATE_FILE}', 'r') as f:
    state = json.load(f)
state['status'] = 'complete'
with open('${tmp_state}', 'w') as f:
    json.dump(state, f, indent=2)
"
  mv "$tmp_state" "$STATE_FILE"
}

# ── Load session state from file ──
# Sets globals and RESUME_FROM_TURN
load_state() {
  local state_file="$1"

  if [ ! -f "$state_file" ]; then
    echo "Error: state file not found: $state_file"
    exit 1
  fi

  # Check status
  local status
  status=$(python3 -c "import json; print(json.load(open('${state_file}'))['status'])")
  if [ "$status" = "complete" ]; then
    echo "Error: this session already completed. Nothing to resume."
    exit 1
  fi

  echo "  Loading session state from: $state_file"

  # Extract all fields via python (v1 backward compat via .get() defaults)
  eval "$(python3 -c "
import json, shlex
with open('${state_file}', 'r') as f:
    state = json.load(f)
print('SEED_TOPIC=' + shlex.quote(state['seed']))
print('MODE=' + shlex.quote(state['mode']))
print('WORD_COUNT=' + shlex.quote(state['word_count']))
print('TIMESTAMP=' + shlex.quote(state['timestamp']))
print('RESUME_FROM_TURN=' + str(state['turn_count']))
print('FRICTION_ENABLED=' + shlex.quote(str(state['flags']['friction_enabled']).lower()))
print('BIAS_ENABLED=' + shlex.quote(str(state['flags']['bias_enabled']).lower()))
print('SENSORY_ENABLED=' + shlex.quote(str(state['flags']['sensory_enabled']).lower()))
print('SHUFFLE_ENABLED=' + shlex.quote(str(state['flags']['shuffle_enabled']).lower()))
print('COMPACT_ENABLED=' + shlex.quote(str(state['flags'].get('compact_enabled', False)).lower()))
print('ALLOWED_TOOLS=' + shlex.quote(state['flags'].get('allowed_tools', '')))
print('LAST_COMPACT_TURN=' + str(state.get('last_compact_turn', 0)))
print('AUTONOMOUS_MODE=' + shlex.quote(str(state['flags'].get('autonomous_mode', True)).lower()))
print('SKIP_STRICT=' + shlex.quote(str(state['flags'].get('skip_strict', False)).lower()))
print('NEGATIVE_SPACE_ENABLED=' + shlex.quote(str(state['flags'].get('negative_space_enabled', True)).lower()))
print('TRANSCENDENCE_ENABLED=' + shlex.quote(str(state['flags'].get('transcendence_enabled', True)).lower()))
print('WAIT_FOR_RATE_LIMIT=' + shlex.quote(str(state['flags'].get('wait_for_rate_limit', state['flags'].get('wait_for_cap', True))).lower()))
prog = state.get('progressive', {})
print('PROGRESSIVE_ENABLED=' + shlex.quote(str(prog.get('enabled', True)).lower()))
print('PROGRESSIVE_TIER=' + shlex.quote(prog.get('tier', 'full')))
print('LAST_PROGRESSIVE_TURN=' + str(prog.get('last_turn', 0)))
")"

  # Rebuild tools flag from restored state
  build_tools_flag

  # Load large text fields separately to avoid shell quoting issues
  CONVERSATION=$(python3 -c "import json; print(json.load(open('${state_file}'))['conversation'], end='')")
  PROJECT_CONTEXT=$(python3 -c "import json; print(json.load(open('${state_file}'))['project_context'], end='')")
  LENS_CONTEXT=$(python3 -c "import json; print(json.load(open('${state_file}'))['lens_context'], end='')")
  CONDUCTOR_VIEW=$(python3 -c "import json; print(json.load(open('${state_file}')).get('progressive', {}).get('conductor_view', ''), end='')" 2>/dev/null || true)
  LENS_VIEW=$(python3 -c "import json; print(json.load(open('${state_file}')).get('progressive', {}).get('lens_view', ''), end='')" 2>/dev/null || true)
  TURN_COUNT="$RESUME_FROM_TURN"

  # Restore mechanism memory (v2+, empty for v1 state files)
  MECHANISM_MEMORY=()
  while IFS= read -r mm_line; do
    [ -n "$mm_line" ] && MECHANISM_MEMORY+=("$mm_line")
  done < <(python3 -c "
import json
with open('${state_file}', 'r') as f:
    state = json.load(f)
for entry in state.get('mechanism_memory', []):
    print(entry)
")
  if [ ${#MECHANISM_MEMORY[@]} -gt 0 ]; then
    echo "  Restored ${#MECHANISM_MEMORY[@]} mechanism memory entries"
  fi

  RESUME_MODE="true"

  echo "  Resuming from turn ${RESUME_FROM_TURN}, mode: ${MODE}"
  echo "  Seed: ${SEED_TOPIC}"
}

# ── EXIT trap: clean shutdown on rate limit ──
rate_limit_cleanup() {
  if [ "$RATE_LIMIT_HIT" = "true" ]; then
    # Flush files if functions are available
    if type json_flush &>/dev/null; then
      json_flush 2>/dev/null || true
    fi
    if type md_flush &>/dev/null; then
      md_flush 2>/dev/null || true
    fi
    save_state 2>/dev/null || true

    echo ""
    echo "  ⛔ Claude API rate limit reached. Stopping session gracefully."
    echo "     Turns completed: ${TURN_COUNT:-0}"
    echo ""
    if [ -n "${TRANSCRIPT_MD:-}" ] && [ -f "${TRANSCRIPT_MD:-}" ]; then
      echo "     📄 Transcript: $TRANSCRIPT_MD"
    fi
    if [ -n "${TRANSCRIPT_JSON:-}" ] && [ -f "${TRANSCRIPT_JSON:-}" ]; then
      echo "     📊 JSON:       $TRANSCRIPT_JSON"
    fi
    if [ -n "${STATE_FILE:-}" ] && [ -f "${STATE_FILE:-}" ]; then
      echo ""
      echo "     Resume this session:"
      echo "       ${CMD_NAME:-./think.sh} --resume ${STATE_FILE}"
    fi
    echo ""
    echo "     Or generate a presentation from what was captured:"
    echo "       ${CMD_NAME:-./think.sh} --report-only ${TRANSCRIPT_MD:-transcript.md} --words ${WORD_COUNT:-500-800}"
    echo ""
  fi
}
