#!/usr/bin/env bash
# ── Animated CLI spinner ──
# Provides start_spinner / stop_spinner for long-running operations.
# Writes animation frames to /dev/tty so stdout/stderr capture is unaffected.
# Falls back to plain echo when not on a terminal.
# Bash 3.2+ compatible (no associative arrays, no bash 4 features).

_SPINNER_PID=""
_SPINNER_MSG=""
_SPINNER_START_TIME=""

# Braille dot animation frames (same style as ora / Astro CLI)
_SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

# ── Detect terminal capability once ──
# Test by actually writing to /dev/tty (permission checks alone are not reliable)
_SPINNER_HAS_TTY=""
if (printf '' > /dev/tty) 2>/dev/null; then
  _SPINNER_HAS_TTY="true"
fi

# ── Kill any running spinner (silent, no output) ──
_spinner_kill() {
  if [ -n "$_SPINNER_PID" ]; then
    kill "$_SPINNER_PID" 2>/dev/null || true
    wait "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
  fi
}

# ── Start spinner ──
# Usage: start_spinner "🔍 Grounding the seed"
# The message should NOT include trailing "..." - the spinner adds it.
# Indentation (4 spaces for subtask level) is handled internally.
start_spinner() {
  local msg="$1"
  _SPINNER_MSG="$msg"
  _SPINNER_START_TIME=$(date +%s)

  # Kill any existing spinner (defensive double-start protection)
  _spinner_kill

  if [ "$_SPINNER_HAS_TTY" != "true" ]; then
    # Non-interactive fallback: plain echo, no animation
    echo -n "  ${msg}..."
    return
  fi

  # Hide cursor
  printf '\033[?25l' > /dev/tty 2>/dev/null

  # Launch background spinner process
  # Pass msg as argument to avoid subshell variable capture issues
  _spinner_loop "$msg" &
  _SPINNER_PID=$!

  # Disown to suppress job control messages
  disown "$_SPINNER_PID" 2>/dev/null || true
}

# ── Background spinner loop (called internally) ──
_spinner_loop() {
  local msg="$1"
  local i=0
  local frame_count=${#_SPINNER_FRAMES[@]}

  while true; do
    local frame="${_SPINNER_FRAMES[$((i % frame_count))]}"
    printf '\r\033[2K    %s %s...' "$frame" "$msg" > /dev/tty 2>/dev/null
    i=$((i + 1))
    sleep 0.08
  done
}

# ── Stop spinner with status ──
# Usage: stop_spinner "done"
#        stop_spinner "failed"
#        stop_spinner "skipped (reason)"
#        stop_spinner "rate limit"
#
# Completion format by status:
#   "done"           ->  "    ✓ Message (4.8s)"
#   "done (detail)"  ->  "    ✓ Message (detail, 4.8s)"
#   "failed"         ->  "    ✗ Message (failed)"
#   "skipped (...)"  ->  "    ○ Message (skipped ...)"
#   "rate limit"      ->  "    ✗ Message (rate limit)"
#   "stale cache"    ->  "    ○ Message (stale cache)"
stop_spinner() {
  local status="$1"
  local msg="$_SPINNER_MSG"

  # Calculate elapsed time
  local elapsed=""
  if [ -n "$_SPINNER_START_TIME" ]; then
    local end_time
    end_time=$(date +%s)
    local diff=$((end_time - _SPINNER_START_TIME))
    elapsed="${diff}s"
  fi

  if [ "$_SPINNER_HAS_TTY" != "true" ]; then
    # Non-interactive fallback: just append status like the old behavior
    echo " ${status}"
    _SPINNER_MSG=""
    _SPINNER_START_TIME=""
    return
  fi

  # Kill the background process
  _spinner_kill

  # Clear the spinner line on tty
  printf '\r\033[2K' > /dev/tty 2>/dev/null

  # Show cursor
  printf '\033[?25h' > /dev/tty 2>/dev/null

  # Print final line to stdout based on status
  case "$status" in
    done)
      echo "    ✓ ${msg} (${elapsed})"
      ;;
    done\ *)
      # "done (detail)" - extract the detail part
      local detail="${status#done }"
      echo "    ✓ ${msg} (${detail}, ${elapsed})"
      ;;
    failed*)
      echo "    ✗ ${msg} (failed)"
      ;;
    skipped*|stale*)
      echo "    ○ ${msg} (${status})"
      ;;
    cap\ limit*)
      echo "    ✗ ${msg} (rate limit)"
      ;;
    *)
      # Generic fallback
      echo "    ✓ ${msg} (${status}, ${elapsed})"
      ;;
  esac

  _SPINNER_MSG=""
  _SPINNER_START_TIME=""
}

# ── Emergency cleanup ──
# Call from EXIT/INT trap to ensure cursor is restored and spinner is killed.
spinner_cleanup() {
  _spinner_kill
  if [ "$_SPINNER_HAS_TTY" = "true" ]; then
    # Restore cursor visibility
    printf '\033[?25h' > /dev/tty 2>/dev/null || true
  fi
}
