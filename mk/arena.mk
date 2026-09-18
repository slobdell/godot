# Arenas: layouts, their static analysis, and proof that they're fair and do what they promise (arena stream, round 5).
# Owner: arena (see _agents/workstreams.md). Design and measurements: _agents/arenas.md. Included by the root Makefile.

.PHONY: arenas arena-test arena-report arena-pytest

ARENA_COMMA := ,

arenas: ## Regenerate arenas/*.json from tools/make_arenas.py (every layout is authored as half + its 180° mirror)
	$(PYTHON) tools/make_arenas.py arenas

arena-test: import arena-pytest ## The arena tests: layout schema v2, validation, collision, symmetric navigation, connectivity, and the report tool's own calibration
	$(MAKE) --no-print-directory test FILTER=arena

# Deliberately NOT in `make check`: it guards an instrument only this stream reads, and 14 s on every stream's check
# to protect arena's own tool is a bad trade. `make arena-test` is the gate, and the brief already requires it on
# every layout change.
arena-pytest: ## The arena report tool's own tests: sight, the centre observer, and the map rankings it must reproduce
	$(PYTHON) -m unittest discover -s tools -p 'test_arena*.py'

arena-report: ## Static analysis of every layout (views, routes, exposure) + a top-down plot each -> build/arenas/
	$(PYTHON) tools/arena_report.py --plot $(BUILD_DIR)/arenas --json $(BUILD_DIR)/arenas/report.json arenas/*.json \
		| grep -E '^(AMBUSH|ARENA_REPORT)' | cut -c1-200

.PHONY: arena-series
arena-series: import ## X4: every arena's fairness (swap-bases mirror matches) and fight shape (ARENAS=yard,pit SEEDS=8 FIRST_SEED=1 ARENA_FACTION=condemned or ARENA_GREEN=gangs ARENA_RUST=syndicate, ARENA_TIME=180 OUT=arena-series) -> build/$(OUT).json
	$(PYTHON) tools/arena_series.py --godot $(GODOT) --jobs $(or $(JOBS),3) --seeds $(or $(SEEDS),8) \
		--faction $(or $(ARENA_FACTION),condemned) --time-limit $(or $(ARENA_TIME),180) $(if $(ARENAS),--arenas $(ARENAS)) \
		$(if $(ARENA_GREEN),--green-faction $(ARENA_GREEN)) $(if $(ARENA_RUST),--rust-faction $(ARENA_RUST)) \
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

.PHONY: arena-candidates
arena-candidates: ## Stretch: propose generated layouts for a human to approve (CHARACTER=yard|boneyard|boulevard|open COUNT=3 STEPS=400) -> build/arena-candidates/index.html (never shipped automatically)
	$(PYTHON) tools/arena_generator.py --character $(or $(CHARACTER),yard) --count $(or $(COUNT),3) --steps $(or $(STEPS),400) \
		--out $(BUILD_DIR)/arena-candidates 2>&1 | grep ARENA_CANDIDATE

.PHONY: nav-maze
# NAV_UNITS, not UNITS: mk/ai.mk sets `UNITS ?= 60` globally, so a nav-maze that read UNITS silently ran 60 units
# while its own help text and every report said 30. Heed this before adding a bare variable name to a shared Makefile.
nav-maze: import ## N3/CP2: send NAV_UNITS vehicles across The Maze and report arrivals, timing, crawling and stuck events (NAV_UNITS=30 ARENA=maze NAV_TIME=180 SEED=1 NAV_BOTH=1 for head-on traffic) -> build/nav-maze.json
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/arena/maze_probe.gd -- \
		--units=$(or $(NAV_UNITS),30) --arena=$(or $(ARENA),maze) --time-limit=$(or $(NAV_TIME),180) \
		--seed=$(or $(SEED),1) $(if $(NAV_BOTH),--both-ways) --json=$(CURDIR)/$(BUILD_DIR)/$(or $(OUT),nav-maze).json
	@echo ">> nav-maze: build/$(or $(OUT),nav-maze).json"

.PHONY: slope-probe
slope-probe: import ## X4: what slope the navmesh bakes over and a vehicle can climb (a measurement, nothing ships) -> build/slopes.json
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/arena/slope_probe.gd -- \
		--json=$(CURDIR)/$(BUILD_DIR)/slopes.json

.PHONY: arena-page
arena-page: ## X5: the lead's arena review page -- every shipping arena as a picture plus what it measures, one self-contained file (needs make arena-report and make remote T=arena-shots first) -> build/arena-page/index.html
	$(PYTHON) tools/arena_page.py --report $(BUILD_DIR)/arenas/report.json --out $(BUILD_DIR)/arena-page/index.html
