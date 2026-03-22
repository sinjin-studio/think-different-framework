#!/usr/bin/env bash
# ── JSON helpers ──
# Shared JSON output functions for transcript files.
# Expects globals: $TRANSCRIPT_JSON, $UNIT_LABEL

json_escape() {
  python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"
}

json_open() {
  echo "[" > "$TRANSCRIPT_JSON"
}

json_close() {
  printf "\n]\n" >> "$TRANSCRIPT_JSON"
}

json_append_entry() {
  local agent_key="$1"
  local name="$2"
  local emoji="$3"
  local bias="$4"
  local phase="$5"
  local unit_num="$6"
  local turn="$7"
  local content="$8"

  local escaped_content
  escaped_content=$(echo "$content" | json_escape)

  if [ "$turn" -gt 0 ]; then
    printf "," >> "$TRANSCRIPT_JSON"
  fi

  printf '\n  {"agent":"%s","name":"%s","emoji":"%s","bias":"%s","phase":"%s","%s":%s,"turn":%s,"content":%s}' \
    "$agent_key" "$name" "$emoji" "$bias" "$phase" "$UNIT_LABEL" "$unit_num" "$turn" "$escaped_content" \
    >> "$TRANSCRIPT_JSON"
}
