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
			engaged) f="--think-engaged=7.5";; stride4) f="--l1=2:4";; B) f="--l1=2:4:3.333:7.5:6";; *) f="$$arm";; esac; \
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
