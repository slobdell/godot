# Round 25 pace: the think rate's pass lines (P0), the quiet census (P1), the smarter quiet (P2).
# Owner: pace (_agents/streams/pace.md). Included by the root Makefile (mk/*.mk).

# P0: each scenario L1's settings broke, at each setting, at several think phases (`--think-phase=`: every brain's first
# think shifted by n ticks, the rate unchanged). A line that flips on the phase alone at today's rate measures timing
# luck. One log per arm x phase under build/pace/p0/; the summary prints PASS/FAIL and every MEASURE line.
PACE_P0_FILTER ?= a_healthy_tank_near_a_wall|teammate_drawing_fire|fighting_from_a_formation_slot|base_of_fire_keeps|overwatch_element_covers|holding_a_crew_down|engine_deck|duel_on_the_move
PACE_P0_ARMS ?= base q333 q2 settled engaged stride4 B
PACE_P0_PHASES ?= 0 1 2 3 4 5
PACE_P0_JOBS ?= 1
pace-p0: import ## Pace P0: the broken scenarios x L1 settings x think phases (PACE_P0_ARMS, PACE_P0_PHASES, PACE_P0_FILTER) -> build/pace/p0/
	@mkdir -p $(BUILD_DIR)/pace/p0
	@echo ">> pace-p0 on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | arms $(PACE_P0_ARMS) | phases $(PACE_P0_PHASES)"
	@for arm in $(PACE_P0_ARMS); do for ph in $(PACE_P0_PHASES); do echo "$$arm $$ph"; done; done | \
		xargs -P $(PACE_P0_JOBS) -L1 sh -c 'arm=$$0; ph=$$1; \
		case $$arm in base) f="";; q333) f="--think-quiet=3.333";; q2) f="--think-quiet=2";; settled) f="--think-settled=3.333";; \
			engaged) f="--think-engaged=7.5";; stride4) f="--l1=2:4";; B) f="--l1=2:4:3.333:7.5:6";; smart) f="--think-smart=2";; smart2) f="--think-smart=2 --quiet-watched=1";; *) f="$$arm";; esac; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- \
			"--filter=$(PACE_P0_FILTER)" --think-phase=$$ph $$f > $(BUILD_DIR)/pace/p0/$$arm-p$$ph.log 2>&1 || true'
	@python3 tests/pace/p0_summary.py $(BUILD_DIR)/pace/p0

# P1: the quiet census on the laptop's workload (perf-fight size 25: foundry + parade + his Crossing x 3 seeds, the
# 8-20 s window), every crew-tick round 24 called quiet split by the smarter quiet's reason (ThinkQuiet.why_not).
# Simulation counts, not timings: run it on builder0 (`make remote T=pace-census`; perf-play needs its display).
# perf-drive orders on wall time, so the orders land a little differently per machine: read shares, not counts.
PACE_CENSUS_ARENAS ?= foundry parade crossing
PACE_CENSUS_SEEDS ?= 92721 31337 5988
PACE_CENSUS_FLAGS ?=
pace-census: import ## Pace P1: the quiet census (BRAINS_LOD split by ThinkQuiet's reason) on PACE_CENSUS_ARENAS x PACE_CENSUS_SEEDS, 25 a side, 8-20 s -> build/pace-census-*.txt + table
	@echo ">> pace-census on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | $(PACE_CENSUS_ARENAS) x $(PACE_CENSUS_SEEDS) | $(PACE_CENSUS_FLAGS)"
	@$(MAKE) --no-print-directory perf-fight PERF_FIGHT=size PERF_FIGHT_SIZES=25 PERF_FIGHT_ARMS=main \
		PERF_FIGHT_ARENAS="$(PACE_CENSUS_ARENAS)" PERF_FIGHT_SEEDS="$(PACE_CENSUS_SEEDS)" PERF_FIGHT_CYCLES=3 \
		PERF_FIGHT_NAME=pace-census PERF_FIGHT_EXTRA="--brains-census --census-window=8,20 $(PACE_CENSUS_FLAGS)" || true
	@python3 tests/pace/census.py $(BUILD_DIR) pace-census

# A quick headless census (diagnosis only; the ruling census is pace-census): a match at 25 a side from the perf
# armies, leaders on, PACE_QC_ARENA x PACE_QC_SEEDS, 20 s of match time, faster than real time.
PACE_QC_ARENA ?= foundry
PACE_QC_SEEDS ?= 92721
PACE_QC_FLAGS ?=
pace-census-quick: import ## Pace P1 diagnosis: the quiet census on a headless 25-a-side match (PACE_QC_ARENA, PACE_QC_SEEDS, PACE_QC_FLAGS) -> build/pace-qc-*.log + table
	@mkdir -p $(BUILD_DIR)/perf-armies && rm -f $(BUILD_DIR)/pace-qc-25-*.log
	@$(PYTHON) tools/perf_armies.py size 25 $(BUILD_DIR)/perf-armies
	@for seed in $(PACE_QC_SEEDS); do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control \
			--green-doctrine=res://$(BUILD_DIR)/perf-armies/green_25.json --rust-doctrine=res://$(BUILD_DIR)/perf-armies/rust_25.json \
			--budget=100000 --time-limit=21 --seed=$$seed --arena=$(PACE_QC_ARENA) --green-elements --rust-elements \
			--brains-census --census-window=8,20 $(PACE_QC_FLAGS) > $(BUILD_DIR)/pace-qc-25-$(PACE_QC_ARENA)-main-$$seed.log 2>&1 || true; \
	done
	@python3 tests/pace/census.py $(BUILD_DIR) pace-qc

# P0 for the drills (tests, not scenarios): PACE_P0T_FILTER x arms x phases through the test runner -> build/pace/p0t/.
PACE_P0T_FILTER ?= test_tactics_bridge|test_tactics_pursuit
PACE_P0T_ARMS ?= base q2
PACE_P0T_PHASES ?= 0 1 2
pace-p0-tests: import ## Pace P0: test files (PACE_P0T_FILTER) x L1 settings x think phases -> build/pace/p0t/
	@mkdir -p $(BUILD_DIR)/pace/p0t
	@for arm in $(PACE_P0T_ARMS); do for ph in $(PACE_P0T_PHASES); do \
		case $$arm in base) f="";; q2) f="--think-quiet=2";; q333) f="--think-quiet=3.333";; smart) f="--think-smart=2";; smart2) f="--think-smart=2 --quiet-watched=1";; *) f="$$arm";; esac; \
		$(GODOT) --headless --path . --script res://tests/run_tests.gd -- '--filter=$(PACE_P0T_FILTER)' --think-phase=$$ph $$f \
			> $(BUILD_DIR)/pace/p0t/$$arm-p$$ph.log 2>&1 || true; \
		echo "$$arm p$$ph: $$(grep -E '^[0-9]+ passed' $(BUILD_DIR)/pace/p0t/$$arm-p$$ph.log)"; \
		grep -hE '^  FAIL|^MEASURE (bridge|pursuit)' $(BUILD_DIR)/pace/p0t/$$arm-p$$ph.log | cut -c1-300; \
	done; done

# The scenario-order leak (2026-10-10, pace): a scenario's result must not depend on what ran before it in the process.
# PACE_LEAK_TARGET alone v after each PACE_LEAK_BEFORE scenario, one process each, at think phase PACE_LEAK_PHASE; FAILS
# (exit 1) when the target's MEASURE lines differ. Cause found: the runner starts a test wherever the previous test's
# teardown left the frame loop (inside a physics step after `await physics_frame`; at idle time for the first test),
# so the scenario's nodes take their first physics tick one frame apart (cp2's scout: 0.0 v 0.5 m/s at t = 0, then 7 v
# 43 hits). One `await process_frame` before each test in run_scenarios.gd makes alone = after (43 = 43 = 43).
PACE_LEAK_TARGET ?= engine_deck
PACE_LEAK_BEFORE ?= none near_a_wall teammate_drawing_fire lancer_holds_steady hurt_tank_under_fire does_not_peek
PACE_LEAK_PHASE ?= 0
PACE_LEAK_MEASURE ?= ai_cp2_scout_engine_deck
pace-leak: import ## Fails when PACE_LEAK_TARGET's result depends on the scenario run before it (alone v after each PACE_LEAK_BEFORE) -> build/pace/leak/
	@mkdir -p $(BUILD_DIR)/pace/leak
	@for before in $(PACE_LEAK_BEFORE); do \
		filter="$(PACE_LEAK_TARGET)"; [ $$before = none ] || filter="$$before|$(PACE_LEAK_TARGET)"; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- \
			"--filter=$$filter" --think-phase=$(PACE_LEAK_PHASE) $(PACE_LEAK_FLAGS) > $(BUILD_DIR)/pace/leak/$$before.log 2>&1 || true; \
		grep -h 'MEASURE $(PACE_LEAK_MEASURE)' $(BUILD_DIR)/pace/leak/$$before.log > $(BUILD_DIR)/pace/leak/$$before.measure || true; \
		echo "after $$before: $$(cut -c1-160 $(BUILD_DIR)/pace/leak/$$before.measure)"; \
	done
	@cd $(BUILD_DIR)/pace/leak && for f in *.measure; do cmp -s none.measure $$f || { echo "pace-leak FAILED: $$f differs from the target alone"; exit 1; }; done; \
		[ -s none.measure ] || { echo "pace-leak FAILED: no MEASURE $(PACE_LEAK_MEASURE) line"; exit 1; }; echo "pace-leak: equal alone and after every scenario"

# The same check for the unit/drill runner (tests/run_tests.gd): PACE_LEAKT_TARGET alone v after PACE_LEAKT_BEFORE
# (a test that sorts before it), comparing the MEASURE lines matching PACE_LEAKT_MEASURE. Exits 1 when they differ.
PACE_LEAKT_TARGET ?= test_his_squad_crosses_by_the_bridge
PACE_LEAKT_BEFORE ?= test_near_water_is_the_carved_terrain
PACE_LEAKT_MEASURE ?= MEASURE bridge
pace-leak-tests: import ## Fails when a drill's result depends on the test run before it (tests/run_tests.gd) -> build/pace/leakt/
	@mkdir -p $(BUILD_DIR)/pace/leakt
	@$(GODOT) --headless --path . --script res://tests/run_tests.gd -- '--filter=$(PACE_LEAKT_TARGET)' > $(BUILD_DIR)/pace/leakt/alone.log 2>&1 || true
	@$(GODOT) --headless --path . --script res://tests/run_tests.gd -- '--filter=$(PACE_LEAKT_BEFORE)|$(PACE_LEAKT_TARGET)' > $(BUILD_DIR)/pace/leakt/after.log 2>&1 || true
	@grep -h '$(PACE_LEAKT_MEASURE)' $(BUILD_DIR)/pace/leakt/alone.log > $(BUILD_DIR)/pace/leakt/alone.measure || true
	@grep -h '$(PACE_LEAKT_MEASURE)' $(BUILD_DIR)/pace/leakt/after.log > $(BUILD_DIR)/pace/leakt/after.measure || true
	@echo "alone: $$(cut -c1-200 $(BUILD_DIR)/pace/leakt/alone.measure | head -2)"; echo "after: $$(cut -c1-200 $(BUILD_DIR)/pace/leakt/after.measure | head -2)"
	@[ -s $(BUILD_DIR)/pace/leakt/alone.measure ] || { echo "pace-leak-tests FAILED: no '$(PACE_LEAKT_MEASURE)' line"; exit 1; }
	@cmp -s $(BUILD_DIR)/pace/leakt/alone.measure $(BUILD_DIR)/pace/leakt/after.measure && echo "pace-leak-tests: equal alone and after" \
		|| { echo "pace-leak-tests FAILED: the drill differs after another test"; exit 1; }

# Reproducibility of one drill (PACE_LEAKT_TARGET): the same process command PACE_REPRO_N times -> its MEASURE lines.
PACE_REPRO_N ?= 3
pace-repro: import ## Runs PACE_LEAKT_TARGET alone PACE_REPRO_N times (PACE_REPRO_FLAGS) and prints each MEASURE line's head
	@for i in $$(seq 1 $(PACE_REPRO_N)); do $(GODOT) --headless --path . --script res://tests/run_tests.gd -- '--filter=$(PACE_LEAKT_TARGET)' $(PACE_REPRO_FLAGS) 2>&1 \
		| grep -h '$(PACE_LEAKT_MEASURE)' | cut -c1-90 | sed "s/^/run $$i: /" || true; done
