#!/usr/bin/env bash
# ── Spiral re-seeding ──
# Extracts the most surprising insight from the previous spiral's
# integration and uses it to re-seed the next spiral.
# Expects globals: $CONVERSATION, $TRANSCRIPT_MD, $TRANSCRIPT_JSON
# Depends on: lib/json.sh

reseed() {
  local spiral_num="$1"
  local reseed_text="$2"

  echo "  ↻ Re-seeding spiral ${spiral_num}..."
  CONVERSATION="${CONVERSATION}

=== SPIRAL ${spiral_num} RE-SEED ===
The session pivots. The most surprising insight from the previous spiral: ${reseed_text}
Let this pull the conversation somewhere unexpected."
  MD_BUFFER="${MD_BUFFER}
> **Re-seed:** ${reseed_text:0:300}
"
}

extract_reseed() {
  local spiral_num="$1"

  python3 -c "
import json, sys
with open('${TRANSCRIPT_JSON}', 'r') as f:
    content = f.read().rstrip().rstrip(',')
    data = json.loads(content + ']')
integrators = [e for e in data if e['lens'] == 'integrator' and e.get('spiral', 0) == ${spiral_num}]
if integrators:
    text = integrators[-1]['content']
    parts = []
    for s in text.replace('...', '.').split('.'):
        s = s.strip()
        if s:
            parts.append(s)
            if len(parts) >= 2:
                break
    print('. '.join(parts) + '.')
else:
    print('Unexpected connections have emerged.')
"
}
