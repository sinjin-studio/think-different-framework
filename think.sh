#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
#  THINK DIFFERENT FRAMEWORK
#
#  Here's to the crazy ones. The misfits. The rebels.
#  The troublemakers. The round pegs in square holes.
#
#  Multi-agent structured divergence via Claude Code CLI.
#  Three-level taxonomy: perceivers, cognitions, compositions.
#
#  Usage:
#    ./think.sh "Your seed topic or question"
#    ./think.sh "topic" --mode spiral --words 1500
#    ./think.sh --brief ./client-brief.pdf
#    ./think.sh --brand "Nike"
#    ./think.sh --notes "luxury wellness, Gen Z"
#    ./think.sh --brief ./brief.pdf --pick
#    ./think.sh --synthesise ./run1/*.md ./run2/*.md
#    ./think.sh --report-only ./transcript.md --words 2000
#
#  Requires: claude CLI (Claude Code) installed and authenticated
#  Works with: bash 3.2+ (macOS compatible)
# ══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect invocation name for user-facing output
if [[ "${BASH_SOURCE[0]}" == */node_modules/* ]] || [[ "$0" == *think-different* ]] || [[ "$0" == *"/td" ]]; then
  CMD_NAME="td"
else
  CMD_NAME="./think.sh"
fi

# ── Parse arguments ──

SEED_TOPIC=""
OUTPUT_DIR="./think-different-output"
WORD_COUNT="1500"
MODE="dyslexic"
PRES_ONLY=""
PRES_SOURCE=""
CONTEXT_FILE=""
SYNTHESISE_MODE=""
SYNTHESISE_FILES=()
BRIEF_FILE=""
BRAND_NAME=""
NOTES_TEXT=""
AUDIENCE_TEXT=""
PICK_MODE=""
RESUME_FILE=""

# ── Experimental composition flags ──
INCLUDE_AGENTS=()
EXCLUDE_AGENTS=()
FRICTION_ENABLED="true"
BIAS_ENABLED="true"
SENSORY_ENABLED="true"
TRANSCENDENCE_ENABLED="true"
SHUFFLE_ENABLED="false"
GROUND_ENABLED="true"
GROUND_ONLY=""
SEED_COUNT=""
SEEDS_SET_BY_USER=""
ROUND_COUNT=""
SPIRAL_COUNT=""
PASS_COUNT=""
ALLOWED_TOOLS="WebSearch,WebFetch"
PROVOCATION_TONE="provocative"
OUTPUT_TYPE="insight,brief,manifesto"
TYPE_EXPLICIT=""
LINE_COUNT=3
LINE_PRACTITIONERS=""
HTML_ENABLED="true"
REPORT_FORMATS="all"

show_help() {
  echo ""
  echo "  🪟 THINK DIFFERENT FRAMEWORK"
  echo "  ─────────────────────────────"
  echo ""
  echo "  From any input (distil into provocations, run sessions, present):"
  echo "    $CMD_NAME \"Your seed topic or question\""
  echo "    $CMD_NAME \"topic\" --mode spiral --words 1500"
  echo "    $CMD_NAME --brief ./client-brief.pdf"
  echo "    $CMD_NAME --brand \"Nike\""
  echo "    $CMD_NAME --notes \"luxury wellness, Gen Z, sustainability\""
  echo "    $CMD_NAME --brief ./brief.pdf --pick    # interactive selection"
  echo "    $CMD_NAME --brief ./brief.pdf --mode spiral"
  echo ""
  echo "  With project context:"
  echo "    cd ~/projects/my-project && $CMD_NAME \"seed topic\""
  echo "    $CMD_NAME \"seed topic\" --context ./brief.md"
  echo ""
  echo "  Manual synthesis of existing transcripts:"
  echo "    $CMD_NAME --synthesise ./run1/*.md ./run2/*.md --words 1500"
  echo ""
  echo "  Re-run presentation from existing transcript:"
  echo "    $CMD_NAME --report-only ./transcript.md --words 2000"
  echo ""
  echo "  Options:"
  echo "    --mode MODE      Composition: dyslexic (default), spiral, lapidary"
  echo "    --words N        Total word budget across all sections (default: 1500)"
  echo "    --output DIR     Output directory (default: ./think-different-output)"
  echo "    --context FILE   Explicit context file to ground the session"
  echo "    --brief FILE     Generate provocations from a brief file"
  echo "    --brand NAME     Generate provocations from a brand name"
  echo "    --notes TEXT     Generate provocations from working notes"
  echo "    --audience TEXT  Target audience (auto-inferred from input if not set)"
  echo "    --seeds N        Number of provocations to generate (default: 3, max: 12)"
  echo "    --tone TONE      Provocation tone: provocative (default), generous, intimate,"
  echo "                     absurd, daydream, mixed. Comma-separated for custom mix"
  echo "    --type TYPES     Output types: insight,brief,manifesto (default: all three)"
  echo "                     Comma-separated list. Each type is a section in the output"
  echo "    --lines N        Number of rallying lines to generate (default: 3, max: 7)"
  echo "    --practitioners  Comma-separated list of creative practitioners as quality bar"
  echo "                     (default: random 3 from built-in pool)"
  echo "    --no-html        Skip HTML presentation generation"
  echo "    --formats LIST   Output formats for --report-only: all, md, doc, html"
  echo "                     (comma-separated. doc/html skip token usage if .md exists)"
  echo "    --pick           Interactively select which provocations to run"
  echo "    --synthesise     Synthesise existing transcript files into one presentation"
  echo "    --report-only F  Regenerate presentation from existing transcript"
  echo "    --resume FILE    Resume an interrupted session from state file"
  echo "    --help           Show this help"
  echo ""
  echo "  Experimental:"
  echo "    --include A,B    Force-include agents by key (e.g. skeptic,mortal)"
  echo "    --exclude A,B    Force-exclude agents by key"
  echo "    --no-friction    Skip friction detection between rounds"
  echo "    --no-bias        Skip cognitive bias checks"
  echo "    --no-sensory     Skip sensory/context re-injection"
  echo "    --no-transcendence  Skip transcendence check"
  echo "    --rounds N       Number of rounds (dyslexic default: 4)"
  echo "    --spirals N      Number of spirals (spiral default: 3)"
  echo "    --passes N       Number of passes (lapidary default: 3)"
  echo "    --shuffle        Randomize agent order within each round/phase"
  echo "    --no-ground      Skip assumption grounding embedded in seed prep"
  echo "    --ground-only    Run only the grounding step, then exit"
  echo "    --allowedTools T Tools for Claude CLI (default: \"WebSearch,WebFetch\", use \"\" to disable)"
  echo ""
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      show_help
      ;;
    --words|-w)
      shift
      WORD_COUNT="$1"
      shift
      ;;
    --output|-o)
      shift
      OUTPUT_DIR="$1"
      shift
      ;;
    --mode|-m)
      shift
      MODE="$1"
      shift
      ;;
    --context|-c)
      shift
      CONTEXT_FILE="$1"
      shift
      ;;
    --brief|-b)
      shift
      BRIEF_FILE="$1"
      shift
      ;;
    --brand)
      shift
      BRAND_NAME="$1"
      shift
      ;;
    --notes|-n)
      shift
      NOTES_TEXT="$1"
      shift
      ;;
    --audience)
      shift
      AUDIENCE_TEXT="$1"
      shift
      ;;
    --pick)
      PICK_MODE="true"
      shift
      ;;
    --include)
      shift
      IFS=',' read -ra INCLUDE_AGENTS <<< "$1"
      shift
      ;;
    --exclude)
      shift
      IFS=',' read -ra EXCLUDE_AGENTS <<< "$1"
      shift
      ;;
    --no-friction)
      FRICTION_ENABLED="false"
      shift
      ;;
    --no-bias)
      BIAS_ENABLED="false"
      shift
      ;;
    --no-sensory)
      SENSORY_ENABLED="false"
      shift
      ;;
    --no-transcendence)
      TRANSCENDENCE_ENABLED="false"
      shift
      ;;
    --rounds)
      shift
      ROUND_COUNT="$1"
      shift
      ;;
    --spirals)
      shift
      SPIRAL_COUNT="$1"
      shift
      ;;
    --passes)
      shift
      PASS_COUNT="$1"
      shift
      ;;
    --shuffle)
      SHUFFLE_ENABLED="true"
      shift
      ;;
    --no-ground)
      GROUND_ENABLED="false"
      shift
      ;;
    --ground-only)
      GROUND_ONLY="true"
      shift
      ;;
    --seeds)
      shift
      SEED_COUNT="$1"
      SEEDS_SET_BY_USER="true"
      if [ "$SEED_COUNT" -lt 1 ] 2>/dev/null; then
        SEED_COUNT=1
      fi
      if [ "$SEED_COUNT" -gt 12 ] 2>/dev/null; then
        echo "Error: max 12 seeds (requested $SEED_COUNT). Each seed runs a full session."
        exit 1
      fi
      shift
      ;;
    --report-only|-r)
      PRES_ONLY="true"
      shift
      PRES_SOURCE="$1"
      shift
      ;;
    --synthesise|--synthesize|-s)
      SYNTHESISE_MODE="true"
      shift
      # Collect remaining non-flag arguments as transcript files
      while [ $# -gt 0 ] && [ "${1:0:2}" != "--" ]; do
        SYNTHESISE_FILES+=("$1")
        shift
      done
      ;;
    --allowedTools|--allowed-tools)
      shift
      ALLOWED_TOOLS="$1"
      shift
      ;;
    --tone|-t)
      shift
      PROVOCATION_TONE="$1"
      shift
      ;;
    --type)
      shift
      OUTPUT_TYPE="$1"
      TYPE_EXPLICIT="true"
      shift
      ;;
    --lines)
      shift
      LINE_COUNT="$1"
      shift
      ;;
    --practitioners)
      shift
      LINE_PRACTITIONERS="$1"
      shift
      ;;
    --no-html)
      HTML_ENABLED="false"
      shift
      ;;
    --formats)
      shift
      REPORT_FORMATS="$1"
      shift
      ;;
    --resume)
      shift
      RESUME_FILE="$1"
      shift
      ;;
    -*)
      echo "Unknown option: $1"
      show_help
      ;;
    *)
      if [ -z "$SEED_TOPIC" ]; then
        SEED_TOPIC="$1"
      fi
      shift
      ;;
  esac
done

# ── Validate ──

# Check mode is valid
case "$MODE" in
  dyslexic|spiral|lapidary) ;;
  *)
    echo "Error: unknown mode '$MODE'. Use: dyslexic, spiral, or lapidary"
    exit 1
    ;;
esac

# Validate output types
IFS=',' read -ra _TYPE_CHECK <<< "$OUTPUT_TYPE"
for _ot in "${_TYPE_CHECK[@]}"; do
  case "$_ot" in
    insight|brief|manifesto) ;;
    *)
      echo "Error: unknown output type '$_ot'. Use: insight, brief, or manifesto (comma-separated)"
      exit 1
      ;;
  esac
done

# Validate line count
if [ "$LINE_COUNT" -lt 1 ] 2>/dev/null; then
  LINE_COUNT=1
fi
if [ "$LINE_COUNT" -gt 7 ] 2>/dev/null; then
  echo "Error: max 7 lines (requested $LINE_COUNT)"
  exit 1
fi

# Expand "mixed" shorthand and validate tone(s)
if [ "$PROVOCATION_TONE" = "mixed" ]; then
  PROVOCATION_TONE="provocative,generous,intimate,absurd,daydream"
fi
IFS=',' read -ra _TONE_CHECK <<< "$PROVOCATION_TONE"
for _t in "${_TONE_CHECK[@]}"; do
  case "$_t" in
    provocative|generous|intimate|absurd|daydream) ;;
    *)
      echo "Error: unknown tone '$_t'. Use: provocative, generous, intimate, absurd, daydream, or mixed"
      exit 1
      ;;
  esac
done

# Need at least one of: seed, raw input, presentation-only, synthesise, or project context
HAS_INPUT=""
if [ -n "$SEED_TOPIC" ] || [ -n "$BRIEF_FILE" ] || [ -n "$BRAND_NAME" ] || [ -n "$NOTES_TEXT" ]; then
  HAS_INPUT="true"
fi

if [ -z "$PRES_ONLY" ] && [ -z "$SYNTHESISE_MODE" ] && [ -z "$RESUME_FILE" ] && [ -z "$HAS_INPUT" ]; then
  # Try project auto-detect
  if [ -f "package.json" ] || [ -f "README.md" ] || [ -f "CLAUDE.md" ] || [ -d "src" ] || [ -d "app" ] || [ -f "Cargo.toml" ] || [ -f "pyproject.toml" ]; then
    HAS_INPUT="true"
  else
    show_help
  fi
fi

if [ -n "$PRES_ONLY" ] && [ -z "$PRES_SOURCE" ]; then
  echo "Error: --report-only requires a path to an existing transcript .md file"
  exit 1
fi

if [ -n "$PRES_ONLY" ] && [ ! -f "$PRES_SOURCE" ]; then
  echo "Error: transcript file not found: $PRES_SOURCE"
  exit 1
fi

if [ -n "$SYNTHESISE_MODE" ] && [ ${#SYNTHESISE_FILES[@]} -eq 0 ]; then
  echo "Error: --synthesise requires at least one transcript file"
  exit 1
fi

if ! command -v claude &> /dev/null; then
  echo "Error: 'claude' CLI not found. Install Claude Code first."
  echo "  npm install -g @anthropic-ai/claude-code"
  exit 1
fi

# ── Detect Claude plan for default seed count ──
CLAUDE_PLAN=""
if auth_json=$(claude auth status 2>/dev/null); then
  CLAUDE_PLAN=$(echo "$auth_json" | grep -o '"subscriptionType":[[:space:]]*"[^"]*"' | cut -d'"' -f4) || true
fi

if [ -n "$CLAUDE_PLAN" ]; then
  echo "  ℹ  Detected plan: $CLAUDE_PLAN"
else
  echo "  ℹ  Could not detect Claude plan (defaulting to 1 seed)."
  echo "     Run 'claude auth status' to check your subscription."
fi

if [ -z "$SEEDS_SET_BY_USER" ]; then
  case "$CLAUDE_PLAN" in
    max|enterprise|team)
      SEED_COUNT="${SEED_COUNT:-3}"
      ;;
    *)
      SEED_COUNT="${SEED_COUNT:-1}"
      # Only show info when in distillation mode (brief/brand/notes generate multiple provocations)
      if [ -n "$BRIEF_FILE" ] || [ -n "$BRAND_NAME" ] || [ -n "$NOTES_TEXT" ]; then
        echo "  ℹ  Pro plan detected - defaulting to 1 provocation (use --seeds N to override)."
        echo "     Max plan recommended for multi-provocation sessions. See README for details."
      fi
      ;;
  esac
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$OUTPUT_DIR"

# ── Slugify seed text for folder names ──
slugify_seed() {
  local slug
  slug=$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 -]//g' | tr ' ' '-' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
  # Truncate to ~50 chars on a word boundary
  if [ ${#slug} -gt 50 ]; then
    slug=$(echo "$slug" | cut -c1-50 | sed 's/-[^-]*$//')
  fi
  # Fallback for empty input
  if [ -z "$slug" ]; then
    slug="session"
  fi
  echo "$slug"
}

# ── Source libraries ──

source "${SCRIPT_DIR}/lib/json.sh"
source "${SCRIPT_DIR}/lib/md.sh"
source "${SCRIPT_DIR}/lib/markers.sh"
source "${SCRIPT_DIR}/lib/cap_check.sh"
source "${SCRIPT_DIR}/lib/call_agent.sh"
source "${SCRIPT_DIR}/lib/spinner.sh"
source "${SCRIPT_DIR}/report/generate.sh"

# ── Build tool flags from parsed arguments ──
build_tools_flag

# ── Convert markdown presentation to .docx ──
convert_to_docx() {
  local md_file="$1"
  local docx_file="$2"
  python3 "${SCRIPT_DIR}/report/md-to-docx.py" "$md_file" "$docx_file" 2>/dev/null || {
    echo "  (python-docx not available - .docx skipped. Install with: pip3 install python-docx)"
  }
}

# ── Convert markdown presentation to .html ──
convert_to_html() {
  local md_file="$1"
  local html_file="$2"
  local template="${SCRIPT_DIR}/report/template.html"
  if [ ! -f "$template" ]; then
    echo "  (HTML template not found - .html skipped. Run: cd report/html-template && npm run export)"
    return
  fi
  python3 "${SCRIPT_DIR}/report/md-to-html.py" "$md_file" "$html_file" "$template" 2>/dev/null || {
    echo "  (HTML conversion failed - .html skipped)"
  }
}

# ── Register cleanup traps ──
cleanup_all() {
  spinner_cleanup
  cap_limit_cleanup
}
trap cleanup_all EXIT
trap 'spinner_cleanup; exit 130' INT


# ══════════════════════════════════════════════
#  SYNTHESISE MODE
# ══════════════════════════════════════════════

if [ -n "$SYNTHESISE_MODE" ]; then
  source "${SCRIPT_DIR}/report/synthesise.sh"

  echo ""
  echo "  🪟 THINK DIFFERENT - Synthesis Mode"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Files: ${#SYNTHESISE_FILES[@]} transcripts"
  echo "  Words: $WORD_COUNT"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  SESSION_DIR="$OUTPUT_DIR/synthesis_${TIMESTAMP}"
  mkdir -p "$SESSION_DIR"
  PRES_FILE="$SESSION_DIR/presentation.md"
  DOCX_FILE="$SESSION_DIR/presentation.docx"
  HTML_FILE="$SESSION_DIR/presentation.html"
  synthesise_presentations "$WORD_COUNT" "$PRES_FILE" "Cross-session synthesis" "${SYNTHESISE_FILES[@]}" > /dev/null
  convert_to_docx "$PRES_FILE" "$DOCX_FILE"
  if [ "$HTML_ENABLED" = "true" ]; then
    convert_to_html "$PRES_FILE" "$HTML_FILE"
  fi

  echo ""
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✦ Synthesis complete"
  echo ""
  echo "  📝 Presentation: $PRES_FILE"
  echo "  📄 Document:     $DOCX_FILE"
  if [ "$HTML_ENABLED" = "true" ]; then
    echo "  🌐 HTML:         $HTML_FILE"
  fi
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 0
fi

# ══════════════════════════════════════════════
#  PRESENTATION-ONLY MODE
# ══════════════════════════════════════════════

if [ -n "$PRES_ONLY" ]; then
  echo ""
  echo "  🪟 THINK DIFFERENT - Presentation Mode"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Source: $PRES_SOURCE"
  echo "  Formats: $REPORT_FORMATS"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  SESSION_DIR="$(dirname "$PRES_SOURCE")"
  pres_suffix=$(date +%H%M%S)

  # Determine which formats to generate
  needs_md="false"
  needs_doc="false"
  needs_html="false"

  case "$REPORT_FORMATS" in
    all)
      needs_md="true"
      needs_doc="true"
      needs_html="true"
      ;;
    *)
      IFS=',' read -ra _fmts <<< "$REPORT_FORMATS"
      for _f in "${_fmts[@]}"; do
        case "$_f" in
          md) needs_md="true" ;;
          doc) needs_doc="true" ;;
          html) needs_html="true" ;;
          *) echo "Error: unknown format '$_f'. Use: all, md, doc, html"; exit 1 ;;
        esac
      done
      ;;
  esac

  # If only doc/html requested, look for existing presentation.md
  if [ "$needs_md" = "true" ]; then
    # Generate new .md from transcript (uses tokens)
    SEED_TOPIC=$(grep -m1 "Seed:" "$PRES_SOURCE" | sed 's/.*Seed:\*\* *//' | sed 's/^> \*\*Seed:\*\* //' | sed 's/^.*Seed: //')
    if [ -z "$SEED_TOPIC" ]; then
      SEED_TOPIC="[Seed not found in transcript]"
    fi
    CONVERSATION=$(cat "$PRES_SOURCE")
    PRES_FILE="$SESSION_DIR/presentation_${pres_suffix}.md"
    echo "  Words: $WORD_COUNT"
    generate_presentation "$CONVERSATION" "$SEED_TOPIC" "$WORD_COUNT" "$PRES_FILE" > /dev/null
  else
    # Use existing presentation.md (no tokens)
    # Check if source IS a presentation.md or if we need to find one
    if echo "$PRES_SOURCE" | grep -q "presentation"; then
      PRES_FILE="$PRES_SOURCE"
    else
      # Look for presentation.md in same directory
      PRES_FILE=$(ls -t "$SESSION_DIR"/presentation*.md 2>/dev/null | head -1)
    fi
    if [ -z "$PRES_FILE" ] || [ ! -f "$PRES_FILE" ]; then
      echo ""
      echo "  Error: No presentation.md found in $SESSION_DIR"
      echo "  Run with --formats md first, or run a full session to generate one."
      exit 1
    fi
    echo "  Using existing: $PRES_FILE"
  fi

  echo ""
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✦ Presentation generated"
  echo ""

  if [ "$needs_md" = "true" ]; then
    echo "  📝 Presentation: $PRES_FILE"
  fi
  if [ "$needs_doc" = "true" ]; then
    DOCX_FILE="${PRES_FILE%.md}.docx"
    convert_to_docx "$PRES_FILE" "$DOCX_FILE"
    echo "  📄 Document:     $DOCX_FILE"
  fi
  if [ "$needs_html" = "true" ]; then
    HTML_FILE="${PRES_FILE%.md}.html"
    convert_to_html "$PRES_FILE" "$HTML_FILE"
    echo "  🌐 HTML:         $HTML_FILE"
  fi

  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 0
fi

# ══════════════════════════════════════════════
#  RESUME MODE
# ══════════════════════════════════════════════

if [ -n "$RESUME_FILE" ]; then
  load_state "$RESUME_FILE"

  source "${SCRIPT_DIR}/report/synthesise.sh"

  # Derive file paths - resume into same folder as the state file
  SESSION_DIR="$(dirname "$RESUME_FILE")"
  TRANSCRIPT_MD="$SESSION_DIR/session.md"
  TRANSCRIPT_JSON="$SESSION_DIR/session.json"
  STATE_FILE="$SESSION_DIR/session.state.json"

  # Restore JSON buffer from existing file if present
  if [ -f "$TRANSCRIPT_JSON" ]; then
    # Re-populate JSON_ENTRIES from existing file
    local_count=0
    while IFS= read -r entry; do
      JSON_ENTRIES+=("$entry")
      local_count=$((local_count + 1))
    done < <(python3 -c "
import json
with open('${TRANSCRIPT_JSON}', 'r') as f:
    data = json.load(f)
for entry in data:
    print(json.dumps(entry))
")
    echo "  Restored ${local_count} entries from existing JSON transcript"
  fi

  # Restore MD buffer from existing file if present
  if [ -f "$TRANSCRIPT_MD" ]; then
    md_content=$(cat "$TRANSCRIPT_MD")
    # Split on first --- to separate header from body
    MD_HEADER=$(echo "$md_content" | sed '/^---$/q')
    MD_HEADER="${MD_HEADER}
"
    MD_BUFFER=$(echo "$md_content" | sed '1,/^---$/d')
    echo "  Restored markdown transcript"
  else
    md_init_header "Think Different Session (Resumed)" "$SEED_TOPIC"
  fi

  echo ""
  echo "  🪟 THINK DIFFERENT FRAMEWORK - Resuming"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Seed: ${SEED_TOPIC:0:80}"
  echo "  Mode: $MODE"
  echo "  Resuming from turn: $RESUME_FROM_TURN"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Source and run the mode (skip logic handled by call_agent)
  source "${SCRIPT_DIR}/modes/${MODE}.sh"
  run_session || true

  if [ "$CAP_LIMIT_HIT" = "true" ]; then
    exit 1
  fi

  # Final flush and mark complete
  json_flush
  md_flush
  complete_state

  PRES_FILE="$SESSION_DIR/presentation.md"
  DOCX_FILE="$SESSION_DIR/presentation.docx"
  HTML_FILE="$SESSION_DIR/presentation.html"
  PRES_CONTENT=$(generate_presentation "$CONVERSATION" "$SEED_TOPIC" "$WORD_COUNT" "$PRES_FILE" "${TURN_COUNT} turns, ${MODE} composition (resumed)")

  # Append presentation to transcript
  MD_BUFFER="${MD_BUFFER}

---

## Presentation

${PRES_CONTENT}
"
  md_flush

  convert_to_docx "$PRES_FILE" "$DOCX_FILE"
  if [ "$HTML_ENABLED" = "true" ]; then
    convert_to_html "$PRES_FILE" "$HTML_FILE"
  fi

  echo ""
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✦ Resumed session complete"
  echo "    ${TURN_COUNT} turns, ${MODE} composition"
  echo ""
  echo "  📝 Presentation: $PRES_FILE"
  echo "  📄 Document:     $DOCX_FILE"
  if [ "$HTML_ENABLED" = "true" ]; then
    echo "  🌐 HTML:         $HTML_FILE"
  fi
  echo "  📄 Transcript:   $TRANSCRIPT_MD"
  echo "  📊 JSON:         $TRANSCRIPT_JSON"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 0
fi

# ══════════════════════════════════════════════
#  MAIN PIPELINE
#  Input -> Distil -> Seeds -> [pick?] -> Session(s) -> Generate/Synthesise -> Presentation
# ══════════════════════════════════════════════

source "${SCRIPT_DIR}/context/provoke.sh"
source "${SCRIPT_DIR}/context/gather.sh"
source "${SCRIPT_DIR}/report/synthesise.sh"

CONVERSATION=""
TURN_COUNT=0
PROJECT_CONTEXT=""

# ── Build experiment banner lines ──
EXPERIMENT_LINES=()
if [ ${#INCLUDE_AGENTS[@]} -gt 0 ]; then
for inc in "${INCLUDE_AGENTS[@]}"; do
  EXPERIMENT_LINES+=("    + ${inc} (included via --include)")
done
fi
if [ ${#EXCLUDE_AGENTS[@]} -gt 0 ]; then
for exc in "${EXCLUDE_AGENTS[@]}"; do
  EXPERIMENT_LINES+=("    - ${exc} (excluded via --exclude)")
done
fi
[ "$FRICTION_ENABLED" != "true" ] && EXPERIMENT_LINES+=("    - friction (disabled via --no-friction)")
[ "$BIAS_ENABLED" != "true" ] && EXPERIMENT_LINES+=("    - bias (disabled via --no-bias)")
[ "$SENSORY_ENABLED" != "true" ] && EXPERIMENT_LINES+=("    - sensory (disabled via --no-sensory)")
[ "$TRANSCENDENCE_ENABLED" != "true" ] && EXPERIMENT_LINES+=("    - transcendence (disabled via --no-transcendence)")
[ -n "$ROUND_COUNT" ] && EXPERIMENT_LINES+=("    ~ rounds: ${ROUND_COUNT} (via --rounds)")
[ -n "$SPIRAL_COUNT" ] && EXPERIMENT_LINES+=("    ~ spirals: ${SPIRAL_COUNT} (via --spirals)")
[ -n "$PASS_COUNT" ] && EXPERIMENT_LINES+=("    ~ passes: ${PASS_COUNT} (via --passes)")
[ "$SHUFFLE_ENABLED" = "true" ] && EXPERIMENT_LINES+=("    ~ shuffle (agent order randomized)")
[ "$GROUND_ENABLED" != "true" ] && EXPERIMENT_LINES+=("    - ground (disabled via --no-ground)")
if [ -n "$ALLOWED_TOOLS" ]; then
  EXPERIMENT_LINES+=("    + tools: ${ALLOWED_TOOLS}")
else
  EXPERIMENT_LINES+=("    - tools: disabled (no web search)")
fi
[ "$PROVOCATION_TONE" != "provocative" ] && EXPERIMENT_LINES+=("    ~ tone: ${PROVOCATION_TONE}")

# ── 1. Read input material ──
# All paths produce INPUT_MATERIAL for distillation

if [ -n "$CONTEXT_FILE" ] && [ -f "$CONTEXT_FILE" ]; then
  PROJECT_CONTEXT=$(cat "$CONTEXT_FILE")
fi

input_type=""
INPUT_MATERIAL=""

if [ -n "$BRIEF_FILE" ]; then
  input_type="brief"
  INPUT_MATERIAL=$(read_input_material "brief" "$BRIEF_FILE") || {
    echo "Error: could not read brief file"
    exit 1
  }
elif [ -n "$BRAND_NAME" ]; then
  input_type="brand"
  INPUT_MATERIAL=$(read_input_material "brand" "$BRAND_NAME")
elif [ -n "$NOTES_TEXT" ]; then
  input_type="notes"
  INPUT_MATERIAL=$(read_input_material "notes" "$NOTES_TEXT")
elif [ -n "$SEED_TOPIC" ]; then
  input_type="seed"
  INPUT_MATERIAL=$(read_input_material "seed" "$SEED_TOPIC")
else
  input_type="project"
  if [ -z "$PROJECT_CONTEXT" ]; then
    gather_project_context
  fi
  INPUT_MATERIAL=$(read_input_material "project" "")
fi

# ── Auto-infer audience if not set ──
if [ -z "$AUDIENCE_TEXT" ] && [ -n "$INPUT_MATERIAL" ]; then
  start_spinner "👥 Inferring target audience"
  infer_tmp=$(mktemp)
  cat > "$infer_tmp" << INFER_EOF
From the following input, identify the target audience in one or two sentences. Who is this work ultimately trying to reach or move? Be specific - name the human beings, not demographics. Include the full range of life stages this touches, not just the youngest or most aspirational. If you genuinely cannot determine an audience, respond with exactly: UNKNOWN

INPUT TYPE: ${input_type}
INPUT: ${INPUT_MATERIAL}
${PROJECT_CONTEXT:+CONTEXT: ${PROJECT_CONTEXT}}
INFER_EOF
  if claude_call "$infer_tmp"; then
    if [ "$CLAUDE_RESPONSE" != "UNKNOWN" ] && [ -n "$CLAUDE_RESPONSE" ]; then
      AUDIENCE_TEXT="$CLAUDE_RESPONSE"
    fi
  fi
  rm -f "$infer_tmp"
  if [ -n "$AUDIENCE_TEXT" ]; then
    stop_spinner "done"
  else
    stop_spinner "skipped"
  fi
fi

# ── Banner ──
echo ""
echo "  🪟 THINK DIFFERENT FRAMEWORK"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Input: ${input_type}"
case "$input_type" in
  seed)  echo "  Seed: ${SEED_TOPIC:0:80}" ;;
  brief) echo "  Brief: $BRIEF_FILE" ;;
  brand) echo "  Brand: $BRAND_NAME" ;;
  notes) echo "  Notes: ${NOTES_TEXT:0:60}..." ;;
  project) echo "  Source: auto-detect from project" ;;
esac
echo "  Mode: $MODE"
if [ -n "$AUDIENCE_TEXT" ]; then
  echo "  Audience: ${AUDIENCE_TEXT:0:80}"
fi
if [ "$PROVOCATION_TONE" != "provocative" ]; then
  echo "  Tone: $PROVOCATION_TONE"
fi
if [ "$OUTPUT_TYPE" != "insight,brief,manifesto" ]; then
  echo "  Output types: $OUTPUT_TYPE"
fi
echo "  Presentation: ~${WORD_COUNT} words"
if [ -n "$CONTEXT_FILE" ]; then
  echo "  Context: $CONTEXT_FILE"
fi
echo "  Output: $OUTPUT_DIR"
if [ ${#EXPERIMENT_LINES[@]} -gt 0 ]; then
  echo "  Experiments:"
  for eline in "${EXPERIMENT_LINES[@]}"; do
    echo "$eline"
  done
fi
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Ground-only mode ──
if [ -n "$GROUND_ONLY" ]; then
  source "${SCRIPT_DIR}/context/gather.sh"
  source "${SCRIPT_DIR}/context/ground.sh"

  # Use seed or first line of input as the seed topic
  if [ -z "$SEED_TOPIC" ]; then
    SEED_TOPIC=$(echo "$INPUT_MATERIAL" | head -1)
  fi

  SESSION_DIR="$OUTPUT_DIR/$(slugify_seed "$SEED_TOPIC")_${TIMESTAMP}"
  mkdir -p "$SESSION_DIR"
  TRANSCRIPT_MD="$SESSION_DIR/session.md"
  TRANSCRIPT_JSON="$SESSION_DIR/session.json"
  md_init_header "Ground Check" "$SEED_TOPIC"
  json_open

  gather_project_context

  # Standalone grounding: surface assumptions, verify with web search if available
  ground_standalone

  json_flush
  md_flush

  echo ""
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✦ Ground check complete"
  echo ""
  echo "  📄 Transcript: $TRANSCRIPT_MD"
  echo "  📊 JSON:       $TRANSCRIPT_JSON"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 0
fi

# ── 2. Distil into seeds (always) ──
if ! generate_provocations "$INPUT_MATERIAL" "$input_type"; then
  if [ -n "$SEED_TOPIC" ]; then
    echo "  Using seed topic directly."
    PROVOCATIONS=("$SEED_TOPIC")
  elif [ -n "$INPUT_MATERIAL" ]; then
    echo "  Using input material as seed."
    PROVOCATIONS=("$(echo "$INPUT_MATERIAL" | head -1)")
  fi
fi

if [ ${#PROVOCATIONS[@]} -eq 0 ]; then
  echo "  No provocations generated and no fallback available. Exiting."
  exit 1
fi

SEEDS=("${PROVOCATIONS[@]}")

# ── 3. Pick (optional, any input type) ──
if [ -n "$PICK_MODE" ]; then
  pick_provocations
  SEEDS=("${PROVOCATIONS[@]}")
fi

# ── 4. Warn if many seeds ──
if [ ${#SEEDS[@]} -gt 5 ]; then
  est_hours=$(( ${#SEEDS[@]} * 15 / 60 ))
  echo "  Warning: ${#SEEDS[@]} seeds will run ~${est_hours}+ hours (each seed is a full session)."
  echo -n "  Continue? [y/N] "
  read -r confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "  Aborted. Use --pick to select fewer, or --seeds N to generate fewer."
    exit 0
  fi
fi

# ── 5. Run sessions ──
SESSION_DIR="$OUTPUT_DIR/$(slugify_seed "${SEEDS[0]}")_${TIMESTAMP}"
mkdir -p "$SESSION_DIR"

# Copy deferred context into session folder
if [ -n "$PROJECT_CONTEXT" ] && [ ! -f "$SESSION_DIR/context.md" ]; then
  echo "$PROJECT_CONTEXT" > "$SESSION_DIR/context.md"
fi

TRANSCRIPT_FILES=()
seed_num=1
for seed in "${SEEDS[@]}"; do
  echo ""
  echo "  ━━━ SEED ${seed_num}/${#SEEDS[@]} ━━━━━━━━━━━━━━━━━━━━━"
  echo "  ${seed}"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Set up session state
  SEED_TOPIC="$seed"
  CONVERSATION=""
  TURN_COUNT=0

  # Suffix for multiple sessions, clean for single
  if [ ${#SEEDS[@]} -gt 1 ]; then
    TRANSCRIPT_MD="$SESSION_DIR/session_s${seed_num}.md"
    TRANSCRIPT_JSON="$SESSION_DIR/session_s${seed_num}.json"
    STATE_FILE="$SESSION_DIR/session_s${seed_num}.state.json"
  else
    TRANSCRIPT_MD="$SESSION_DIR/session.md"
    TRANSCRIPT_JSON="$SESSION_DIR/session.json"
    STATE_FILE="$SESSION_DIR/session.state.json"
  fi

  md_init_header "Think Different Session (Seed ${seed_num})" "$SEED_TOPIC"
  json_open

  # Source and run the mode
  source "${SCRIPT_DIR}/modes/${MODE}.sh"
  run_session || true

  # Final flush (always valid, even on cap hit)
  json_flush
  md_flush

  if [ "$CAP_LIMIT_HIT" = "true" ]; then
    break
  fi

  # Mark session complete
  complete_state

  TRANSCRIPT_FILES+=("$TRANSCRIPT_MD")
  seed_num=$((seed_num + 1))
done

# ── 6. Output ──
# Skip presentation if cap was hit - transcript is saved, user can --report-only later
if [ "$CAP_LIMIT_HIT" = "true" ]; then
  exit 1
fi

PRES_FILE="$SESSION_DIR/presentation.md"
DOCX_FILE="$SESSION_DIR/presentation.docx"
HTML_FILE="$SESSION_DIR/presentation.html"

if [ ${#TRANSCRIPT_FILES[@]} -eq 1 ]; then
  # Single session - generate presentation directly from transcript
  PRES_CONTENT=$(generate_presentation "$CONVERSATION" "$SEED_TOPIC" "$WORD_COUNT" "$PRES_FILE" "${TURN_COUNT} turns, ${MODE} composition")

  MD_BUFFER="${MD_BUFFER}

---

## Presentation

${PRES_CONTENT}
"
  md_flush

  convert_to_docx "$PRES_FILE" "$DOCX_FILE"
  if [ "$HTML_ENABLED" = "true" ]; then
    convert_to_html "$PRES_FILE" "$HTML_FILE"
  fi

  echo ""
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✦ Session complete"
  echo "    ${#SEEDS[@]} seed, ${TURN_COUNT} turns, ${MODE} composition"
  echo ""
  echo "  📝 Presentation: $PRES_FILE"
  echo "  📄 Document:     $DOCX_FILE"
  if [ "$HTML_ENABLED" = "true" ]; then
    echo "  🌐 HTML:         $HTML_FILE"
  fi
  echo "  📄 Transcript:   $TRANSCRIPT_MD"
  echo "  📊 JSON:         $TRANSCRIPT_JSON"
  if [ -f "$SESSION_DIR/context.md" ]; then
    echo "  📍 Context:      $SESSION_DIR/context.md"
  fi
  echo ""
  echo "  Re-run presentation at different length:"
  echo "    $CMD_NAME --report-only $TRANSCRIPT_MD --words 1500"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
else
  # Multiple sessions - synthesise into one presentation
  seed_summary=""
  case "$input_type" in
    brief)   seed_summary="Distilled from brief: $(basename "$BRIEF_FILE")" ;;
    brand)   seed_summary="Distilled from brand: $BRAND_NAME" ;;
    notes)   seed_summary="Distilled from notes: ${NOTES_TEXT:0:100}" ;;
    seed)    seed_summary="Distilled from seed: ${SEEDS[0]:0:100}" ;;
    project) seed_summary="Distilled from project context" ;;
  esac

  synthesise_presentations "$WORD_COUNT" "$PRES_FILE" "$seed_summary" "${TRANSCRIPT_FILES[@]}" > /dev/null
  convert_to_docx "$PRES_FILE" "$DOCX_FILE"
  if [ "$HTML_ENABLED" = "true" ]; then
    convert_to_html "$PRES_FILE" "$HTML_FILE"
  fi

  echo ""
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✦ Session complete"
  echo "    ${#SEEDS[@]} seeds, ${MODE} composition"
  echo ""
  echo "  📝 Presentation: $PRES_FILE"
  echo "  📄 Document:     $DOCX_FILE"
  if [ "$HTML_ENABLED" = "true" ]; then
    echo "  🌐 HTML:         $HTML_FILE"
  fi
  for tf in "${TRANSCRIPT_FILES[@]}"; do
    echo "  📄 Transcript:  $tf"
  done
  echo ""
  echo "  Re-run presentation at different length:"
  echo "    $CMD_NAME --synthesise ${TRANSCRIPT_FILES[*]} --words 1500"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi
