#!/usr/bin/env bash
# Known answers for the round scoreboard's reader and table (round 35, X5 (a)): tools/scoreboard/test_score.py; and its
# verdict (round 36: a preempted run is no row), tools/scoreboard/test_verdict.sh.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
python3 "$here/scoreboard/test_score.py" || exit 1
bash "$here/scoreboard/test_verdict.sh"
