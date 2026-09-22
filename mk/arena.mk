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
# NAV_FLAGS reaches the probe (round 8). Without it this target accepted `--nav-off=flow`, ignored it, and ran the
# SAME TREATMENT TWICE: nav's flow-field A/B came back byte-identical on both arms — a clean, quiet null that looks
# exactly like "the change does nothing". A measuring target that silently drops the thing being measured is worse
# than one that refuses it.
nav-maze: import ## N3/CP2: send NAV_UNITS vehicles across The Maze and report arrivals, timing, crawling and stuck events (NAV_UNITS=30 ARENA=maze NAV_TIME=180 SEED=1 NAV_BOTH=1 for head-on traffic, NAV_FLAGS=--nav-off=flow) -> build/nav-maze.json
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/arena/maze_probe.gd -- \
		--units=$(or $(NAV_UNITS),30) --arena=$(or $(ARENA),maze) --time-limit=$(or $(NAV_TIME),180) \
		--seed=$(or $(SEED),1) $(if $(NAV_BOTH),--both-ways) $(NAV_FLAGS) --json=$(CURDIR)/$(BUILD_DIR)/$(or $(OUT),nav-maze).json
	@echo ">> nav-maze: build/$(or $(OUT),nav-maze).json"

.PHONY: slope-probe
slope-probe: import ## X4: what slope the navmesh bakes over and a vehicle can climb (a measurement, nothing ships) -> build/slopes.json
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/arena/slope_probe.gd -- \
		--json=$(CURDIR)/$(BUILD_DIR)/slopes.json

.PHONY: arena-page
arena-page: ## X5: the lead's arena review page -- every shipping arena as a picture plus what it measures, one self-contained file (needs make arena-report and make remote T=arena-shots first) -> build/arena-page/index.html
	$(PYTHON) tools/arena_page.py --report $(BUILD_DIR)/arenas/report.json --out $(BUILD_DIR)/arena-page/index.html

.PHONY: arena-reach
arena-reach: import ## X2: write the catalog's covering ranges (Engagement.covering_range) to build/arena-reach.json, which arena-report reads
	$(GODOT) --headless --path . --script res://tests/arena/reach_probe.gd -- --json=$(CURDIR)/$(BUILD_DIR)/arena-reach.json

.PHONY: water-probe
water-probe: import ## Round 7: does a carved navmesh hole give us water (impassable, fire-transparent)? BRIDGE=1 restores a strip -> build/water.json
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/arena/water_probe.gd -- \
		$(if $(BRIDGE),--bridge) --json=$(CURDIR)/$(BUILD_DIR)/water$(if $(BRIDGE),-bridge).json

# R4 (round 10): the Terminus streets at the lead's pose, before (the round-9 layout frozen in tests/arena/before/)
# and after (the shipping layout), one frame per named street; `make arena-page` shows the pairs when they exist.
STREETS_DIR := $(BUILD_DIR)/terminus-streets
STREETS_FLAGS := --skirmish --mute --seed=3 --player-faction=condemned --enemy-faction=syndicate
.PHONY: terminus-streets
terminus-streets: import ## R4: every Terminus street at the lead's pose (21 deg, FOV 35, 49 m), round-9 layout vs today's -> build/terminus-streets/ (needs a display: make remote T=terminus-streets)
	rm -rf $(STREETS_DIR) && mkdir -p $(STREETS_DIR) && touch $(BUILD_DIR)/.gdignore
	timeout 240 $(GODOT) --path . --resolution 1920x1080 --script res://tests/arena/street_shots.gd -- $(STREETS_FLAGS) \
		--arena=res://tests/arena/before/terminus_round9.json --street-shots=$(CURDIR)/$(STREETS_DIR) --street-shots-tag=before 2>&1 \
		| tee $(STREETS_DIR)/before.log | grep -E 'STREET_SHOTS_DONE|SCRIPT ERROR|^ERROR' || true
	timeout 240 $(GODOT) --path . --resolution 1920x1080 --script res://tests/arena/street_shots.gd -- $(STREETS_FLAGS) \
		--arena=terminus --street-shots=$(CURDIR)/$(STREETS_DIR) --street-shots-tag=after 2>&1 \
		| tee $(STREETS_DIR)/after.log | grep -E 'STREET_SHOTS_DONE|SCRIPT ERROR|^ERROR' || true
	grep -q 'STREET_SHOTS_DONE tag=before' $(STREETS_DIR)/before.log
	grep -q 'STREET_SHOTS_DONE tag=after' $(STREETS_DIR)/after.log
	@echo "Now LOOK at $(STREETS_DIR)/*_before.jpg against *_after.jpg"

.PHONY: terminus-streets-page
terminus-streets-page: ## R4: the before/after street pairs with each street's narrowest width, one self-contained file -> build/terminus-streets/index.html (after make remote T=terminus-streets)
	$(PYTHON) tools/street_page.py --commit $$(git rev-parse --short HEAD)

# ---- Terrain (round 10, the terrain stream's; additive): water, pits, bridges -------------------------------------
.PHONY: terrain-pytest terrain-shots

terrain-pytest: ## Terrain: the Python water/bridge mirror against the golden file Godot is held to, and the report routing round water
	$(PYTHON) -m unittest tools/test_arena_terrain.py

## Spots and scale hulls per terrain map: name:x:z for the camera, x:z:yaw for a hull. The dry twin is shot from the same pose.
TERRAIN_SHOT_ARENAS ?= crossing sumps
TERRAIN_SPOTS_crossing ?= bridge:-92:14,neck:0:22,landing:-76:-22,far_bridge:92:-14
TERRAIN_HULLS_crossing ?= -92:12:0,-88:36:10,-78:-20:170,6:48:0,70:18:200
TERRAIN_SPOTS_sumps ?= catwalk:-55:14,causeway:-27:14,lip:-40:40,far:-52:-22
TERRAIN_HULLS_sumps ?= -55:10:0,-27:20:10,-44:40:0,-50:-22:170,-84:30:0

terrain-shots: import ## Terrain: each terrain map at the lead's pose (21 deg, FOV 35, 49 m) beside its dry twin, plus an overview -> build/terrain-shots/ (needs a display: make remote T=terrain-shots)
	rm -rf $(BUILD_DIR)/terrain-shots && mkdir -p $(BUILD_DIR)/terrain-shots
	@# $(foreach), not a shell loop over a nested `make`: every make target takes a heavy-run slot, and a recipe that
	@# already holds one waiting for another is a deadlock.
	$(foreach arena,$(TERRAIN_SHOT_ARENAS),timeout 600 $(GODOT) --path . --resolution 1920x1080 \
		--script res://game/theme/arena_kit/terrain/tools/terrain_shots.gd -- --arena=$(arena) \
		--out=$(CURDIR)/$(BUILD_DIR)/terrain-shots --spots=$(TERRAIN_SPOTS_$(arena)) --hulls=$(TERRAIN_HULLS_$(arena)) \
		> $(BUILD_DIR)/terrain-shots/$(arena).log 2>&1 || true; \
		grep -E 'TERRAIN_SHOT|SCRIPT ERROR|^ERROR' $(BUILD_DIR)/terrain-shots/$(arena).log || true; \
		grep -q 'TERRAIN_SHOTS_DONE ok=true' $(BUILD_DIR)/terrain-shots/$(arena).log || { echo "terrain-shots: $(arena) failed"; exit 1; };)
	ls $(BUILD_DIR)/terrain-shots/*.png

.PHONY: terrain-series terrain-measure
terrain-series: import ## Terrain (R9): a terrain map vs its dry twin on the SAME seeds -- unit-time on the crossings, time at the contested objective, discordant pairs (TERRAIN_MAP=crossing SEEDS=32 FIRST_SEED=1 ARENA_FACTION=condemned ARENA_TIME=180) -> build/terrain-series-<map>.json
	$(PYTHON) tools/terrain_series.py --godot $(GODOT) --map $(or $(TERRAIN_MAP),crossing) --seeds $(or $(SEEDS),32) \
		--first-seed $(or $(FIRST_SEED),1) --jobs $(or $(JOBS),3) --faction $(or $(ARENA_FACTION),condemned) \
		--time-limit $(or $(ARENA_TIME),180) --json $(BUILD_DIR)/terrain-series-$(or $(TERRAIN_MAP),crossing).json \
		| grep -E '^TERRAIN_(RUN|SERIES)'

terrain-measure: ## Terrain: the ring-of-eyes centre figure and plain objective routes beside arena-report's (no Godot)
	$(PYTHON) tools/terrain_measure.py arenas/crossing.json arenas/crossing_dry.json arenas/sumps.json arenas/sumps_dry.json

.PHONY: terrain-page
terrain-page: ## Terrain: the lead's page -- every terrain map's frames beside its dry twin, and the numbers (after make remote T=terrain-shots) -> build/terrain-page/index.html
	$(PYTHON) tools/terrain_page.py --shots $(BUILD_DIR)/terrain-shots --series $(BUILD_DIR) --out $(BUILD_DIR)/terrain-page/index.html $(TERRAIN_SHOT_ARENAS)
