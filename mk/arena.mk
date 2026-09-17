# Arenas: layouts, their static analysis, and proof that they're fair and do what they promise (arena stream, round 5).
# Owner: arena (see _agents/workstreams.md). Design and measurements: _agents/arenas.md. Included by the root Makefile.

.PHONY: arenas arena-test arena-report

ARENA_COMMA := ,

arenas: ## Regenerate arenas/*.json from tools/make_arenas.py (every layout is authored as half + its 180° mirror)
	$(PYTHON) tools/make_arenas.py arenas

arena-test: import ## The arena tests: layout schema v2, validation, collision, symmetric navigation, connectivity
	$(MAKE) --no-print-directory test FILTER=arena

arena-report: ## Static analysis of every layout (views, routes, exposure) + a top-down plot each -> build/arenas/
	$(PYTHON) tools/arena_report.py --plot $(BUILD_DIR)/arenas --json $(BUILD_DIR)/arenas/report.json arenas/*.json | cut -c1-240

.PHONY: arena-series
arena-series: import ## X4: every arena's fairness (swap-bases mirror matches) and fight shape (ARENAS=yard,pit SEEDS=8 FIRST_SEED=1 ARENA_FACTION=condemned TIME=180 OUT=arena-series) -> build/$(OUT).json
	$(PYTHON) tools/arena_series.py --godot $(GODOT) --jobs $(or $(JOBS),3) --seeds $(or $(SEEDS),8) \
		--faction $(or $(ARENA_FACTION),condemned) --time-limit $(or $(TIME),180) $(if $(ARENAS),--arenas $(ARENAS)) \
		--first-seed $(or $(FIRST_SEED),1) --json $(BUILD_DIR)/$(or $(OUT),arena-series).json

.PHONY: arena-shots
arena-shots: import ## Every arena in pictures: the match runner's whole-arena view and the player's skirmish view, at 1920x1080 (ARENAS=yard,pit DELAY=20) -> build/screenshots/arena-*.png (needs a display: make remote T=arena-shots)
	mkdir -p $(BUILD_DIR)/screenshots
	for arena in $(or $(subst $(ARENA_COMMA), ,$(ARENAS)),$(basename $(notdir $(wildcard arenas/*.json)))); do \
		$(GODOT) --path . --resolution 1920x1080 -- --match --elimination --control --arena=$$arena \
			--green-faction=condemned --rust-faction=condemned --budget=5200 --time-limit=300 --seed=1 \
			--screenshot-delay=$(or $(DELAY),20) --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/arena-$$arena-overview.png \
			2>&1 | grep -E "ERROR|SCRIPT" || true; \
		$(GODOT) --path . --resolution 1920x1080 -- --skirmish --scripted --arena=$$arena --screenshot-delay=$(or $(DELAY),20) \
			--screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/arena-$$arena-skirmish.png 2>&1 | grep -E "ERROR|SCRIPT" || true; \
	done
	ls $(BUILD_DIR)/screenshots/arena-*.png
