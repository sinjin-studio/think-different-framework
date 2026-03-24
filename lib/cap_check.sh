#!/usr/bin/env bash
# ── Cap detection, state management, and session resumability ──
# Centralised wrapper for all `claude -p` calls.
# Detects usage cap hits, saves session state for resume.
# Expects globals: $OUTPUT_DIR, $TIMESTAMP, $SEED_TOPIC, $MODE,
#                  $WORD_COUNT, $CONVERSATION, $TURN_COUNT,
#                  $TRANSCRIPT_MD, $TRANSCRIPT_JSON,
#                  $FRICTION_ENABLED, $BIAS_ENABLED, $SENSORY_ENABLED,
#                  $SHUFFLE_ENABLED, $CMD_NAME

# ── Cap detection globals ──
CAP_LIMIT_HIT=""
CAP_FAIL_COUNT=0
CAP_FAIL_THRESHOLD=2
CLAUDE_RESPONSE=""
ALLOWED_TOOLS_FLAG=""

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

# ── Heuristic: does this response look like a cap/limit error? ──
is_cap_hit() {
  local exit_code="$1"
  local response="$2"
  local stderr="$3"

  # Non-zero exit code
  if [ "$exit_code" -ne 0 ]; then
    return 0
  fi

  # Empty or whitespace-only response
  local trimmed
  trimmed=$(echo "$response" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  if [ -z "$trimmed" ]; then
    return 0
  fi

  # Check for error strings in response or stderr (bash 3.2 compatible)
  local lower_response lower_stderr
  lower_response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
  lower_stderr=$(echo "$stderr" | tr '[:upper:]' '[:lower:]')

  local pattern
  for pattern in "rate limit" "usage limit" "quota" "capacity" "too many requests" "429" "overloaded" "token limit" "exceeded"; do
    case "$lower_response" in *"$pattern"*) return 0 ;; esac
    case "$lower_stderr" in *"$pattern"*) return 0 ;; esac
  done

  return 1
}

# ── Wrapper for claude -p calls ──
# Usage: claude_call "$tmpfile" ["$system_prompt"]
# Sets: CLAUDE_RESPONSE
# Returns: 0 on success, 1 on failure (check CAP_LIMIT_HIT for cap vs transient)
claude_call() {
  local tmpfile="$1"
  local system_prompt="${2:-}"

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

  if is_cap_hit "$exit_code" "$CLAUDE_RESPONSE" "$stderr_content"; then
    CAP_FAIL_COUNT=$((CAP_FAIL_COUNT + 1))
    if [ "$CAP_FAIL_COUNT" -ge "$CAP_FAIL_THRESHOLD" ]; then
      CAP_LIMIT_HIT="true"
    fi
    CLAUDE_RESPONSE=""
    return 1
  fi

  # Success - reset counter
  CAP_FAIL_COUNT=0
  return 0
}

# ── Save session state to file (atomic via temp+mv) ──
save_state() {
  [ -z "${STATE_FILE:-}" ] && return

  local tmp_state
  tmp_state=$(mktemp "$(dirname "$STATE_FILE")/.tmp_state.XXXXXX")

  local escaped_conversation escaped_seed escaped_context escaped_lens
  escaped_conversation=$(echo "$CONVERSATION" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  escaped_seed=$(echo "$SEED_TOPIC" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))")
  escaped_context=$(echo "${PROJECT_CONTEXT:-}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  escaped_lens=$(echo "${LENS_CONTEXT:-}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

  cat > "$tmp_state" << STATEEOF
{
  "version": 1,
  "seed": ${escaped_seed},
  "mode": "${MODE}",
  "conversation": ${escaped_conversation},
  "turn_count": ${TURN_COUNT},
  "word_count": "${WORD_COUNT}",
  "timestamp": "${TIMESTAMP}",
  "project_context": ${escaped_context},
  "lens_context": ${escaped_lens},
  "status": "in_progress",
  "flags": {
    "friction_enabled": ${FRICTION_ENABLED:-true},
    "bias_enabled": ${BIAS_ENABLED:-true},
    "sensory_enabled": ${SENSORY_ENABLED:-true},
    "shuffle_enabled": ${SHUFFLE_ENABLED:-false},
    "allowed_tools": "${ALLOWED_TOOLS:-}"
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

  # Extract all fields via python
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
print('ALLOWED_TOOLS=' + shlex.quote(state['flags'].get('allowed_tools', '')))
")"

  # Rebuild tools flag from restored state
  build_tools_flag

  # Load large text fields separately to avoid shell quoting issues
  CONVERSATION=$(python3 -c "import json; print(json.load(open('${state_file}'))['conversation'], end='')")
  PROJECT_CONTEXT=$(python3 -c "import json; print(json.load(open('${state_file}'))['project_context'], end='')")
  LENS_CONTEXT=$(python3 -c "import json; print(json.load(open('${state_file}'))['lens_context'], end='')")
  TURN_COUNT="$RESUME_FROM_TURN"

  RESUME_MODE="true"

  echo "  Resuming from turn ${RESUME_FROM_TURN}, mode: ${MODE}"
  echo "  Seed: ${SEED_TOPIC}"
}

# ── EXIT trap: clean shutdown on cap hit ──
cap_limit_cleanup() {
  if [ "$CAP_LIMIT_HIT" = "true" ]; then
    # Flush files if functions are available
    if type json_flush &>/dev/null; then
      json_flush 2>/dev/null || true
    fi
    if type md_flush &>/dev/null; then
      md_flush 2>/dev/null || true
    fi
    save_state 2>/dev/null || true

    echo ""
    echo "  ⛔ Claude CLI usage cap reached. Stopping session gracefully."
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
