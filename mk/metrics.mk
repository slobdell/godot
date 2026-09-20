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
