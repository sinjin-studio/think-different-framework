# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A multi-agent structured divergence framework for Claude Code CLI. It runs creative thinking sessions by dispatching multiple AI agents (each with a distinct cognitive bias) through composition modes inspired by neurodivergent thinking patterns. Raw input (briefs, brand names, notes) is distilled into seed provocations, each run through a multi-agent session, then synthesized into a structured presentation.

## Commands

```bash
# Direct seed
./think.sh "How might luxury wellness appeal to Gen Z?"
./think.sh "seed" --mode spiral --words 1500

# From raw input (generates provocations)
./think.sh --brief ./client-brief.pdf
./think.sh --brand "Nike"
./think.sh --notes "luxury wellness, Gen Z, sustainability"

# Interactive provocation selection
./think.sh --brief ./brief.pdf --pick

# Presentation-only (regenerate from existing transcript)
./think.sh --report-only ./transcript.md --words 2000

# Synthesise multiple transcripts
./think.sh --synthesise ./run1/*.md ./run2/*.md --words 1500

# Test assumption grounding in isolation
./think.sh "seed" --ground-only
```

### Key Flags

- `--mode {dyslexic|spiral|lapidary}` - Composition mode (default: dyslexic)
- `--words N` - Target word count (default: 500-800)
- `--output DIR` - Output directory (default: ./think_output)
- `--context FILE` - Explicit context file
- `--rounds N`, `--spirals N`, `--passes N` - Customize phase counts
- `--include/--exclude agents` - Force agent inclusion/exclusion
- `--no-friction`, `--no-bias`, `--no-sensory` - Disable mechanisms
- `--shuffle` - Randomize agent order within rounds

### npm Distribution

```bash
npm install -g @sinjin/think-different-framework
think-different "seed topic"   # or: td "seed topic"
```

## Architecture

### Three-Layer Taxonomy

1. **Perceivers** (8 agents) - How you see. Each has a cognitive bias lens (empathy, compression, literal, threat-awareness, naivety, absence, incongruence, quality/proportion).
2. **Cognitions** (11 agents) - What you do with what you see. Grouped into fragmentary (break, leap, shift, name), deepening (open, rhyme, integrate), and evaluative (weigh, root, pare).
3. **Compositions** (3 modes) - How you sequence perceivers + cognitions together.

### Three Composition Modes

| Mode | Cognitions | Character | Steps |
|------|-----------|-----------|-------|
| **Dyslexic** (`dyslexic.sh`) | Fragmentary + Logician | Leaping, collision-driven | ~30 |
| **Spiral** (`spiral.sh`) | Deepening | 3 widening-then-crystallizing spirals | ~34 |
| **Lapidary** (`lapidary.sh`) | Evaluative + Logician | Iterative refinement/polish | ~23 |

### Agent Dispatch System

`lib/call_agent.sh` is the core dispatcher. Each agent script (in `agents/`) exports 4 functions: `agent_emoji_${key}`, `agent_name_${key}`, `agent_bias_${key}`, `agent_system_${key}`. The dispatcher calls Claude Code CLI directly: `claude -p --system-prompt "$system_prompt"`.

COMMON_RULES (defined in `lib/call_agent.sh`) are applied to every agent call - 150-200 word constraint, first-person prose, no lists, no em-dashes.

### Conversation Threading

A global `$CONVERSATION` string accumulates all agent responses. Each agent reads the full history and adds its perspective. Friction/bias/sensory mechanisms inject meta-commentary as special markers between agent turns.

### Pipeline Flow

1. **Ground** - Surface assumptions (stated/inferred/unknown)
2. **Mode-specific seed prep** - Fracture (dyslexic), tune (spiral), or appraise (lapidary)
3. **Rounds/spirals/passes** with interspersed mechanisms (friction, sensory, bias)
4. **Between-phase operations** - Re-seeding (spiral) or polish (lapidary)
5. **Report generation** - Extract conversation into 6-section article, optional .pptx

### Key Directories

- `agents/` - 19 agents across `perceivers/`, `cognitions/{fragmentary,deepening,evaluative}/`, `hybrids/`
- `modes/` - Three composition orchestrators
- `context/` - Input handling (gather, ground, provoke, fracture, tune, appraise)
- `mechanisms/` - Meta-cognitive operations (friction, sensory, bias, reseed, polish)
- `lib/` - Shared utilities (dispatch, JSON/MD transcript output, markers)
- `report/` - Presentation generation and synthesis

### Output

Sessions produce files in `./think_output/`:
- `presentation_*.md` - Structured article (Provocation, Landscape, Insight, Tension, Experiment, Sources)
- `presentation_*.pptx` - PowerPoint slides (if python-pptx available)
- `session_*.md` / `session_*.json` - Full transcript (markdown + machine-readable)
- `context_*.md` - Project context brief (if gathered)

## Dependencies

- Bash 3.2+ (macOS compatible - no bash 4+ features)
- Claude Code CLI (`claude` binary in PATH)
- Python 3 + python-pptx (optional, for .pptx output)

## Conventions

- **Bash 3.2 compatibility is mandatory** - Array shuffling uses RANDOM, avoid associative arrays and other bash 4+ features. Recent bugs have been around unbound variables with empty arrays.
- **No em-dashes** - Use hyphens or commas instead. Enforced in COMMON_RULES for all agent output.
- **`set -euo pipefail`** in think.sh - Agents fail gracefully but pipeline errors halt execution.
- **Phase labeling** - Three UNIT_LABEL types: "round" (dyslexic), "spiral" (spiral), "pass" (lapidary).
- **Agent key-based dispatch** - Keys like `empath`, `provocateur` are decoupled from display names.
- **Conversation markers** - Mechanism sections use `=== MECHANISM (unit type number) ===` headers.
- **Temp file cleanup** - Uses `mktemp`, always cleaned up with `rm -f`.
- **Plan-aware seed defaults** - `claude auth status` detects subscription type. Pro=1 seed, Max/Enterprise/Team=3 seeds. User `--seeds` flag always overrides.
- No automated test suite - framework is experimental/research-oriented, tested manually via CLI.
