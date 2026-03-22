#!/usr/bin/env bash
# ── Sensory check ──
# Re-injects project context mid-session as bottom-up signal
# colliding with top-down predictions.
# Expects globals: $PROJECT_CONTEXT, $CONVERSATION

sensory_check() {
  [ "$SENSORY_ENABLED" != "true" ] && return
  if [ -z "$PROJECT_CONTEXT" ]; then
    return
  fi

  CONVERSATION="${CONVERSATION}

=== GROUND TRUTH ===
Here is what is actually true about this situation. Not to correct the thinking but to collide with it. Notice where the agents' ideas rub against reality. That friction is interesting.
${PROJECT_CONTEXT}"
}
