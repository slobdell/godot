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
nav-fight: import ## nav (round 7): why ordered units aren't making progress IN A FIGHT — two ~30-unit CPU-rostered armies, GREEN ordered by Orders like a player; every ordered unit-tick bucketed (progressing, yielding, blocked_*, halted_shooting, retasked:<option>, slow) (ARENA=yard SEED=3 NAV_TIME=120 BUDGET=6500)
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/fight_probe.gd -- \
		--arena=$(or $(ARENA),yard) --seed=$(or $(SEED),3) --time-limit=$(or $(NAV_TIME),120) --budget=$(or $(BUDGET),6500) \
		$(NAV_FLAGS) 2>&1 | grep -E "NAV_FIGHT|SCRIPT ERROR|ERROR" || true
