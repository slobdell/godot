# Arenas: layouts, their static analysis, and proof that they're fair and do what they promise (arena stream, round 5).
# Owner: arena (see _agents/workstreams.md). Design and measurements: _agents/arenas.md. Included by the root Makefile.

.PHONY: arenas arena-test arena-report

arenas: ## Regenerate arenas/*.json from tools/make_arenas.py (every layout is authored as half + its 180° mirror)
	$(PYTHON) tools/make_arenas.py arenas

arena-test: import ## The arena tests: layout schema v2, validation, collision, symmetric navigation, connectivity
	$(MAKE) --no-print-directory test FILTER=arena

arena-report: ## Static analysis of every layout (views, routes, exposure) + a top-down plot each -> build/arenas/
	$(PYTHON) tools/arena_report.py --plot $(BUILD_DIR)/arenas --json $(BUILD_DIR)/arenas/report.json arenas/*.json | cut -c1-240
