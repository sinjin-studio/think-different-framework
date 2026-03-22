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

# ── Parse arguments ──

SEED_TOPIC=""
OUTPUT_DIR="./think_output"
WORD_COUNT="500-800"
MODE="dyslexic"
PRES_ONLY=""
PRES_SOURCE=""
CONTEXT_FILE=""
SYNTHESISE_MODE=""
SYNTHESISE_FILES=()
BRIEF_FILE=""
BRAND_NAME=""
NOTES_TEXT=""
PICK_MODE=""

# ── Experimental composition flags ──
INCLUDE_AGENTS=()
EXCLUDE_AGENTS=()
FRICTION_ENABLED="true"
BIAS_ENABLED="true"
SENSORY_ENABLED="true"
SHUFFLE_ENABLED="false"
ROUND_COUNT=""
SPIRAL_COUNT=""
PASS_COUNT=""

show_help() {
  echo ""
  echo "  🪟 THINK DIFFERENT FRAMEWORK"
  echo "  ─────────────────────────────"
  echo ""
  echo "  Direct seed (single session):"
  echo "    ./think.sh \"Your seed topic or question\""
  echo "    ./think.sh \"topic\" --mode spiral --words 1500"
  echo ""
  echo "  From raw input (auto-provoke, run all, synthesise):"
  echo "    ./think.sh --brief ./client-brief.pdf"
  echo "    ./think.sh --brand \"Nike\""
  echo "    ./think.sh --notes \"luxury wellness, Gen Z, sustainability\""
  echo "    ./think.sh --brief ./brief.pdf --pick    # interactive selection"
  echo "    ./think.sh --brief ./brief.pdf --mode spiral"
  echo ""
  echo "  With project context:"
  echo "    cd ~/projects/my-project && ~/think.sh \"seed topic\""
  echo "    ./think.sh \"seed topic\" --context ./brief.md"
  echo ""
  echo "  Manual synthesis of existing transcripts:"
  echo "    ./think.sh --synthesise ./run1/*.md ./run2/*.md --words 1500"
  echo ""
  echo "  Re-run presentation from existing transcript:"
  echo "    ./think.sh --report-only ./transcript.md --words 2000"
  echo ""
  echo "  Options:"
  echo "    --mode MODE      Composition: dyslexic (default), spiral, lapidary"
  echo "    --words N        Target word count for presentation (default: 500-800)"
  echo "    --output DIR     Output directory (default: ./think_output)"
  echo "    --context FILE   Explicit context file to ground the session"
  echo "    --brief FILE     Generate provocations from a brief file"
  echo "    --brand NAME     Generate provocations from a brand name"
  echo "    --notes TEXT     Generate provocations from working notes"
  echo "    --pick           Interactively select which provocations to run"
  echo "    --synthesise     Synthesise existing transcript files into one presentation"
  echo "    --report-only F  Regenerate presentation from existing transcript"
  echo "    --help           Show this help"
  echo ""
  echo "  Experimental:"
  echo "    --include A,B    Force-include agents by key (e.g. skeptic,anxious)"
  echo "    --exclude A,B    Force-exclude agents by key"
  echo "    --no-friction    Skip friction detection between rounds"
  echo "    --no-bias        Skip cognitive bias checks"
  echo "    --no-sensory     Skip sensory/context re-injection"
  echo "    --rounds N       Number of rounds (dyslexic default: 4)"
  echo "    --spirals N      Number of spirals (spiral default: 3)"
  echo "    --passes N       Number of passes (lapidary default: 3)"
  echo "    --shuffle        Randomize agent order within each round/phase"
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

# Determine which branch we're in
HAS_RAW_INPUT=""
if [ -n "$BRIEF_FILE" ] || [ -n "$BRAND_NAME" ] || [ -n "$NOTES_TEXT" ]; then
  HAS_RAW_INPUT="true"
fi

# Need at least one of: seed, raw input, presentation-only, synthesise, or project context
if [ -z "$PRES_ONLY" ] && [ -z "$SYNTHESISE_MODE" ] && [ -z "$SEED_TOPIC" ] && [ -z "$HAS_RAW_INPUT" ]; then
  # Try project auto-detect
  if [ -f "package.json" ] || [ -f "README.md" ] || [ -f "CLAUDE.md" ] || [ -d "src" ] || [ -d "app" ] || [ -f "Cargo.toml" ] || [ -f "pyproject.toml" ]; then
    HAS_RAW_INPUT="true"
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

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$OUTPUT_DIR"

# ── Source libraries ──

source "${SCRIPT_DIR}/lib/json.sh"
source "${SCRIPT_DIR}/lib/md.sh"
source "${SCRIPT_DIR}/lib/markers.sh"
source "${SCRIPT_DIR}/lib/call_agent.sh"
source "${SCRIPT_DIR}/report/generate.sh"

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

  PRES_FILE="$OUTPUT_DIR/presentation_${TIMESTAMP}.pptx"
  synthesise_presentations "$WORD_COUNT" "$PRES_FILE" "Cross-session synthesis" "${SYNTHESISE_FILES[@]}" > /dev/null

  echo ""
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✦ Synthesis complete"
  echo ""
  echo "  📝 Presentation: $PRES_FILE"
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
  echo "  Words: $WORD_COUNT"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  SEED_TOPIC=$(grep -m1 "Seed:" "$PRES_SOURCE" | sed 's/.*Seed:\*\* *//' | sed 's/^> \*\*Seed:\*\* //' | sed 's/^.*Seed: //')
  if [ -z "$SEED_TOPIC" ]; then
    SEED_TOPIC="[Seed not found in transcript]"
  fi

  CONVERSATION=$(cat "$PRES_SOURCE")
  PRES_FILE="$OUTPUT_DIR/presentation_${TIMESTAMP}.pptx"
  generate_presentation "$CONVERSATION" "$SEED_TOPIC" "$WORD_COUNT" "$PRES_FILE" > /dev/null

  echo ""
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✦ Presentation generated"
  echo ""
  echo "  📝 Presentation: $PRES_FILE"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 0
fi

# ══════════════════════════════════════════════
#  DISTILLATION BRANCH (raw input -> provocations -> sessions -> synthesis)
# ══════════════════════════════════════════════

if [ -n "$HAS_RAW_INPUT" ] && [ -z "$SEED_TOPIC" ]; then
  source "${SCRIPT_DIR}/context/provoke.sh"
  source "${SCRIPT_DIR}/context/gather.sh"
  source "${SCRIPT_DIR}/report/synthesise.sh"

  echo ""
  echo "  🪟 THINK DIFFERENT - Distillation Mode"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Mode: $MODE"
  echo "  Words: $WORD_COUNT"

  # Gather project context first (used by provocation generation)
  PROJECT_CONTEXT=""
  if [ -n "$CONTEXT_FILE" ]; then
    if [ -f "$CONTEXT_FILE" ]; then
      PROJECT_CONTEXT=$(cat "$CONTEXT_FILE")
      echo "  Context: $CONTEXT_FILE"
    fi
  fi

  # Read input material
  local_input_type=""
  local_input_material=""

  if [ -n "$BRIEF_FILE" ]; then
    local_input_type="brief"
    echo "  Brief: $BRIEF_FILE"
    local_input_material=$(read_input_material "brief" "$BRIEF_FILE") || {
      echo "Error: could not read brief file"
      exit 1
    }
  elif [ -n "$BRAND_NAME" ]; then
    local_input_type="brand"
    echo "  Brand: $BRAND_NAME"
    local_input_material=$(read_input_material "brand" "$BRAND_NAME")
  elif [ -n "$NOTES_TEXT" ]; then
    local_input_type="notes"
    echo "  Notes: ${NOTES_TEXT:0:60}..."
    local_input_material=$(read_input_material "notes" "$NOTES_TEXT")
  else
    local_input_type="project"
    echo "  Input: auto-detect from project"
    # Gather context if not already done
    if [ -z "$PROJECT_CONTEXT" ]; then
      gather_project_context
    fi
    local_input_material=$(read_input_material "project" "")
  fi

  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Generate provocations
  generate_provocations "$local_input_material" "$local_input_type"

  if [ ${#PROVOCATIONS[@]} -eq 0 ]; then
    echo "  No provocations generated. Exiting."
    exit 1
  fi

  # Interactive selection if --pick
  if [ -n "$PICK_MODE" ]; then
    pick_provocations
  fi

  # Run each provocation as a separate session
  TRANSCRIPT_FILES=()
  local prov_num=1
  for provocation in "${PROVOCATIONS[@]}"; do
    echo ""
    echo "  ━━━ PROVOCATION ${prov_num}/${#PROVOCATIONS[@]} ━━━━━━━━━━━━━"
    echo "  ${provocation}"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Set up session state for this provocation
    SEED_TOPIC="$provocation"
    CONVERSATION=""
    TURN_COUNT=0
    TRANSCRIPT_MD="$OUTPUT_DIR/session_${TIMESTAMP}_p${prov_num}.md"
    TRANSCRIPT_JSON="$OUTPUT_DIR/session_${TIMESTAMP}_p${prov_num}.json"

    md_init_header "Think Different Session (Provocation ${prov_num})" "$SEED_TOPIC"
    json_open

    # Source and run the mode
    source "${SCRIPT_DIR}/modes/${MODE}.sh"
    run_session

    # Close JSON
    json_close

    TRANSCRIPT_FILES+=("$TRANSCRIPT_MD")
    prov_num=$((prov_num + 1))
  done

  # Synthesise all transcripts into one presentation
  echo ""
  PRES_FILE="$OUTPUT_DIR/presentation_${TIMESTAMP}.pptx"

  local seed_summary=""
  if [ -n "$BRIEF_FILE" ]; then
    seed_summary="Distilled from brief: $(basename "$BRIEF_FILE")"
  elif [ -n "$BRAND_NAME" ]; then
    seed_summary="Distilled from brand: $BRAND_NAME"
  elif [ -n "$NOTES_TEXT" ]; then
    seed_summary="Distilled from notes: ${NOTES_TEXT:0:100}"
  else
    seed_summary="Distilled from project context"
  fi

  synthesise_presentations "$WORD_COUNT" "$PRES_FILE" "$seed_summary" "${TRANSCRIPT_FILES[@]}" > /dev/null

  echo ""
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✦ Distillation complete"
  echo "    ${#PROVOCATIONS[@]} provocations, ${MODE} composition"
  echo ""
  echo "  📝 Presentation: $PRES_FILE"
  for tf in "${TRANSCRIPT_FILES[@]}"; do
    echo "  📄 Transcript:  $tf"
  done
  echo ""
  echo "  Re-run presentation at different length:"
  echo "    ./think.sh --synthesise ${TRANSCRIPT_FILES[*]} --words 1500"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 0
fi

# ══════════════════════════════════════════════
#  DIRECT SEED SESSION
# ══════════════════════════════════════════════

TRANSCRIPT_MD="$OUTPUT_DIR/session_${TIMESTAMP}.md"
TRANSCRIPT_JSON="$OUTPUT_DIR/session_${TIMESTAMP}.json"
CONVERSATION=""
TURN_COUNT=0
PROJECT_CONTEXT=""

# ── Build experiment banner lines ──
EXPERIMENT_LINES=()
for inc in "${INCLUDE_AGENTS[@]}"; do
  EXPERIMENT_LINES+=("    + ${inc} (included via --include)")
done
for exc in "${EXCLUDE_AGENTS[@]}"; do
  EXPERIMENT_LINES+=("    - ${exc} (excluded via --exclude)")
done
[ "$FRICTION_ENABLED" != "true" ] && EXPERIMENT_LINES+=("    - friction (disabled via --no-friction)")
[ "$BIAS_ENABLED" != "true" ] && EXPERIMENT_LINES+=("    - bias (disabled via --no-bias)")
[ "$SENSORY_ENABLED" != "true" ] && EXPERIMENT_LINES+=("    - sensory (disabled via --no-sensory)")
[ -n "$ROUND_COUNT" ] && EXPERIMENT_LINES+=("    ~ rounds: ${ROUND_COUNT} (via --rounds)")
[ -n "$SPIRAL_COUNT" ] && EXPERIMENT_LINES+=("    ~ spirals: ${SPIRAL_COUNT} (via --spirals)")
[ -n "$PASS_COUNT" ] && EXPERIMENT_LINES+=("    ~ passes: ${PASS_COUNT} (via --passes)")
[ "$SHUFFLE_ENABLED" = "true" ] && EXPERIMENT_LINES+=("    ~ shuffle (agent order randomized)")

echo ""
echo "  🪟 THINK DIFFERENT FRAMEWORK"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Seed: ${SEED_TOPIC:0:80}"
echo "  Mode: $MODE"
echo "  Presentation: ~${WORD_COUNT} words"
if [ -n "$CONTEXT_FILE" ]; then
  echo "  Context: $CONTEXT_FILE"
else
  echo "  Context: auto-detect from project"
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

# Init outputs
md_init_header "Think Different Session ($MODE)" "$SEED_TOPIC"
json_open

# Source and run the mode
source "${SCRIPT_DIR}/modes/${MODE}.sh"
run_session

# Close JSON
json_close

# ── Generate presentation ──

PRES_FILE="$OUTPUT_DIR/presentation_${TIMESTAMP}.pptx"
PRES_CONTENT=$(generate_presentation "$CONVERSATION" "$SEED_TOPIC" "$WORD_COUNT" "$PRES_FILE" "${TURN_COUNT} turns, ${MODE} composition")

printf "\n\n---\n\n## Presentation\n\n" >> "$TRANSCRIPT_MD"
echo "$PRES_CONTENT" >> "$TRANSCRIPT_MD"

# ── Done ──
echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✦ Session complete"
echo "    ${TURN_COUNT} turns, ${MODE} composition"
echo ""
echo "  📝 Presentation: $PRES_FILE"
echo "  📄 Transcript:   $TRANSCRIPT_MD"
echo "  📊 JSON:         $TRANSCRIPT_JSON"
if [ -f "$OUTPUT_DIR/context_${TIMESTAMP}.md" ]; then
  echo "  📍 Context:      $OUTPUT_DIR/context_${TIMESTAMP}.md"
fi
echo ""
echo "  Re-run presentation at different length:"
echo "    ./think.sh --report-only $TRANSCRIPT_MD --words 1500"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
