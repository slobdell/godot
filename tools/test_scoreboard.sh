#!/usr/bin/env bash
# Known answers for the round scoreboard's reader and table (round 35, X5 (a)): tools/scoreboard/test_score.py.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
python3 "$here/scoreboard/test_score.py"
