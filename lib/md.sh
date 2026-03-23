#!/usr/bin/env bash
# ── Markdown helpers ──
# Buffered markdown output with atomic flush via temp+mv.
# Files are always in a valid state on disk.
# Expects globals: $TRANSCRIPT_MD, $OUTPUT_DIR

# ── Buffer ──
MD_HEADER=""
MD_BUFFER=""

md_init_header() {
  local title="$1"
  local seed="$2"

  MD_HEADER="# ${title}

> **Seed:** ${seed}
> **Date:** $(date '+%Y-%m-%d %H:%M')

---
"
  MD_BUFFER=""
}

md_append_agent() {
  local emoji="$1"
  local name="$2"
  local bias="$3"
  local content="$4"

  MD_BUFFER="${MD_BUFFER}
**${emoji} ${name}** _${bias}_

${content}
"
}

md_append_section() {
  local level="$1"
  local text="$2"

  if [ "$level" = "2" ]; then
    MD_BUFFER="${MD_BUFFER}
---

## ${text}
"
  else
    MD_BUFFER="${MD_BUFFER}
### ${text}
"
  fi
}

# ── Write complete markdown to disk (atomic) ──
md_flush() {
  [ -z "${TRANSCRIPT_MD:-}" ] && return

  local tmp_md
  tmp_md=$(mktemp "$(dirname "$TRANSCRIPT_MD")/.tmp_md.XXXXXX")

  printf "%s\n%s" "$MD_HEADER" "$MD_BUFFER" > "$tmp_md"
  mv "$tmp_md" "$TRANSCRIPT_MD"
}
