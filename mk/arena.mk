# Arenas: layouts, their static analysis, and proof that they're fair and do what they promise (arena stream, round 5).
# Owner: arena (see _agents/workstreams.md). Design and measurements: _agents/arenas.md. Included by the root Makefile.

.PHONY: arenas arena-test arena-report

arenas: ## Regenerate arenas/*.json from tools/make_arenas.py (every layout is authored as half + its 180° mirror)
	$(PYTHON) tools/make_arenas.py arenas

arena-test: import ## The arena tests: layout schema v2, validation, collision, symmetric navigation, connectivity
	$(MAKE) --no-print-directory test FILTER=arena

arena-report: ## Static analysis of every layout (views, routes, exposure) + a top-down plot each -> build/arenas/
	$(PYTHON) tools/arena_report.py --plot $(BUILD_DIR)/arenas --json $(BUILD_DIR)/arenas/report.json arenas/*.json | cut -c1-240

.PHONY: arena-series
arena-series: import ## X4: every arena's fairness (swap-bases mirror matches) and fight shape (ARENAS=yard,pit SEEDS=8 FACTION=condemned TIME=180) -> build/arena-series.json
	$(PYTHON) tools/arena_series.py --godot $(GODOT) --jobs $(or $(JOBS),3) --seeds $(or $(SEEDS),8) \
		--faction $(or $(FACTION),condemned) --time-limit $(or $(TIME),180) $(if $(ARENAS),--arenas $(ARENAS)) \
		--json $(BUILD_DIR)/arena-series.json
