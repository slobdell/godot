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

# ---- round 28 (M1): hull facing at rest, the change v its switch on ONE commit -------------------------------------
# Orders' O3 workload (hull-rest-probe: foundry, quiet arm, HULL_FACTIONS x HULL_SEEDS x the six faced tasks) in four
# arms: drawn / clicked (--faced-click) x new / base (`--nav-off=turnhull,faceslot`: round 27). Same seeds every arm.
# Report only -> build/manoeuvre/hull-rest/<arm>/<faction>/<task>-<seed>/screen.json + tests/manoeuvre/hull_rest_ab.py.
M1_ARMS ?= new_drawn base_drawn new_clicked base_clicked
M1_DIR ?= $(BUILD_DIR)/manoeuvre/hull-rest
# Extra flags for every arm (e.g. --turn-states: each crew's state once a second, read by hull_rest_moving.py).
M1_FLAGS ?=
.PHONY: manoeuvre-hull-rest
manoeuvre-hull-rest: import ## manoeuvre M1: hull facing at rest per hull class, drawn/clicked x new/base (--nav-off=turnhull) on one commit -> build/manoeuvre/hull-rest/ + the A/B table
	mkdir -p $(M1_DIR) && for arm in $(M1_ARMS); do rm -rf $(M1_DIR)/$$arm; done  # one arm a call keeps the others
	for arm in $(M1_ARMS); do for faction in $(HULL_FACTIONS); do for seed in $(HULL_SEEDS); do for task in $(_FACING_TASKS); do \
		echo "$$arm $$faction $$seed $$task"; done; done; done; done | xargs -P $(HULL_JOBS) -L 1 sh -c '\
		d=$(M1_DIR)/$$0/$$1/$$3-$$2; mkdir -p $$d; enemy=law; [ $$1 = law ] && enemy=gangs; \
		click=""; case $$0 in *clicked) click=--faced-click;; esac; off=""; case $$0 in base_*) off=--nav-off=turnhull,faceslot;; esac; \
		timeout 300 $(GODOT) --headless --path . -- --skirmish --seed=$$2 --no-pick-faction --mute --arena=$(FACING_ARENA) \
			--player-faction=$$1 --enemy-faction=$$enemy --tune=match.no_damage=1 --enemy=$(FACING_QUIET_ENEMY) \
			--no-element-cpu $$click $$off $(M1_FLAGS) --screen-test=$(CURDIR)/$$d --screen-only=$$3 > $$d/run.log 2>&1; \
		grep -q SCREEN_DONE $$d/run.log || echo "manoeuvre-hull-rest: $$d has no SCREEN_DONE"; \
		! grep -m1 "SCRIPT ERROR" $$d/run.log'
	$(PYTHON) tests/manoeuvre/hull_rest_ab.py $(M1_DIR)
	$(PYTHON) tests/manoeuvre/hull_rest_moving.py $(M1_DIR)

# One run of manoeuvre-hull-rest's workload, for a trace: ONE_FACTION, ONE_SEED, ONE_TASK, ONE_CLICK=1 for the clicked
# arm, NAV_FLAGS (e.g. --turn-trace=<unit> --nav-off=turnhull) -> build/manoeuvre/hull-one/run.log + screen.json.
.PHONY: manoeuvre-hull-one
manoeuvre-hull-one: import ## manoeuvre M1: one hull-rest run (ONE_FACTION ONE_SEED ONE_TASK [ONE_CLICK=1] NAV_FLAGS) -> build/manoeuvre/hull-one/
	@d=$(BUILD_DIR)/manoeuvre/hull-one; rm -rf $$d && mkdir -p $$d; enemy=law; [ "$(ONE_FACTION)" = law ] && enemy=gangs; \
	timeout 300 $(GODOT) --headless --path . -- --skirmish --seed=$(ONE_SEED) --no-pick-faction --mute --arena=$(FACING_ARENA) \
		--player-faction=$(ONE_FACTION) --enemy-faction=$$enemy --tune=match.no_damage=1 --enemy=$(FACING_QUIET_ENEMY) \
		--no-element-cpu $(if $(ONE_CLICK),--faced-click) $(NAV_FLAGS) --screen-test=$(CURDIR)/$$d --screen-only=$(ONE_TASK) \
		> $$d/run.log 2>&1; grep -q SCREEN_DONE $$d/run.log || echo "manoeuvre-hull-one: no SCREEN_DONE"; \
	grep -c MANOEUVRE_TRACE $$d/run.log || true
