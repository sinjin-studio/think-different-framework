#!/usr/bin/env bash
# ── Sensory check ──
# Re-injects project context mid-session as bottom-up signal
# colliding with top-down predictions.
# Expects globals: $PROJECT_CONTEXT, $CONVERSATION

sensory_check() {
  [ "$SENSORY_ENABLED" != "true" ] && return
  if [ -z "$PROJECT_CONTEXT" ] && [ -z "${ZEITGEIST_CONTEXT:-}" ]; then
    return
  fi

  if [ -n "$PROJECT_CONTEXT" ]; then
    CONVERSATION="${CONVERSATION}

=== GROUND TRUTH ===
Here is what is actually true about this situation. Not to correct the thinking but to collide with it. Notice where the lenses' ideas rub against reality. That friction is interesting.
${PROJECT_CONTEXT}"
  fi

  if [ -n "${ZEITGEIST_CONTEXT:-}" ]; then
    CONVERSATION="${CONVERSATION}

=== KNOWN TERRITORY ===
Here is what the broader conversation already covers. Not to constrain the thinking but to challenge it. If the session is only reaching territory these sources already occupy, it has not gone far enough.
${ZEITGEIST_CONTEXT}"
  fi
}
