# metrics (round 9, A12): trajectory-space metrics. Owner: metrics (see _agents/workstreams.md, contract S3).
# The tool reads the per-tick trajectory log defined in tools/metrics/FORMAT.md and reports windowed displacement
# efficiency, signed cusp density, spectral arc length and the affine formation residual.
#
# Pure Python, no third-party dependency -- `make check` must not grow one for a measurement tool, and the numbers
# must be identical on the laptop and on builder0.

METRICS_DIR := tools/metrics
LOGS ?=

.PHONY: metrics metrics-pytest metrics-check metrics-fixtures

metrics: ## A12: the four trajectory metrics over LOGS="build/metrics/*.jsonl" (METRICS_JSON=path also writes JSON)
	@test -n "$(LOGS)" || { echo 'usage: make metrics LOGS="build/metrics/*.jsonl"'; exit 2; }
	$(PYTHON) $(METRICS_DIR)/run_metrics.py $(LOGS) $(if $(METRICS_JSON),--json $(METRICS_JSON))

# `-v` and the collected count are the point, not decoration: arena shipped four bare `def test_*` functions that
# `unittest discover` never ran and nobody noticed for a round (_agents/workstreams.md, Invariant 0). A suite that
# collects zero tests passes, silently, forever. So we read the count and fail on it.
metrics-pytest: ## The metrics tools' own known-answer tests (and it FAILS if the suite collected nothing)
	@out=$$($(PYTHON) -m unittest discover -s $(METRICS_DIR) -p 'test_*.py' -v 2>&1); \
	echo "$$out" | tail -3; \
	ran=$$(echo "$$out" | grep -oE '^Ran [0-9]+ test' | grep -oE '[0-9]+' || echo 0); \
	echo "metrics-pytest: collected $$ran tests"; \
	test "$$ran" -gt 0 || { echo "metrics-pytest FAILED: unittest discovered NO tests (bare functions are not collected)"; exit 1; }; \
	echo "$$out" | tail -1 | grep -qE '^(OK|OK \()' || { echo "$$out"; exit 1; }

# The synthetic fixtures with the hand-computed answers beside them: `make metrics` over these is the smoke test
# that the tool runs end to end, and the README names each one's expected value.
metrics-fixtures: ## Write the synthetic trajectory fixtures to build/metrics/fixtures/ and run the metrics over them
	$(PYTHON) $(METRICS_DIR)/make_fixtures.py $(BUILD_DIR)/metrics/fixtures
	$(PYTHON) $(METRICS_DIR)/run_metrics.py "$(BUILD_DIR)/metrics/fixtures/*.jsonl"

metrics-check: metrics-pytest metrics-fixtures ## Everything this stream verifies headless

# ---- ai-scenarios in `check`, behind a committed count (lesson 159, orchestrator's call 2026-09-20) ------------
#
# nav found squad's leash commit errors in a scenario `check` never ran. The scenarios are not IN `check` because
# one of them is a laptop-speed perf case that fails on slow hardware -- so adding them as a pass/fail gate would
# redden the gate for a reason that is not a defect, and lesson 42 says do not add a red suite to the gate.
#
# So the gate is on the COUNT, not on the outcome: the committed line in tests/baselines/ai_scenarios_count.txt
# names the machine and the counts it was taken on, and `ai-scenarios-check` fails when the counts CHANGE. A new
# script error moves `failed` and is caught; the pre-existing perf failure sits in the baseline and is not.
#
# The count file, like the lint baseline and unlike sim_state_hash.txt, is NOT machine-keyed -- but the perf case
# IS machine-sensitive, so the file records which machine the counts came from and the target says so on failure.
AI_SCENARIOS_BASELINE := tests/baselines/ai_scenarios_count.txt

.PHONY: ai-scenarios-check ai-scenarios-record

ai-scenarios-check: import ## The AI behaviour scenarios, gated on a CHANGE in the passed/failed/pending counts
	@mkdir -p $(BUILD_DIR)
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- \
		> $(BUILD_DIR)/ai-scenarios.log 2>&1 || true
	@line=$$(grep -E '^scenarios: ' $(BUILD_DIR)/ai-scenarios.log | tail -1); \
	if [ -z "$$line" ]; then \
		echo "ai-scenarios-check FAILED: the runner printed no summary line at all."; \
		echo "  That is a crashed or refused run, not a clean one -- the last 20 lines:"; \
		tail -20 $(BUILD_DIR)/ai-scenarios.log | sed 's/^/    /'; \
		exit 1; \
	fi; \
	counts=$$(echo "$$line" | grep -oE '[0-9]+' | paste -sd,); \
	expected=$$(grep -v '^#' $(AI_SCENARIOS_BASELINE) 2>/dev/null | grep -v '^$$' | head -1 | cut -d' ' -f1); \
	if [ -z "$$expected" ]; then \
		echo "ai-scenarios-check FAILED: no baseline in $(AI_SCENARIOS_BASELINE)."; \
		echo "  Record one with: make ai-scenarios-record   (counts now: $$counts)"; \
		exit 1; \
	fi; \
	if [ "$$counts" != "$$expected" ]; then \
		echo "ai-scenarios-check FAILED: the counts CHANGED."; \
		echo "  expected (passed,failed,pending,unexpectedly_passing): $$expected"; \
		echo "  got:                                                   $$counts"; \
		echo "  baseline was recorded on: $$(grep -E '^# machine:' $(AI_SCENARIOS_BASELINE) | cut -d' ' -f3-)"; \
		echo "  this machine: $$(hostname)"; \
		echo "  $$line"; \
		grep -E '^  (FAIL|UNEXPECTED PASS)' $(BUILD_DIR)/ai-scenarios.log | sed 's/^/    /' | head -20; \
		echo "  If the change is intended, re-record with `make ai-scenarios-record` and say why in the commit."; \
		exit 1; \
	fi; \
	echo "ai-scenarios-check: $$line (unchanged against $(AI_SCENARIOS_BASELINE))"

# Writes to build/ rather than straight into tests/baselines/, exactly like `sim-baseline-record`: `make remote`
# copies build/ back AND NOTHING ELSE, so a target that writes into the repo records the number onto builder0 and
# then loses it. The copy is one line and it is the reader's, so re-recording a gate is always deliberate.
ai-scenarios-record: import ## Record this machine's ai-scenarios counts to build/ (then copy over the baseline)
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- \
		> $(BUILD_DIR)/ai-scenarios.log 2>&1 || true
	@line=$$(grep -E '^scenarios: ' $(BUILD_DIR)/ai-scenarios.log | tail -1); \
	test -n "$$line" || { echo "no summary line; refusing to record nothing"; exit 1; }; \
	counts=$$(echo "$$line" | grep -oE '[0-9]+' | paste -sd,); \
	{ echo "# ai-scenarios counts: passed,failed,pending,unexpectedly_passing"; \
	  echo "# `make ai-scenarios-check` fails when these CHANGE, not when a scenario fails: one perf case is"; \
	  echo "# laptop-speed-sensitive and would redden the gate for a reason that is not a defect (lesson 42),"; \
	  echo "# while a new script error moves \`failed\` and is caught (lesson 159)."; \
	  echo "# machine: $$(hostname)"; \
	  echo "# commit:  $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown})"; \
	  echo "# line:    $$line"; \
	  echo "$$counts"; } > $(BUILD_DIR)/ai_scenarios_count.txt; \
	cat $(BUILD_DIR)/ai_scenarios_count.txt; \
	echo "recorded $$counts on $$(hostname) in $(BUILD_DIR)/ai_scenarios_count.txt"; \
	echo "  cp $(BUILD_DIR)/ai_scenarios_count.txt $(AI_SCENARIOS_BASELINE)   # and say WHY in the commit"
