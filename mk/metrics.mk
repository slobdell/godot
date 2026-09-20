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
#
# ---- Only the NON-PENDING counts are gated (2026-09-20, found by combat on a pristine tree) --------------------
#
# The gate's first run on `main` failed `scenario_dodge_rate`, and the finding was wrong -- not about that
# scenario, about the BASELINE. That scenario has never passed on merit: its own header says "KNOWN-FAILING
# since CP4 ... Not in make check", dodging has never really fired, and which variant collects the few attempts
# reshuffles with any change. It happened to pass at `1cb2fda9`, so a coin landed heads at the exact moment the
# baseline was recorded and the gate inherited a 2% pass as its expectation. **A baseline records whatever was
# true the instant it was taken, including luck** -- which is why it now carries the commit and the machine, and
# why a scenario whose failure is KNOWN belongs in `const PENDING` where a tool can read it, not in prose.
#
# So: `passed` and `failed` are the gate. `pending` and `unexpectedly_passing` are REPORTED and never fail it --
# a PENDING scenario is one we expect to fail, and one that passes by luck must not redden eight streams'
# checks. The report is not silence: a move there prints, because a pending behaviour that starts working is
# news worth promoting, just not news worth failing a gate over (lesson 42).
AI_SCENARIOS_BASELINE := tests/baselines/ai_scenarios_count.txt
# REASON reaches the recorder through the ENVIRONMENT, unexpanded, and never through a shell word.
# Quoting it into the recipe failed the same two ways `FILTER` did and one worse: a `'` broke the recipe
# outright (`Unterminated quoted string`), and `$` was eaten by MAKE before any shell saw it (`$HOME` ->
# `OME`). `export ... := $(value REASON)` hands the literal text to the child's environment, so quotes,
# backticks, dollars and semicolons all arrive as typed. Verified against all five before it shipped.
export AI_SCENARIOS_REASON := $(value REASON)

.PHONY: ai-scenarios-check ai-scenarios-record

ai-scenarios-check: import ## The AI behaviour scenarios, gated on a CHANGE in the non-pending counts
	@mkdir -p $(BUILD_DIR)
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- \
		> $(BUILD_DIR)/ai-scenarios.log 2>&1 || true
	@$(METRICS_DIR)/ai_scenarios_gate.sh check $(BUILD_DIR)/ai-scenarios.log $(AI_SCENARIOS_BASELINE)

# Writes to build/ rather than straight into tests/baselines/, exactly like `sim-baseline-record`: `make remote`
# copies build/ back AND NOTHING ELSE, so a target that writes into the repo records the number onto builder0 and
# then loses it. The copy is one line and it is the reader's, so re-recording a gate is always deliberate.
ai-scenarios-record: import ## Record this machine's ai-scenarios counts to build/ (then copy over the baseline)
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- \
		> $(BUILD_DIR)/ai-scenarios.log 2>&1 || true
	@test -n "$(value REASON)" || { \
		echo "ai-scenarios-record: REASON= is required -- what moved the counts, and why it is correct."; \
		echo "  A baseline that records a number without its cause is how this gate inherited a 2% coin."; \
		echo '  e.g. make remote T='"'"'ai-scenarios-record REASON="suppression bar became a separation (combat 364d77f2)"'"'"; \
		exit 2; }
	@$(METRICS_DIR)/ai_scenarios_gate.sh record $(BUILD_DIR)/ai-scenarios.log $(BUILD_DIR)/ai_scenarios_count.txt
	@echo "  cp $(BUILD_DIR)/ai_scenarios_count.txt $(AI_SCENARIOS_BASELINE)   # and say WHY in the commit"

.PHONY: error-type-probe
error-type-probe: import ## What integer a Logger receives per message kind (the Jolt WARNING charged as an error)
	@$(GODOT) --headless --path . --script res://tests/probes/error_type_probe.gd 2>&1 | grep -E "^PROBE_|WARNING:|ERROR:" | head -40
