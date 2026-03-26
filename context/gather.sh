#!/usr/bin/env bash
# ── Project context gathering ──
# Shared by all compositions. Runs Claude to understand the project
# from a human-experience perspective.
# Expects globals: $CONTEXT_FILE, $SESSION_DIR (optional - copies context there if set)
# Sets: $PROJECT_CONTEXT

gather_project_context() {
  start_spinner "📍 Gathering project context"

  if [ -n "$CONTEXT_FILE" ]; then
    if [ -f "$CONTEXT_FILE" ]; then
      PROJECT_CONTEXT=$(cat "$CONTEXT_FILE")
      if [ -n "${SESSION_DIR:-}" ]; then
        cp "$CONTEXT_FILE" "$SESSION_DIR/context.md"
      fi
      stop_spinner "done (from file)"
      return
    else
      stop_spinner "failed"
      echo "  Warning: context file not found: $CONTEXT_FILE"
      PROJECT_CONTEXT=""
      return
    fi
  fi

  local has_project=""
  if [ -f "package.json" ] || [ -f "README.md" ] || [ -f "CLAUDE.md" ] || [ -d "src" ] || [ -d "app" ] || [ -f "Cargo.toml" ] || [ -f "pyproject.toml" ]; then
    has_project="true"
  fi

  if [ -z "$has_project" ]; then
    stop_spinner "skipped (no project detected)"
    PROJECT_CONTEXT=""
    return
  fi

  local current_commit=""
  local cache_dir=".context"
  local cache_file="$cache_dir/experience.md"
  local cache_commit_file="$cache_dir/experience_commit"

  if command -v git &> /dev/null && git rev-parse --is-inside-work-tree &> /dev/null 2>&1; then
    current_commit=$(git rev-parse HEAD 2>/dev/null) || current_commit=""
  fi

  if [ -f "$cache_file" ] && [ -f "$cache_commit_file" ] && [ -n "$current_commit" ]; then
    local cached_commit
    cached_commit=$(cat "$cache_commit_file")
    if [ "$cached_commit" = "$current_commit" ]; then
      PROJECT_CONTEXT=$(cat "$cache_file")
      if [ -n "${SESSION_DIR:-}" ]; then
        cp "$cache_file" "$SESSION_DIR/context.md"
      fi
      stop_spinner "done (cached, commit ${current_commit:0:7})"
      return
    else
      stop_spinner "stale cache"
      start_spinner "📍 Regenerating project context"
    fi
  fi

  local research_preamble=""
  case "${ALLOWED_TOOLS:-}" in
    *WebSearch*)
      research_preamble="You have access to web search. If the project references a specific product, brand, or market, search for current public information to enrich your brief.

"
      ;;
  esac

  local gather_prompt="${research_preamble}I need you to look at this project and produce a brief that describes the HUMAN EXPERIENCE of what this project is. This brief will be used as context for a creative thinking session.

CRITICAL: Do NOT mention technical implementation details. No frameworks (Astro, React, Next.js, etc.), no deployment platforms (Netlify, Vercel, etc.), no programming languages, no package managers, no database engines, no CSS approaches, no build tools. None of that.

THE ONE EXCEPTION: If AI or machine intelligence plays a role in the user experience or business logic, DO describe what the AI does from the user's perspective. Not model names or API details, but the experience.

Answer these questions in plain, concrete language:

1. WHAT IS THIS? One paragraph. What does it do? What is it for?
2. WHO IS IT FOR? The actual human beings. What are they like? What do they care about?
3. HOW DOES IT FEEL TO USE? The experience. The journey. The key moments.
4. WHAT MAKES IT DISTINCTIVE? What would be lost if it did not exist?
5. WHAT IS THE CURRENT STATE? Live, in development, prototype? What works? What struggles?

Keep the brief under 500 words. Concrete and specific."

  local gather_tmpfile
  gather_tmpfile=$(mktemp)
  echo "$gather_prompt" > "$gather_tmpfile"
  VERBOSE_CALLER="gather"
  if claude_call "$gather_tmpfile"; then
    PROJECT_CONTEXT="$CLAUDE_RESPONSE"
  else
    PROJECT_CONTEXT=""
    rm -f "$gather_tmpfile"
    if [ "$CAP_LIMIT_HIT" = "true" ]; then
      stop_spinner "cap limit"
      return 1
    fi
    stop_spinner "failed (continuing without context)"
    return
  fi
  rm -f "$gather_tmpfile"

  mkdir -p "$cache_dir"
  echo "$PROJECT_CONTEXT" > "$cache_file"
  if [ -n "$current_commit" ]; then
    echo "$current_commit" > "$cache_commit_file"
    stop_spinner "done (cached at commit ${current_commit:0:7})"
  else
    echo "none" > "$cache_commit_file"
    stop_spinner "done (cached, no git)"
  fi

  if [ -n "${SESSION_DIR:-}" ]; then
    echo "$PROJECT_CONTEXT" > "$SESSION_DIR/context.md"
    echo "  📍 Context saved: $SESSION_DIR/context.md"
  fi
}
