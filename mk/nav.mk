# nav (round 6): measuring movement. The instrument is arena's maze probe (tests/arena/maze_probe.gd, `make nav-maze`);
# this runs it over a suite of arenas, sizes, traffic directions and seeds in parallel and summarises.

NAV_SUITE ?= maze:30 maze:60 maze:60:both yard:60 yard:60:both foundry:60
# One seed by default: the maze probe has no randomness in a hold-fire drive (five seeds at 30e3250d gave five
# identical results), so more seeds only matter once something random enters the drive.
NAV_SEEDS ?= 1
NAV_JOBS ?= 6

.PHONY: nav-suite
nav-suite: import ## nav X2: arena's maze probe over NAV_SUITE (arena:units[:both]) x NAV_SEEDS, NAV_JOBS at a time -> build/nav/*.json + build/nav/summary.{json,md} (NAV_TIME=180)
	@rm -rf $(BUILD_DIR)/nav && mkdir -p $(BUILD_DIR)/nav
	@for config in $(NAV_SUITE); do for seed in $(NAV_SEEDS); do echo "$$config:$$seed"; done; done | \
		xargs -P $(NAV_JOBS) -I{} sh -c 'set -- $$(echo {} | tr ":" " "); \
			if [ "$$3" = both ]; then both=--both-ways; tag=$$1-$$2-both; seed=$$4; else both=; tag=$$1-$$2; seed=$$3; fi; \
			$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/arena/maze_probe.gd -- \
				--units=$$2 --arena=$$1 --time-limit=$(or $(NAV_TIME),180) --seed=$$seed $$both \
				--json=$(CURDIR)/$(BUILD_DIR)/nav/$$tag-s$$seed.json > $(BUILD_DIR)/nav/$$tag-s$$seed.log 2>&1; \
			echo ">> nav-suite: $$tag seed $$seed done"'
	NAV_COMMIT=$(NAV_COMMIT) $(PYTHON) tools/nav_suite.py $(BUILD_DIR)/nav

.PHONY: nav-where
nav-where: import ## nav: one maze-probe run (ARENA=foundry NAV_UNITS=60 NAV_BOTH=1 NAV_TIME=180) that also prints where every unit that didn't arrive ended up (NAV_WHERE lines) -> build/nav-where.log
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/nav_probe.gd -- \
		--units=$(or $(NAV_UNITS),60) --arena=$(or $(ARENA),foundry) --time-limit=$(or $(NAV_TIME),180) \
		--seed=1 $(if $(NAV_BOTH),--both-ways) $(NAV_FLAGS) > $(BUILD_DIR)/nav-where.log 2>&1 || true
	grep -E "NAV_WHERE|NAV_COUNTERS|SCRIPT ERROR" $(BUILD_DIR)/nav-where.log || true
	grep -oE '"(arrived|off_navmesh|t100_s)":[-0-9.]*' $(BUILD_DIR)/nav-where.log || true

.PHONY: nav-orders
nav-orders: import ## nav: the lead's test with brains — 5 player squads ordered across each other at once (ARENA=yard NAV_TIME=90); prints NAV_ORDERS (completed, completed_far = done > 7 m from the goal, never_completed, t50/t90/t100)
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/order_probe.gd -- \
		--arena=$(or $(ARENA),yard) --time-limit=$(or $(NAV_TIME),90) $(NAV_FLAGS) 2>&1 | grep -E "NAV_ORDERS|SCRIPT ERROR|ERROR" || true

.PHONY: nav-facing
nav-facing: import ## nav (round 7): do units achieve an ordered facing? 5 player squads sent across one another, each told to face 90 deg off its travel (VERB=move|hold, ARENA=yard, NAV_TIME=90); prints NAV_FACING (heading error at arrival and +2/+5/+10 s)
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/facing_probe.gd -- \
		--arena=$(or $(ARENA),yard) --time-limit=$(or $(NAV_TIME),90) --verb=$(or $(VERB),move) $(NAV_FLAGS) 2>&1 | grep -E "NAV_FACING|SCRIPT ERROR|ERROR" || true

.PHONY: nav-fight
nav-fight: import ## nav (round 7): why ordered units aren't making progress IN A FIGHT — two ~30-unit CPU-rostered armies, GREEN ordered by Orders like a player; every ordered unit-tick bucketed (progressing, yielding, blocked_*, halted_shooting, retasked:<option>, slow) (ARENA=yard FIGHT_SEED=3 NAV_TIME=120 FIGHT_BUDGET=6500; not SEED/BUDGET: other mk files default those globally, lesson 44)
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/fight_probe.gd -- \
		--arena=$(or $(ARENA),yard) --seed=$(or $(FIGHT_SEED),3) --time-limit=$(or $(NAV_TIME),120) --budget=$(or $(FIGHT_BUDGET),6500) \
		$(NAV_FLAGS) 2>&1 | grep -E "NAV_FIGHT|SCRIPT ERROR|ERROR" || true

.PHONY: nav-fight-ab
nav-fight-ab: import ## nav: nav-fight over FIGHT_SEEDS (default 1 3 5 7 9) with and without --nav-off=$(AB_OFF), NAV_JOBS at a time -> build/nav-ab/*.log + a one-line summary per run (NAV_ORDERS lines grep-able)
	@rm -rf $(BUILD_DIR)/nav-ab && mkdir -p $(BUILD_DIR)/nav-ab
	@for seed in $(or $(FIGHT_SEEDS),1 3 5 7 9); do for arm in on off; do echo "$$seed:$$arm"; done; done | \
		xargs -P $(NAV_JOBS) -I{} sh -c 'seed=$${1%%:*}; arm=$${1##*:}; flags=""; [ "$$arm" = off ] && flags="--nav-off=$(AB_OFF)"; \
			$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/fight_probe.gd -- \
				--arena=$(or $(ARENA),yard) --seed=$$seed --time-limit=$(or $(NAV_TIME),120) --budget=$(or $(FIGHT_BUDGET),6500) $$flags \
				> $(BUILD_DIR)/nav-ab/s$$seed-$$arm.log 2>&1; echo ">> nav-fight-ab: seed $$seed $$arm done"' _ {}
	@for f in $(BUILD_DIR)/nav-ab/*.log; do echo "$$(basename $$f .log) $$(grep -E '^NAV_FIGHT_ARM ' $$f | head -1) $$(grep -E '^NAV_FIGHT ' $$f | head -1)"; done
	@# The arms must be arms (round 7: the first commitment A/B's switch never applied and both arms came back
	@# byte-identical — which a pre-registered "no worse" rule would have read as a pass). Fail if the live treatment
	@# line is the same in both arms of any seed, or if every seed's results are identical across arms.
	@for seed in $(or $(FIGHT_SEEDS),1 3 5 7 9); do 		a=$$(grep -E '^NAV_FIGHT_ARM ' $(BUILD_DIR)/nav-ab/s$$seed-on.log); b=$$(grep -E '^NAV_FIGHT_ARM ' $(BUILD_DIR)/nav-ab/s$$seed-off.log); 		if [ "$$a" = "$$b" ]; then echo "nav-fight-ab control FAILED: seed $$seed ran the same treatment in both arms ($$a)"; exit 1; fi; done
	@same=1; for seed in $(or $(FIGHT_SEEDS),1 3 5 7 9); do 		a=$$(grep -E '^NAV_FIGHT ' $(BUILD_DIR)/nav-ab/s$$seed-on.log); b=$$(grep -E '^NAV_FIGHT ' $(BUILD_DIR)/nav-ab/s$$seed-off.log); 		[ "$$a" = "$$b" ] || same=0; done; 		if [ $$same = 1 ]; then echo "nav-fight-ab control FAILED: every seed gave identical results in both arms: the switch changed nothing"; exit 1; fi
	@echo ">> nav-fight-ab: arms differ in treatment and in outcome; results are comparisons"

.PHONY: nav-rotation
nav-rotation: import ## nav (round 7): how hulls ROTATE from the lead's camera (pitch 21, 49 m, FOV 35): a tank's pivot, a car's K-turn, a squad wheeling -> build/nav-rotation/*.png + NAV_ROTATION lines (pre-registered "robotic" tests) (needs a display)
	rm -rf $(BUILD_DIR)/nav-rotation && mkdir -p $(BUILD_DIR)/nav-rotation
	timeout 900 $(GODOT) --path . --resolution 960x540 --fixed-fps $(SIM_HZ) --script res://tests/nav/rotation_capture.gd -- \
		--out=$(CURDIR)/$(BUILD_DIR)/nav-rotation > $(BUILD_DIR)/nav-rotation/run.log 2>&1 || true
	grep -E "NAV_ROTATION|SCRIPT ERROR|ERROR" $(BUILD_DIR)/nav-rotation/run.log || true
