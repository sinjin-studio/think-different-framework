# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A multi-lens structured divergence framework for Claude Code CLI. It runs creative thinking sessions by dispatching multiple cognitive lenses (each with a distinct bias) through composition modes inspired by neurodivergent thinking patterns. Raw input (briefs, brand names, notes) is distilled into seed provocations, each run through a thinking session, then synthesized into a structured presentation.

**Autonomous mode is on by default.** A conductor agent orchestrates lenses with autonomous decision-making, lenses can skip turns when they have nothing new to add, mechanisms return structured decisions that influence session flow, and a reviewer can restart sessions with mutations when output is conventional. Use `--no-autonomous` to fall back to hardcoded composition sequences.

## Commands

```bash
# Direct seed
./think.sh "How might luxury wellness appeal to Gen Z?"
./think.sh "seed" --mode spiral --words 1500

# Non-autonomous mode (hardcoded composition sequences)
./think.sh "seed" --no-autonomous

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
- `--words N` - Total word budget across all presentation sections (default: 1500). Auto-drops sections at low budgets unless `--type` is explicit
- `--output DIR` - Output directory (default: ./think-different-output)
- `--context FILE` - Explicit context file
- `--rounds N`, `--spirals N`, `--passes N` - Customize phase counts for non-autonomous modes (defaults: 7, 5, 5)
- `--turns N` - Max turns for autonomous conductor (default: 35)
- `--min-turns N` - Min turns before conductor can end session (default: 15)
- `--include/--exclude lenses` - Force lens inclusion/exclusion
- `--audience TEXT` - Target audience (auto-inferred from input if not set). Shapes provocations and all presentation output toward audience-facing content
- `--tone TONE` - Provocation tone: `provocative` (default), `generous`, `personal`, `absurd`, `daydream`, `mixed`. Comma-separated for custom mix (e.g. `--tone provocative,generous`)
- `--depth LEVEL` - Lens depth: `deep` (default), `deeper`, `deepest`. Per-lens: `mortal:deepest,achala:deeper`. Controls how deep into fundamental human drivers the lenses go. Affects Mortal, Achala, Empath, Child, Provocateur
- `--type TYPES` - Output types: `insight,brief,manifesto` (default: all three). Comma-separated
- `--lines N` - Number of angles to generate (default: 3, max: 7). Each angle outputs two altitudes: Platform (strategic truth) and Expression (audience-facing punch)
- `--practitioners LIST` - Comma-separated creative practitioners as quality bar for The Line (default: random 3 from built-in pool)
- `--html` - Enable HTML presentation generation (experimental, off by default)
- `--formats LIST` - Output formats for `--report-only`: `all`, `md`, `doc`, `html` (comma-separated)
- `--no-friction`, `--no-bias`, `--no-sensory`, `--no-transcendence`, `--no-negative-space` - Disable mechanisms
- `--shuffle` - Randomize lens order within rounds
- `--autonomous` - Enable agentic mode (default: on)
- `--no-autonomous` - Disable agentic mode, use hardcoded composition sequences (also disables auto-wait)
- `--no-wait` - Disable auto-wait on cap hit (default: wait and poll in autonomous mode)
- `--skip-strict` - Use separate pre-call for skip-turn (default: inline detection)
- `--compact` - Enable context compaction (off by default, opt in for very long sessions)
- `--allowedTools TOOLS` - Tools for Claude CLI (default: `"WebSearch,WebFetch"`, use `""` to disable)

### npm Distribution

```bash
npm install -g @sinjin/think-different-framework
think-different "seed topic"   # or: td "seed topic"
```

## Architecture

### Taxonomy (aligned with Anthropic's terms)

- **Lenses** (perceivers + cognitions) - Cognitive perspectives. Not agents or skills. Each sees through a specific bias.
- **Modes** - Composition strategies / conductor presets. How lenses are sequenced together.
- **Mechanisms** - Metacognitive operations (friction, sensory, bias, transcendence, review). Return structured JSON decisions that influence session flow.
- **Conductor** - The framework's first true agent. Orchestrates lenses autonomously in `--autonomous` mode. Has tool use (via dispatched lenses), decision-making (choosing sequence), and evaluate-decide-act loops (via reviewer).
- **Reviewer** - Adversarial quality gate using prosecution/defense/verdict pattern. The prosecution assumes the session failed and searches for prior art. The defense concedes weak ideas and argues only for genuine divergence. The verdict decides restart/proceed. Can trigger session restart with mutations.

### Three-Layer Lens Taxonomy

1. **Perceivers** (9 lenses) - How you see. Each has a cognitive bias (empathy, compression, literal, finitude/impermanence/urgency, naivety, absence, incongruence, quality/proportion, resolve/interconnection).
2. **Cognitions** (11 lenses) - What you do with what you see. Grouped into fragmentary (break, leap, shift, name), deepening (open, rhyme, integrate), and evaluative (weigh, root, pare).
3. **Compositions** (3 modes) - How you sequence perceivers + cognitions together.

### Three Composition Modes

| Mode | Cognitions | Character | Steps |
|------|-----------|-----------|-------|
| **Dyslexic** (`dyslexic.sh`) | Fragmentary + Logician | Leaping, collision-driven | ~50 |
| **Spiral** (`spiral.sh`) | Deepening | 5 widening-then-crystallizing spirals | ~55 |
| **Lapidary** (`lapidary.sh`) | Evaluative + Logician | Iterative refinement/polish | ~40 |

In autonomous mode, these become conductor presets rather than hardcoded sequences.

### Lens Dispatch System

`lib/call_lens.sh` is the core dispatcher. Each lens script (in `lenses/`) exports functions: `lens_emoji_${key}`, `lens_name_${key}`, `lens_bias_${key}`, `lens_system_${key}`, and optionally `lens_tools_${key}` (per-lens tool access). The dispatcher calls Claude Code CLI directly: `claude -p --system-prompt "$system_prompt"`.

**Per-lens tool access:** Observer, Empath, Skeptic, Mortal, and Logician have `WebSearch,WebFetch` enabled. Other lenses stay tool-free (thinking from feeling, not facts).

**Inline skip-turn (--autonomous):** Each lens decides within its response whether it has something new to add. If it responds with `SKIP: reason`, the turn is logged and skipped without a separate pre-call. Use `--skip-strict` to restore the original two-call pattern.

**Context compaction (off by default):** When enabled via `--compact`, every 8-10 turns or when the conversation exceeds ~15K characters, the full history is distilled into a 400-600 word digest plus the last 3-4 verbatim turns. Disabled by default because research shows breakthroughs often arrive at iteration 10+ and compaction destroys the raw phrasing that fuels them. Opus 4.6's 1M context window handles full conversations comfortably. Full transcript always preserved in output files.

COMMON_RULES (defined in `lib/call_lens.sh`) are applied to every lens call - 150-200 word constraint, first-person prose, no lists, no em-dashes.

### Conductor (--autonomous mode)

`lib/conductor_loop.sh` implements the agentic orchestration loop. The conductor (`lenses/conductor.sh`) makes structured JSON decisions about which lens speaks next, what instruction to give, whether to trigger a mechanism, and when to end the session.

Guard rails: max 35 turns, minimum 15 turns before ending, minimum 7 distinct lenses before grounding, two-strike transcendence (requires two consecutive signals before triggering early grounding), cap awareness. Auto-wait on cap hit (polls with backoff until credits reset, max 4 hours) - enables unattended overnight runs. Disable with `--no-wait`.

### Conversation Threading

A global `$CONVERSATION` string accumulates all lens responses. Each lens reads the history and adds its perspective. Mechanisms inject meta-commentary and structured decisions between lens turns.

**Context compaction** (`compact_conversation()` in `lib/call_lens.sh`): Off by default. When enabled via `--compact`, every 8-10 turns or when the conversation exceeds ~15K characters, the history is distilled into a 400-600 word digest plus the last 3-4 verbatim turns. Disabled by default because late-arriving breakthroughs (iteration 10+) need access to raw phrasing from earlier turns. Full transcript is always preserved in MD/JSON output files.

### Mechanism Flow Control

Mechanisms return structured JSON decisions alongside their conversation append:
- **Friction** returns `{recommendation: "deepen|redirect|continue", inject_lens: "..."}` - can inject a specific lens to break stuck patterns
- **Transcendence** returns `{has_breakthrough: bool, recommendation: "compress|continue|ground_early"}` - can skip to grounding
- **Bias** returns `{biases_detected: [...], recommendation: "..."}` - identifies cognitive biases as creative fuel
- **Negative Space** returns `{territories: [...], pattern_of_avoidance: "...", recommendation: "redirect_to_void|note_and_continue|void_is_intentional"}` - maps unexplored territory and can redirect a lens into the dark patches

**Mechanism memory** (`MECHANISM_MEMORY` array in `lib/call_lens.sh`): Each mechanism appends its findings to a structured log. Subsequent mechanisms receive a MECHANISM HISTORY section listing prior findings, with the instruction to focus on what's new or evolved. This prevents amnesiac re-discovery of the same tensions. The conductor's state summary also includes mechanism memory. Persisted in `session.state.json` for resume continuity.

Flow control helpers in `lib/call_lens.sh`: `handle_friction_decision()`, `handle_transcendence_decision()`, `handle_negative_space_decision()`.

### Zeitgeist Context

When web search is enabled during provocation generation, Claude may return source citations alongside provocations. These are captured as `ZEITGEIST_SOURCES` and built into a `ZEITGEIST_CONTEXT` block representing "known territory" - what broader discourse already covers. This context is threaded into:
- **Seed prep** (fracture/tune/appraise) - external anchors for assumption grounding
- **Sensory mechanism** - re-injected mid-session as `=== KNOWN TERRITORY ===` alongside ground truth
- **Negative space mechanism** - contrasts known discourse against session territory for sharper negative space detection
- **Review prosecution** - head start on prior art identification

Lenses do not receive zeitgeist directly - they encounter it through mechanisms, keeping lens calls clean.

### Provocation Review Gate

When multiple provocations are generated (`--autonomous` mode), they pass through two gates:
1. **Distinctness review** - Similar provocations get merged, weak ones get reframed. Each should open territory the others cannot reach.
2. **Quality prosecution** - Each provocation is prosecuted for genuine quality: is it truly provocative or just unusual phrasing of a common question? Does it contain real tension? Weak provocations get sharpened.

### Session Reviewer

Adversarial quality gate (`mechanisms/review.sh`) using a prosecution/defense/verdict pattern:
1. **Prosecution** - Assumes the session failed. Scores novelty 1-10, names closest prior art for each major idea. Uses WebSearch.
2. **Defense** - Concedes weak ideas, argues only for genuine divergence from prior art cited.
3. **Verdict** - Decides restart/proceed from the adversarial exchange. Identifies unpushed tensions and provides a reframed seed if restart needed.

Can trigger a **restart with mutations**: different mode, shuffled lens order, reframed seed. 2-run ceiling per provocation. Synthesises across both runs.

### Line Prosecution

After The Line is generated and the strongest expression picked, the winning PLATFORM+EXPRESSION pair passes through an adversarial prosecution loop (max 2 iterations):
1. **Prosecute** - Tests briefability (can a team build from it?), cold-readability (lands on a wall?), and specificity (only works for this topic?)
2. **Improve** - If weak, generates 2 alternatives that fix identified weaknesses
3. **Re-judge** - Picks between original and alternatives

This ensures The Line, the most visible output, receives adversarial treatment comparable to the session review.

### Verbose Session Log

Every `claude_call*` invocation is logged to `$SESSION_DIR/log.jsonl` (JSONL format, one JSON object per line). Each entry captures: timestamp, caller identifier (e.g. `lens:empath`, `mechanism:negative_space`, `conductor`), call type, prompt excerpt (first 500 chars), full response, exit code, and cap hit status. Callers set `VERBOSE_CALLER` before invoking `claude_call*`. Excludes the growing conversation context - just individual prompts and responses.

### Pipeline Flow

1. **Seed prep with embedded grounding** - Fracture (dyslexic), tune (spiral), or appraise (lapidary). Each surfaces and web-verifies assumptions before preparing the seed
2. **Provocation review** (autonomous mode) - checks distinctness of generated provocations
3. **Rounds/spirals/passes** (or conductor loop in autonomous mode) with interspersed mechanisms
4. **Session review** (autonomous mode) - baseline test, novelty search, tension check. Can restart with mutations
5. **Between-phase operations** - Re-seeding (spiral) or polish (lapidary)
6. **Report generation** - Distil session findings (ranked by novelty), generate The Line (platform + expression, strongest picked from N angles), the asset (sensory/tactile creative description), then creative brief, manifesto, and insight article. All sections receive the distillation to anchor on the deepest material. Optional .docx

### Key Directories

- `lenses/` - 20 lenses across `perceivers/`, `cognitions/{fragmentary,deepening,evaluative}/`, `hybrids/`, plus `conductor.sh`
- `modes/` - Three composition orchestrators (used in non-autonomous mode, become conductor presets in autonomous mode)
- `context/` - Input handling (gather, ground preamble, provoke, fracture, tune, appraise)
- `mechanisms/` - Meta-cognitive operations (friction, sensory, bias, transcendence, negative_space, reseed, polish, review)
- `lib/` - Shared utilities (dispatch, conductor loop, JSON/MD transcript output, markers)
- `report/` - Presentation generation, synthesis, and format converters (docx, html)
- `report/html-template/` - Astro project for developing the HTML template (`npm run dev` for hot reload)

### Output

Sessions produce files in `./think-different-output/<slug>_<timestamp>/`:
- `presentation.md` - Combined output: The Line (winning platform + expression), the experiment, the asset (sensory description), creative brief, manifesto, insight article (controlled by `--type`), session findings (novel ideas for inspiration), runner-up lines (non-winning platform/expression pairs)
- `presentation.docx` - Branded Word document (if python-docx available)
- `presentation.html` - Cinematic scroll presentation with GSAP ScrollTrigger (enable with `--html`, experimental)
- `session.md` / `session.json` - Full transcript (markdown + machine-readable)
- `session.state.json` - Session state for resume capability
- `log.jsonl` - Verbose session log (every Claude call/response, JSONL format)
- `context.md` - Project context brief (if gathered)

## Dependencies

- Bash 3.2+ (macOS compatible - no bash 4+ features)
- Claude Code CLI (`claude` binary in PATH)
- Python 3 + python-docx (optional, for .docx output)

## Conventions

- **Bash 3.2 compatibility is mandatory** - Array shuffling uses RANDOM, avoid associative arrays and other bash 4+ features. Recent bugs have been around unbound variables with empty arrays.
- **No em-dashes** - Use hyphens or commas instead. Enforced in COMMON_RULES for all lens output.
- **`set -euo pipefail`** in think.sh - Lenses fail gracefully but pipeline errors halt execution.
- **Phase labeling** - Three UNIT_LABEL types: "round" (dyslexic), "spiral" (spiral), "pass" (lapidary), "turn" (conductor).
- **Lens key-based dispatch** - Keys like `empath`, `provocateur` are decoupled from display names.
- **Conversation markers** - Mechanism sections use `=== MECHANISM (unit type number) ===` headers.
- **Temp file cleanup** - Uses `mktemp`, always cleaned up with `rm -f`.
- **Plan-aware seed defaults** - `claude auth status` detects subscription type. Pro=1 seed, Max/Enterprise/Team=3 seeds. User `--seeds` flag always overrides.
- No automated test suite - framework is experimental/research-oriented, tested manually via CLI.
