#!/usr/bin/env bash
# Runs the headless test suite. Used by the git pre-commit hook, the Claude
# Code Stop hook and CI. Extra args are passed to the runner, e.g.:
#   tools/run_tests.sh --filter=deck
# Godot is found via $GODOT_BIN, then $GODOT_PATH (same var the MCP server
# uses), then `godot` / `godot4` on PATH.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-${GODOT_PATH:-$(command -v godot || command -v godot4 || true)}}"
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
  echo "run_tests: Godot executable not found. Set GODOT_BIN to its path." >&2
  exit 127
fi

# Refresh the import cache so class_name scripts and resources resolve.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
"$GODOT" --headless --path "$ROOT" -s res://tests/run_tests.gd -- "$@" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}

# GDScript has no exceptions: runtime errors are logged and execution carries
# on, so treat any engine-reported script error as a failure. Leaked objects
# at exit usually mean a reference cycle (e.g. a lambda capturing the object
# whose signal it is connected to), so fail on those too.
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Invalid call|Invalid access|instances were leaked|resources still in use" "$LOG"; then
  echo "run_tests: engine reported script errors or leaks (see above)." >&2
  status=1
fi
exit "$status"
