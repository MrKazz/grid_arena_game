#!/usr/bin/env bash
# Claude Code Stop hook: when Claude finishes a turn that changed game files,
# run the tests. On failure, exit 2 so Claude sees the output and keeps
# working instead of stopping with a red suite.
INPUT="$(cat)"
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || exit 0

# Avoid an endless loop if Claude already tried to fix a failure once.
if echo "$INPUT" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi
# Only run when game files have uncommitted changes.
if ! git status --porcelain | grep -qE '\.(gd|tscn|tres|godot|cfg)$'; then
  exit 0
fi

OUTPUT="$(tools/run_tests.sh 2>&1)"
status=$?
if [[ $status -eq 127 ]]; then
  exit 0  # Godot not installed here; nothing to check against.
elif [[ $status -ne 0 ]]; then
  {
    echo "Godot tests are failing after your changes. Fix them before finishing:"
    echo "$OUTPUT" | grep -E "FAIL|ERROR|failed|passed" | head -n 40
  } >&2
  exit 2
fi
exit 0
