# ---- manoeuvre (round 26): the short move behind, the three-point turn ----------------------------------------------
# Owner: the manoeuvre stream (_agents/streams/archive/round26/manoeuvre.md). Probes print one JSON line per case; tests/manoeuvre/*.py
# pool them.

MANOEUVRE_HULLS ?= tank scout gang_tank
MANOEUVRE_SEEDS ?= 1,2,3

.PHONY: manoeuvre-behind
manoeuvre-behind: import ## manoeuvre M0a: a player's plain move to a goal 5/10/20 m astern and 10 m at 120/150 deg, per hull (MANOEUVRE_HULLS), +/- a drawn facing, pooled over start ticks {1,3,6,8,11,16} x MANOEUVRE_SEEDS -> build/manoeuvre/behind_<hull>.log + the table (NAV_FLAGS passes --nav-off=... etc.)
	@mkdir -p $(BUILD_DIR)/manoeuvre
	@for h in $(MANOEUVRE_HULLS); do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/manoeuvre/goal_behind_probe.gd -- \
			--hull=$$h --seeds=$(MANOEUVRE_SEEDS) $(if $(MANOEUVRE_CASE),--case=$(MANOEUVRE_CASE)) \
			$(if $(MANOEUVRE_TICKS),--ticks=$(MANOEUVRE_TICKS)) $(if $(MANOEUVRE_TRACE),--trace=1) $(NAV_FLAGS) \
			> $(BUILD_DIR)/manoeuvre/behind_$$h.log 2>&1 & \
	done; wait
	python3 tests/manoeuvre/behind_table.py $(foreach h,$(MANOEUVRE_HULLS),$(BUILD_DIR)/manoeuvre/behind_$(h).log)

# M0b (C26.5): every turn episode (ManoeuvreCensus: legs per turn, what was in the way) in three workloads, each run
# its own process, one at a time (fits the light lane): the Terminus drive (DRIVE squads x CENSUS_SEEDS), the
# sim-baseline match (40 s, seeds CENSUS_SIM_SEEDS) and Sumps 25 a side (perf_armies size 25, elements both sides,
# CENSUS_SUMPS_TIME s, seeds CENSUS_SEEDS). Rows: MANOEUVRE_TURN lines in build/manoeuvre/census/*.log.
CENSUS_SEEDS ?= 1 2 3
CENSUS_SIM_SEEDS ?= 3 4 5
CENSUS_SUMPS_TIME ?= 60
CENSUS_WORKLOADS ?= terminus sim sumps
.PHONY: manoeuvre-census
manoeuvre-census: import ## manoeuvre M0b: the turn census (legs per turn by obstacle kind: static / friendly / enemy / open) over the Terminus drive, the sim-baseline match and Sumps 25 a side (CENSUS_WORKLOADS, CENSUS_SEEDS; NAV_FLAGS for an arm) -> build/manoeuvre/census/ + the table
	@rm -rf $(BUILD_DIR)/manoeuvre/census && mkdir -p $(BUILD_DIR)/manoeuvre/census $(BUILD_DIR)/perf-armies
	@case " $(CENSUS_WORKLOADS) " in *" terminus "*) for squad in mixed rigs; do for seed in $(CENSUS_SEEDS); do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/terminus_drive.gd -- \
			--squad=$$squad --seed=$$seed --arena=terminus --leg-time=$(or $(DRIVE_LEG_TIME),90) --turn-log $(NAV_FLAGS) \
			> $(BUILD_DIR)/manoeuvre/census/terminus-$$squad-$$seed.log 2>&1 || true; \
		echo ">> manoeuvre-census: terminus $$squad $$seed"; done; done;; esac
	@case " $(CENSUS_WORKLOADS) " in *" sim "*) for seed in $(CENSUS_SIM_SEEDS); do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --green-doctrine=res://doctrines/sim_baseline_green.json \
			--rust-doctrine=res://doctrines/sim_baseline_rust.json --time-limit=40 --seed=$$seed --turn-log $(NAV_FLAGS) \
			> $(BUILD_DIR)/manoeuvre/census/sim-$$seed.log 2>&1 || true; \
		echo ">> manoeuvre-census: sim $$seed"; done;; esac
	@case " $(CENSUS_WORKLOADS) " in *" sumps "*) $(PYTHON) tools/perf_armies.py size 25 $(BUILD_DIR)/perf-armies > /dev/null; \
		for seed in $(CENSUS_SEEDS); do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control \
			--green-doctrine=res://$(BUILD_DIR)/perf-armies/green_25.json --rust-doctrine=res://$(BUILD_DIR)/perf-armies/rust_25.json \
			--budget=100000 --squad-cap=5 --time-limit=$(CENSUS_SUMPS_TIME) --seed=$$seed --arena=sumps --green-elements --rust-elements \
			--turn-log $(NAV_FLAGS) > $(BUILD_DIR)/manoeuvre/census/sumps-$$seed.log 2>&1 || true; \
		echo ">> manoeuvre-census: sumps $$seed"; done;; esac
	$(PYTHON) tests/manoeuvre/census_table.py $(BUILD_DIR)/manoeuvre/census/*.log

# A quick parse check of the stream's own scripts (the whole-tree `lint` is -P1 and takes ~1 h on a loaded builder0).
MANOEUVRE_PARSE ?= game/ai/manoeuvre.gd game/ai/manoeuvre_census.gd game/ai/movement.gd game/ai/order_controller.gd \
	tests/manoeuvre/goal_behind_probe.gd tests/test_manoeuvre_behind.gd
.PHONY: manoeuvre-parse
manoeuvre-parse: import ## manoeuvre: --check-only on the stream's scripts (MANOEUVRE_PARSE), the real messages printed
	@for f in $(MANOEUVRE_PARSE); do out=$$($(GODOT) --headless --path . --check-only --script res://$$f 2>&1 | grep -E "Parse Error|SCRIPT ERROR|ERROR" | grep -v "depended scripts" || true); \
		if [ -n "$$out" ]; then echo "== $$f"; echo "$$out" | head -8; else echo "ok $$f"; fi; done
