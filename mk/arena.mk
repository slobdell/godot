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
terminus-streets-page: import ## R4: the before/after street pairs with each street's narrowest width and every map's lane readability, one self-contained file -> build/terminus-streets/index.html (after make remote T=terminus-streets)
	mkdir -p $(STREETS_DIR)
	$(GODOT) --headless --path . --script res://tests/arena/lane_read_probe.gd -- --out=$(CURDIR)/$(STREETS_DIR)/lane_read.json 2>&1 \
		| grep -E 'LANE_READ_PROBE|SCRIPT ERROR|^ERROR' || true
	$(PYTHON) tools/street_page.py --commit $$(git rev-parse --short HEAD)

# ---- Terrain (round 10, the terrain stream's; additive): water, pits, bridges -------------------------------------
.PHONY: terrain-pytest terrain-shots

terrain-pytest: ## Terrain: the Python water/bridge mirror against the golden file Godot is held to, and the report routing round water
	$(PYTHON) -m unittest tools/test_arena_terrain.py

## Spots and scale hulls per terrain map: name:x:z for the camera, x:z:yaw for a hull. The dry twin is shot from the same pose.
TERRAIN_SHOT_ARENAS ?= crossing sumps locks pit terminus_canal
TERRAIN_SPOTS_crossing ?= bridge:-92:14,neck:0:22,landing:-76:-22,far_bridge:92:-14
TERRAIN_HULLS_crossing ?= -92:12:0,-88:36:10,-78:-20:170,6:48:0,70:18:200
TERRAIN_SPOTS_sumps ?= catwalk:-55:14,causeway:-27:14,lip:-40:40,far:-52:-22
TERRAIN_HULLS_sumps ?= -55:10:0,-27:20:10,-44:40:0,-50:-22:170,-84:30:0
TERRAIN_SPOTS_locks ?= lock:0:4,swing_bridge:-92:0,far_quay:-72:-24,canal:-55:0
TERRAIN_HULLS_locks ?= 0:4:0,-2:-8:180,-92:6:0,-70:-24:170,-30:15:90
TERRAIN_SPOTS_pit ?= corner_pit:-50:40,gate:0:36,far_yard:-66:-40
TERRAIN_HULLS_pit ?= -38:52:90,0:44:0,-62:-44:170
TERRAIN_SPOTS_terminus_canal ?= avenue_bridge:0:30,west_bridge:-70:30,canal:-35:30
TERRAIN_HULLS_terminus_canal ?= 0:28:0,-70:34:0,-40:44:90
## A layout whose "before" frame is not `<name>_dry` (a proposal drawn on a real map).
TERRAIN_DRY_terminus_canal ?= terminus

terrain-shots: import ## Terrain: each terrain map at the lead's pose (21 deg, FOV 35, 49 m) beside its dry twin, plus an overview -> build/terrain-shots/ (needs a display: make remote T=terrain-shots)
	rm -rf $(BUILD_DIR)/terrain-shots && mkdir -p $(BUILD_DIR)/terrain-shots
	@# $(foreach), not a shell loop over a nested `make`: every make target takes a heavy-run slot, and a recipe that
	@# already holds one waiting for another is a deadlock.
	$(foreach arena,$(TERRAIN_SHOT_ARENAS),timeout 600 $(GODOT) --path . --resolution 1920x1080 \
		--script res://game/theme/arena_kit/terrain/tools/terrain_shots.gd -- --arena=$(arena) \
		--out=$(CURDIR)/$(BUILD_DIR)/terrain-shots --spots=$(TERRAIN_SPOTS_$(arena)) --hulls=$(TERRAIN_HULLS_$(arena)) \
		$(if $(TERRAIN_DRY_$(arena)),--dry=$(TERRAIN_DRY_$(arena))) \
		> $(BUILD_DIR)/terrain-shots/$(arena).log 2>&1 || true; \
		grep -E 'TERRAIN_SHOT|SCRIPT ERROR|^ERROR' $(BUILD_DIR)/terrain-shots/$(arena).log || true; \
		grep -q 'TERRAIN_SHOTS_DONE ok=true' $(BUILD_DIR)/terrain-shots/$(arena).log || { echo "terrain-shots: $(arena) failed"; exit 1; };)
	ls $(BUILD_DIR)/terrain-shots/*.png

# Round 12 (arena, A1/A3): the wet look as PAIRS at the lead's pose, one dial per step (WaterLook.STEPS), every water
# map and both pit maps (a pit must not change between steps: changed_px 0), frozen at one instant of the swell.
WATER_PAIR_ARENAS ?= crossing locks terminus_canal sumps pit
WATER_LOOKS ?= r10,a_body,a_flood,b_venue,c_lamps,c_swell,d_lap
.PHONY: water-pairs
water-pairs: import ## Arena (round 12): each water and pit map at the lead's pose once per WaterLook step (r10 -> what ships) + WATER_STATS (water luma, black share, changed pixels) -> build/water-pairs/ (needs a display: make remote T=water-pairs)
	rm -rf $(BUILD_DIR)/water-pairs && mkdir -p $(BUILD_DIR)/water-pairs
	$(foreach arena,$(WATER_PAIR_ARENAS),timeout 900 $(GODOT) --path . --resolution 1920x1080 \
		--script res://game/theme/arena_kit/terrain/tools/terrain_shots.gd -- --arena=$(arena) \
		--out=$(CURDIR)/$(BUILD_DIR)/water-pairs --spots=$(TERRAIN_SPOTS_$(arena)) --hulls=$(TERRAIN_HULLS_$(arena)) \
		$(if $(TERRAIN_DRY_$(arena)),--dry=$(TERRAIN_DRY_$(arena))) --looks=$(WATER_LOOKS) --freeze=$(or $(WATER_FREEZE),7.0) \
		> $(BUILD_DIR)/water-pairs/$(arena).log 2>&1 || true; \
		grep -E 'SCRIPT ERROR|^ERROR' $(BUILD_DIR)/water-pairs/$(arena).log || true; \
		grep -h '^WATER_STATS' $(BUILD_DIR)/water-pairs/$(arena).log | cut -c1-400; \
		grep -q 'TERRAIN_SHOTS_DONE ok=true' $(BUILD_DIR)/water-pairs/$(arena).log || { echo "water-pairs: $(arena) failed"; exit 1; };)
	@grep -h '^WATER_STATS' $(BUILD_DIR)/water-pairs/*.log | sed 's/^WATER_STATS //' > $(BUILD_DIR)/water-pairs/stats.jsonl
	@ls $(BUILD_DIR)/water-pairs/*.png | wc -l

# Round 12 (arena, A1): the water's GPU cost at the lead's pose, one frame held still, water drawn vs hidden.
WATER_GPU_SPOTS ?= crossing:-92:14 locks:0:4
.PHONY: water-gpu
water-gpu: import ## Arena (round 12): the water's GPU ms at the lead's pose, held still, drawn vs hidden (WATER_GPU_SPOTS="crossing:-92:14 locks:0:4") -> WATER_GPU lines (needs a display: make remote T=water-gpu)
	@mkdir -p $(BUILD_DIR)/water-gpu
	@$(foreach s,$(WATER_GPU_SPOTS),timeout 900 $(GODOT) --path . --resolution 1920x1080 --disable-vsync --script res://tests/arena/water_gpu_probe.gd -- \
		--arena=$(word 1,$(subst :, ,$(s))) --spot=$(word 2,$(subst :, ,$(s))):$(word 3,$(subst :, ,$(s))) --frames=$(or $(WATER_GPU_FRAMES),480) $(if $(WATER_GPU_LOOKS),--looks=$(WATER_GPU_LOOKS)) \
		> $(BUILD_DIR)/water-gpu/$(subst :,_,$(s)).log 2>&1; echo ">> water-gpu $(s): godot exited $$?"; \
		grep -E '^WATER_GPU|ERROR|Error' $(BUILD_DIR)/water-gpu/$(subst :,_,$(s)).log | head -20 || true;)

.PHONY: terrain-series terrain-measure
terrain-series: import ## Terrain (R9): a terrain map vs its dry twin on the SAME seeds -- unit-time on the crossings, time at the contested objective, discordant pairs (TERRAIN_MAP=crossing SEEDS=32 FIRST_SEED=1 ARENA_FACTION=condemned ARENA_TIME=180) -> build/terrain-series-<map>.json
	$(PYTHON) tools/terrain_series.py --godot $(GODOT) --map $(or $(TERRAIN_MAP),crossing) --seeds $(or $(SEEDS),32) \
		--first-seed $(or $(FIRST_SEED),1) --jobs $(or $(JOBS),3) --faction $(or $(ARENA_FACTION),condemned) \
		--time-limit $(or $(ARENA_TIME),180) --json $(BUILD_DIR)/terrain-series-$(or $(TERRAIN_MAP),crossing).json \
		| grep -E '^TERRAIN_(RUN|SERIES)'

terrain-measure: ## Terrain: the ring-of-eyes centre figure and plain objective routes beside arena-report's (no Godot)
	$(PYTHON) tools/terrain_measure.py arenas/crossing.json arenas/crossing_dry.json arenas/sumps.json arenas/sumps_dry.json arenas/locks.json arenas/locks_dry.json

.PHONY: terrain-page
terrain-page: ## Terrain: the lead's page -- every terrain map's frames beside its dry twin, and the numbers (after make remote T=terrain-shots) -> build/terrain-page/index.html
	$(PYTHON) tools/terrain_page.py --shots $(BUILD_DIR)/terrain-shots --series $(BUILD_DIR) --out $(BUILD_DIR)/terrain-page/index.html $(TERRAIN_SHOT_ARENAS)

# Round 11 (A1.4): a player squad ordered across each terrain map's water or pits on the DEFAULT path (Orders,
# source: player), legs to points the planner can only reach over a bridge or a causeway. Arrivals, contacts by cause,
# and ticks any hull spent inside a carved footprint (must be zero). DRIVE_TERRAIN_MAPS / DRIVE_TERRAIN_SQUADS, and
# DRIVE_TERRAIN_SHOTS=1 for frames at the lead's pose (needs a display: make remote T="terrain-drive DRIVE_TERRAIN_SHOTS=1").
DRIVE_TERRAIN_MAPS ?= crossing sumps locks pit
DRIVE_TERRAIN_SQUADS ?= mixed rigs

.PHONY: terrain-drive
terrain-drive: import ## Arena (round 11): a squad ordered over each terrain map's bridges/causeways on the default path -> build/terrain-drive/*.log, TERRAIN_DRIVE lines (DRIVE_TERRAIN_MAPS="crossing sumps" DRIVE_TERRAIN_SQUADS="mixed rigs" DRIVE_TERRAIN_SHOTS=1 for frames)
	@rm -rf $(BUILD_DIR)/terrain-drive && mkdir -p $(BUILD_DIR)/terrain-drive
	@$(foreach map,$(DRIVE_TERRAIN_MAPS),$(foreach squad,$(DRIVE_TERRAIN_SQUADS),\
		timeout 900 $(GODOT) $(if $(DRIVE_TERRAIN_SHOTS),--resolution 1920x1080,--headless) --fixed-fps $(SIM_HZ) --path . \
			--script res://tests/arena/terrain_drive.gd -- --arena=$(map) --squad=$(squad) \
			$(if $(DRIVE_TERRAIN_SHOTS),--shots=$(CURDIR)/$(BUILD_DIR)/terrain-drive/shots) \
			> $(BUILD_DIR)/terrain-drive/$(map)-$(squad).log 2>&1 || true; \
		grep -E "^TERRAIN_DRIVE_LEG|^TERRAIN_DRIVE |SCRIPT ERROR|control FAILED" $(BUILD_DIR)/terrain-drive/$(map)-$(squad).log | cut -c1-900 \
			|| echo ">> terrain-drive: $(map) $(squad) printed NO result";))
	@! grep -l "control FAILED\|SCRIPT ERROR" $(BUILD_DIR)/terrain-drive/*.log || { echo ">> terrain-drive: a run REFUSED or errored"; exit 1; }

# ---- Containers placed by people (yard, round 17) -----------------------------------------------------------------
.PHONY: container-census
container-census: ## Yard (round 17): per layout, containers square to the grid (within 0.5 deg of 90), the off-square spread, stacks and levels; CENSUS_MAX_SQUARE=0.25 CENSUS_SCOPE=rotation|shipping|all makes it fail -> build/container-census.json
	@mkdir -p $(BUILD_DIR)
	$(PYTHON) tools/container_census.py arenas/*.json --json $(BUILD_DIR)/container-census.json \
		$(if $(CENSUS_MAX_SQUARE),--max-square-share $(CENSUS_MAX_SQUARE) --scope $(or $(CENSUS_SCOPE),rotation))

## Spots for the frames page (key[:x:z[:heading_deg[:distance_m]]]; `opening` = where the match puts his camera).
## Picked as each dealt map's densest container clusters in green's half (counted from arenas/*.json), plus two
## close looks at stacks (22 m: the yard's tallest run, the Pit's three-high diagonal).
CF_ARENAS ?= yard pit terminus crossing sumps locks
CF_SPOTS_yard ?= opening;west_stacks:-86:28;east_stacks:98:36;close_stacks:-84:22:30:22
CF_SPOTS_pit ?= opening;ring:30:20;gate:-18:32;close_diagonal:30:30:0:22
CF_SPOTS_terminus ?= opening;avenue:6:68;west:-82:24
CF_SPOTS_crossing ?= opening;centre:38:20;west:-14:0
CF_SPOTS_sumps ?= opening;east:54:16;middle:2:40
CF_SPOTS_locks ?= opening;east_quay:110:32;south:-26:80
CF_TAG ?= after
.PHONY: container-frames
container-frames: import ## Yard (round 17): every dealt map's containers at the lead's pose (CF_ARENAS, CF_TAG=after; CF_SQUARE=1 renders the frozen square layouts of tests/arena/before/square/) -> build/container-frames/*.jpg (needs a display: make remote T=container-frames)
	@mkdir -p $(BUILD_DIR)/container-frames
	@$(foreach a,$(CF_ARENAS),timeout 300 $(GODOT) --path . --resolution 1920x1080 --script res://tests/arena/container_frames.gd -- \
		--skirmish --mute --seed=3 --arena=$(if $(CF_SQUARE),res://tests/arena/before/square/$(a).json,$(a)) \
		--frames-out=$(CURDIR)/$(BUILD_DIR)/container-frames --frames-tag=$(CF_TAG) --frames-spots='$(CF_SPOTS_$(a))' \
		> $(BUILD_DIR)/container-frames/$(a)_$(CF_TAG).log 2>&1 || true; \
		grep -E 'CONTAINER_FRAMES_DONE|SCRIPT ERROR|^ERROR' $(BUILD_DIR)/container-frames/$(a)_$(CF_TAG).log | head -5 || true; \
		grep -q 'CONTAINER_FRAMES_DONE' $(BUILD_DIR)/container-frames/$(a)_$(CF_TAG).log || { echo "container-frames: $(a) failed"; exit 1; };)
	@ls $(BUILD_DIR)/container-frames/*_$(CF_TAG).jpg | wc -l

# CP1's own evidence (round 17): the sim baseline runs on foundry, which holds no containers, so it cannot see the
# layouts turn. This runs the baseline's own match (SIM_HASH_READ's doctrines, seed and length) on EVERY layout and
# prints a state hash each: on the turned tree every layout with turned containers must differ from the launch tree's,
# and every layout without (foundry, furnace, scrapyard, maze, barriers) must be identical.
CH_LAYOUTS ?= $(basename $(notdir $(wildcard arenas/*.json)))
.PHONY: container-hashes
container-hashes: import ## Yard (round 17, CP1): the sim-baseline match on every layout (CH_LAYOUTS, CH_SEED=3, CH_TIME=40), one state hash each -> CONTAINER_HASH lines, build/container-hashes.txt
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/container-hashes.txt
	@for a in $(CH_LAYOUTS); do \
		h=$$($(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --arena=$$a \
			--green-doctrine=res://doctrines/sim_baseline_green.json --rust-doctrine=res://doctrines/sim_baseline_rust.json \
			--time-limit=$(or $(CH_TIME),40) --seed=$(or $(CH_SEED),3) 2>/dev/null | grep MATCH_RESULT \
			| $(PYTHON) -c "import json,sys; d=json.loads(sys.stdin.read().split('MATCH_RESULT ')[1]); print(d['state_hash'], d.get('ticks', d.get('tick', '?')))"); \
		echo "CONTAINER_HASH $$a $${h:-NONE}" | tee -a $(BUILD_DIR)/container-hashes.txt; \
	done

# CP1's other question (round 17, brains via the orchestrator): does a turned container give a long hull's planned
# k-turn something to plant into? The SAME match (Gangs' War Rigs vs the Condemned's 9.7 m tanks, elimination,
# CC_TIME s) on each map's frozen square layout and on today's, CC_SEEDS seeds, CC_JOBS at once; every hull's
# Movement.state() read each tick (tests/arena/contact_probe.gd). One CONTACT_PROBE line per match, then a summary.
CC_MAPS ?= terminus yard pit sumps
CC_SEEDS ?= 8
CC_TIME ?= 180
.PHONY: container-contacts
container-contacts: import ## Yard (round 17, CP1): wall-contact ticks by cause x driver for long hulls, square vs turned layouts, same seeds (CC_MAPS, CC_SEEDS=8, CC_TIME=180, CC_JOBS=3) -> build/container-contacts.jsonl + CONTACT_SUMMARY lines
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/container-contacts.jsonl
	@for m in $(CC_MAPS); do for s in $$(seq 1 $(CC_SEEDS)); do \
		echo "square res://tests/arena/before/square/$$m.json $$s"; echo "turned $$m $$s"; done; done \
	| xargs -P $(or $(CC_JOBS),3) -L 1 sh -c '$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/arena/contact_probe.gd -- \
		--match --elimination --arena=$$1 --green-faction=gangs --rust-faction=condemned --budget=5200 --time-limit=$(CC_TIME) \
		--seed=$$2 --probe-tag=$$0 2>/dev/null | grep "^CONTACT_PROBE" | cut -c15- >> $(BUILD_DIR)/container-contacts.jsonl'
	@$(PYTHON) tools/container_contacts.py $(BUILD_DIR)/container-contacts.jsonl
