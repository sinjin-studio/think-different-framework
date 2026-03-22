#!/usr/bin/env bash
# ── Markdown helpers ──
# Shared markdown output functions for transcript files.
# Expects globals: $TRANSCRIPT_MD

md_init_header() {
  local title="$1"
  local seed="$2"

  cat > "$TRANSCRIPT_MD" << MDHEADER
# ${title}

> **Seed:** ${seed}
> **Date:** $(date '+%Y-%m-%d %H:%M')

---

MDHEADER
}

md_append_agent() {
  local emoji="$1"
  local name="$2"
  local bias="$3"
  local content="$4"

  echo "" >> "$TRANSCRIPT_MD"
  echo "**${emoji} ${name}** _${bias}_" >> "$TRANSCRIPT_MD"
  echo "" >> "$TRANSCRIPT_MD"
  echo "${content}" >> "$TRANSCRIPT_MD"
  echo "" >> "$TRANSCRIPT_MD"
}

md_append_section() {
  local level="$1"
  local text="$2"

  if [ "$level" = "2" ]; then
    printf "\n---\n\n## %s\n" "$text" >> "$TRANSCRIPT_MD"
  else
    printf "\n### %s\n" "$text" >> "$TRANSCRIPT_MD"
  fi
}
