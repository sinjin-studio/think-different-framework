#!/usr/bin/env bash
# ── JSON helpers ──
# Buffered JSON output with atomic flush via temp+mv.
# Files are always in a valid state on disk.
# Expects globals: $TRANSCRIPT_JSON, $UNIT_LABEL, $OUTPUT_DIR

# ── Buffer ──
JSON_ENTRIES=()

json_escape() {
  python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"
}

json_open() {
  JSON_ENTRIES=()
}

json_close() {
  json_flush
}

json_append_entry() {
  local lens_key="$1"
  local name="$2"
  local emoji="$3"
  local bias="$4"
  local phase="$5"
  local unit_num="$6"
  local turn="$7"
  local content="$8"

  local escaped_content
  escaped_content=$(echo "$content" | json_escape)

  local entry
  entry=$(printf '{"lens":"%s","name":"%s","emoji":"%s","bias":"%s","phase":"%s","%s":%s,"turn":%s,"content":%s}' \
    "$lens_key" "$name" "$emoji" "$bias" "$phase" "$UNIT_LABEL" "$unit_num" "$turn" "$escaped_content")

  JSON_ENTRIES+=("$entry")
}

# ── Write complete valid JSON to disk (atomic) ──
json_flush() {
  [ -z "${TRANSCRIPT_JSON:-}" ] && return

  local tmp_json
  tmp_json=$(mktemp "$(dirname "$TRANSCRIPT_JSON")/.tmp_json.XXXXXX")

  if [ ${#JSON_ENTRIES[@]} -eq 0 ]; then
    echo "[]" > "$tmp_json"
  else
    printf "[\n" > "$tmp_json"
    local i
    for (( i=0; i<${#JSON_ENTRIES[@]}; i++ )); do
      if [ "$i" -gt 0 ]; then
        printf ",\n" >> "$tmp_json"
      fi
      printf "  %s" "${JSON_ENTRIES[$i]}" >> "$tmp_json"
    done
    printf "\n]\n" >> "$tmp_json"
  fi

  mv "$tmp_json" "$TRANSCRIPT_JSON"
}
