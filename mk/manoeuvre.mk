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
M1_FLAGS ?= --turn-states
# Round 30 (M4b/M1b): the base arms' --nav-off list (the parser honours only the FIRST --nav-off= on the line, and the
# arm's comes first, so a base switch must be named HERE, not in M1_FLAGS). Round 29's "turnhull,faceslot" named
# mechanisms main does not have (push_error on every base run).
M1_BASE_OFF ?= faceslot
# Round 31 (R31.1): an OPT-IN candidate is turned ON by naming it, so the NEW arms carry the list (M1b(2): turnhull)
# and the base arms none (M1_BASE_OFF=). Both arms run the GDScript path when either names a --nav-off (any list
# leaves native's drive): put --brains-off=native in M1_FLAGS for such a pair.
M1_NEW_OFF ?=
# make remote's T is word-split: M1_GD=1 appends --brains-off=native to every arm; M1_SEEDS=a-b replaces HULL_SEEDS.
M1_GD ?=
# M1_GDD=1 appends --brains-off=native_drive (planner's judge flags: the GDScript drive under the native planner; with
# --brains-off=native the seam's plans are never answered inside their slice and every k-turn ask is abandoned).
M1_GDD ?=
M1_SEEDS ?=
M1_SEED_LIST = $(if $(M1_SEEDS),$(shell seq $(subst -, ,$(M1_SEEDS))),$(HULL_SEEDS))
# Round 33 (R33.21, 2026-10-18): hull-rest and hull-one run --fixed-fps $(SIM_HZ). Before this they were wall-clock paced
# with HULL_JOBS runs sharing the box, so the box's load could change what a crew was doing at the judge. Numbers from
# before the pin (every hull-rest series to round 33's CP-F, b6c2a974, and planner's P2/P3) do NOT compare with numbers
# after it; re-run both arms under the pin.
# Round 33 (R33.34 / the overnight judge item): the faced stage placed the same army on the same spots whatever the seed
# (`--seed` reaches only the RNG), so most seeds repeated another's rows (CP-F attempt 3: 21 distinct pairs of 64 a task).
# The SEED now sets the drawn facing too: FACED_OFF_TRAVEL_DEG (60) +- HULL_JITTER_DEG, a whole degree from the seed, so
# every crew's turn differs seed to seed. HULL_JITTER_DEG=0 restores the fixed 60. Numbers from before this (every
# hull-rest series to CP-F attempt 3) do NOT compare with numbers after it.
HULL_JITTER_DEG ?= 20
_hull_jitter = $(if $(filter-out 0,$(HULL_JITTER_DEG)),--faced-off-deg=$$(( 60 - $(HULL_JITTER_DEG) + ($(1)) % (2 * $(HULL_JITTER_DEG) + 1) )))
# Round 34 (M1 (2B), the ruler): the seed also shifts the order's destination HULL_SHIFT_M metres in a seed-hashed
# direction (screen_playtest's --faced-shift-m), so two seeds never share a geometry. HULL_SHIFT_M=0 restores the fixed
# destination. Numbers from before this (every hull-rest series to CP-F attempt 3) do NOT compare with numbers after it.
HULL_SHIFT_M ?= 6
_hull_shift = $(if $(filter-out 0,$(HULL_SHIFT_M)),--faced-shift-m=$(HULL_SHIFT_M))
.PHONY: manoeuvre-hull-rest
manoeuvre-hull-rest: import ## manoeuvre M1: hull facing at rest per hull class, drawn/clicked x new/base (--nav-off=turnhull) on one commit -> build/manoeuvre/hull-rest/ + the A/B table
	mkdir -p $(M1_DIR) && for arm in $(M1_ARMS); do rm -rf $(M1_DIR)/$$arm; done  # one arm a call keeps the others
	for arm in $(M1_ARMS); do for faction in $(HULL_FACTIONS); do for seed in $(M1_SEED_LIST); do for task in $(_FACING_TASKS); do \
		echo "$$arm $$faction $$seed $$task"; done; done; done; done | xargs -P $(HULL_JOBS) -L 1 sh -c '\
		d=$(M1_DIR)/$$0/$$1/$$3-$$2; mkdir -p $$d; enemy=law; [ $$1 = law ] && enemy=gangs; \
		click=""; case $$0 in *clicked) click=--faced-click;; esac; off=""; case $$0 in base_*) off=$(if $(M1_BASE_OFF),--nav-off=$(M1_BASE_OFF));; new_*) off=$(if $(M1_NEW_OFF),--nav-off=$(M1_NEW_OFF));; esac; \
		timeout 300 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --skirmish --seed=$$2 --no-pick-faction --mute --arena=$(FACING_ARENA) \
			--player-faction=$$1 --enemy-faction=$$enemy --tune=match.no_damage=1 --enemy=$(FACING_QUIET_ENEMY) \
			--no-element-cpu $$click $$off $(M1_FLAGS) $(if $(M1_GD),--brains-off=native) $(if $(M1_GDD),--brains-off=native_drive) $(call _hull_jitter,$$2) $(_hull_shift) \
			--screen-test=$(CURDIR)/$$d --screen-only=$$3 > $$d/run.log 2>&1; \
		grep -q SCREEN_DONE $$d/run.log || echo "manoeuvre-hull-rest: $$d has no SCREEN_DONE"; \
		! grep -m1 "SCRIPT ERROR" $$d/run.log'
	$(PYTHON) tests/manoeuvre/hull_rest_ab.py $(M1_DIR)
	$(PYTHON) tests/manoeuvre/hull_rest_moving.py $(M1_DIR)
	$(PYTHON) tests/manoeuvre/hull_rest_counters.py $(M1_DIR)

# One run of manoeuvre-hull-rest's workload, for a trace: ONE_FACTION, ONE_SEED, ONE_TASK, ONE_CLICK=1 for the clicked
# arm, NAV_FLAGS (e.g. --turn-trace=<unit> --nav-off=turnhull) -> build/manoeuvre/hull-one/run.log + screen.json.
.PHONY: manoeuvre-hull-one
manoeuvre-hull-one: import ## manoeuvre M1: one hull-rest run (ONE_FACTION ONE_SEED ONE_TASK [ONE_CLICK=1] NAV_FLAGS) -> build/manoeuvre/hull-one/
	@d=$(BUILD_DIR)/manoeuvre/hull-one; rm -rf $$d && mkdir -p $$d; enemy=law; [ "$(ONE_FACTION)" = law ] && enemy=gangs; \
	timeout 300 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --skirmish --seed=$(ONE_SEED) --no-pick-faction --mute --arena=$(FACING_ARENA) \
		--player-faction=$(ONE_FACTION) --enemy-faction=$$enemy --tune=match.no_damage=1 --enemy=$(FACING_QUIET_ENEMY) \
		--no-element-cpu $(if $(ONE_CLICK),--faced-click) $(NAV_FLAGS) $(call _hull_jitter,$(ONE_SEED)) \
		--screen-test=$(CURDIR)/$$d --screen-only=$(ONE_TASK) \
		> $$d/run.log 2>&1; grep -q SCREEN_DONE $$d/run.log || echo "manoeuvre-hull-one: no SCREEN_DONE"; \
	grep -c MANOEUVRE_TRACE $$d/run.log || true
# Round 33 (the overnight judge item, R33.34): the seed must vary the faced stage. Two hull-one runs of one task on
# two seeds (default 40 and 41, gangs, faced_move); fails if their screen rows are identical (they were, before the
# per-seed facing jitter: hull-rest repeated seeds, 21 distinct pairs of 64 a task on CP-F attempt 3).
SEEDS_DIFFER_A ?= 40
SEEDS_DIFFER_B ?= 41
.PHONY: manoeuvre-hull-seeds-differ
manoeuvre-hull-seeds-differ: import ## manoeuvre: two seeds of one hull-rest task give different rows (the per-seed jitter works)
	@d=$(BUILD_DIR)/manoeuvre/seeds-differ; rm -rf $$d && mkdir -p $$d; \
	for seed in $(SEEDS_DIFFER_A) $(SEEDS_DIFFER_B); do \
		$(MAKE) --no-print-directory manoeuvre-hull-one ONE_FACTION=gangs ONE_SEED=$$seed ONE_TASK=faced_move > /dev/null 2>&1; \
		cp $(BUILD_DIR)/manoeuvre/hull-one/screen.json $$d/$$seed.json || { echo "manoeuvre-hull-seeds-differ: seed $$seed wrote no rows"; exit 1; }; \
	done; \
	if cmp -s $$d/$(SEEDS_DIFFER_A).json $$d/$(SEEDS_DIFFER_B).json; then \
		echo "manoeuvre-hull-seeds-differ: FAIL, seeds $(SEEDS_DIFFER_A) and $(SEEDS_DIFFER_B) gave identical rows"; exit 1; fi; \
	echo "manoeuvre-hull-seeds-differ: PASS, seeds $(SEEDS_DIFFER_A) and $(SEEDS_DIFFER_B) differ (drawn $$($(PYTHON) -c "import json,sys; print([r['drawn'] for r in json.load(open(sys.argv[1])) if 'drawn' in r][0])" $$d/$(SEEDS_DIFFER_A).json) v $$($(PYTHON) -c "import json,sys; print([r['drawn'] for r in json.load(open(sys.argv[1])) if 'drawn' in r][0])" $$d/$(SEEDS_DIFFER_B).json))"

# ---- round 29 (M4): the fights guard -----------------------------------------------------------------------------
# The showmatch's own match headless per FIGHT_SEEDS (tests/manoeuvre/fight_census.gd: shots, hits, kills, deaths per
# team; shots at and hits on targets touching something), NAV_FLAGS for an arm -> build/manoeuvre/fights/<seed>.log.
# Two arms side by side: tests/manoeuvre/fight_table.py BASE_DIR NEW_DIR (paired by seed, within 2 se).
FIGHT_SEEDS ?= 1 2 3 4 5 6 7 8
# Round 35: FIGHT_RANGE=a-b replaces FIGHT_SEEDS (make remote's T is word-split, so a list can't travel).
FIGHT_RANGE ?=
override FIGHT_SEEDS := $(if $(FIGHT_RANGE),$(shell seq $(subst -, ,$(FIGHT_RANGE))),$(FIGHT_SEEDS))
FIGHT_JOBS ?= 4
FIGHT_SECONDS ?= 180
# Round 35 (R34.15/R35.7: random arenas deal twins): FIGHT_AT = a comma list of fixed arenas runs each seed on each
# (logs <arena>-<seed>.log; fight_table pairs by arena and seed). Default random, as before.
FIGHT_AT ?= random
.PHONY: manoeuvre-fights
manoeuvre-fights: import ## manoeuvre M4: the fights guard (showmatch matches, FIGHT_SEEDS, every unit: shots, hits, kills, deaths, hits on touching targets; NAV_FLAGS for an arm) -> build/manoeuvre/fights/
	@rm -rf $(BUILD_DIR)/manoeuvre/fights; mkdir -p $(BUILD_DIR)/manoeuvre/fights
	@echo ">> manoeuvre-fights on $$(hostname) | flags '$(NAV_FLAGS)'"
	@if [ "$(FIGHT_AT)" = random ]; then \
	for seed in $(FIGHT_SEEDS); do echo $$seed; done | xargs -P $(FIGHT_JOBS) -I{} sh -c 'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . \
		--script res://tests/manoeuvre/fight_census.gd -- --skirmish --demo-match --clean --seed={} --arena=random --mute \
		--seconds=$(FIGHT_SECONDS) $(NAV_FLAGS) > $(BUILD_DIR)/manoeuvre/fights/{}.log 2>&1 || true'; \
	else \
	for seed in $(FIGHT_SEEDS); do for arena in $(subst $(comma), ,$(FIGHT_AT)); do echo "$$arena $$seed"; done; done | \
		xargs -P $(FIGHT_JOBS) -L 1 sh -c 'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . \
		--script res://tests/manoeuvre/fight_census.gd -- --skirmish --demo-match --clean --seed=$$1 --arena=$$0 --mute \
		--seconds=$(FIGHT_SECONDS) $(NAV_FLAGS) > $(BUILD_DIR)/manoeuvre/fights/$$0-$$1.log 2>&1 || true'; \
	fi
	@grep -h '^FIGHT_CENSUS' $(BUILD_DIR)/manoeuvre/fights/*.log | wc -l | xargs echo "manoeuvre-fights: FIGHT_CENSUS rows"

# ---- round 31 (CP-H, C31.4, R31.1): the honest reading's consumers, ONE arm x ONE stage a call ---------------------
# Every consumer is OPT-IN (naming it turns it ON). R31.1's addendum (native): --gun-off, --traffic-off and
# --brains-off names do NOT leave native's drive/gun, so an arm without --brains-off=native would silently run the OFF
# behaviour on the native path: every CP-H arm runs the GDScript path, and this runner REFUSES an arm whose flags lack
# it. CPH_ARM = off | all | allnoghost | unstickback | kturnarc | realspeed | ghost | realslow (each consumer alone, REPORTED).
# CPH_STAGE = census (Terminus rigs+mixed, CENSUS_SEEDS) | sbf (B6's SBF probe, gang_ifv) | drive (nav-terminus-drive, DRIVE_SEEDS) | fights (FIGHT_SEEDS)
# | hull (hull-rest, drawn, HULL_SEEDS; one arm a call, lesson 311) | bridge (bridge-pooled). The arm's flags are printed
# first (lesson 309: the run's own printout is the proof of what ran).
CPH_ARM ?= off
CPH_STAGE ?= census
CPH_FLAGS_off := --brains-off=native
CPH_FLAGS_all := --nav-off=unstickback,kturnarc --gun-off=realspeed --traffic-off=ghost --brains-off=native,realslow
# CP-H without traffic's T4 (if T4 stands down for this round, the orchestrator's 09:00 PDT cutoff).
CPH_FLAGS_allnoghost := --nav-off=unstickback,kturnarc --gun-off=realspeed --brains-off=native,realslow
CPH_FLAGS_unstickback := --nav-off=unstickback --brains-off=native
CPH_FLAGS_kturnarc := --nav-off=kturnarc --brains-off=native
CPH_FLAGS_realspeed := --gun-off=realspeed --brains-off=native
CPH_FLAGS_ghost := --traffic-off=ghost --brains-off=native
CPH_FLAGS_realslow := --brains-off=native,realslow
# M1b(2)'s judged arms through the same runner (one flag, GDScript path; base = `off`).
CPH_FLAGS_turnhull := --nav-off=turnhull --brains-off=native
# Round 35: Bar M5's base (CP-F attempt 5: turnhull and facesettle both off; on lab/cpf5 both default true), and Bar M6's ON
# arm before native's mirror (W1c + traffic's T9; on the joint pair the defaults flip and the base is `stallintentbase`).
CPH_FLAGS_cpf5base := --nav-off=turnhull,facesettle --brains-off=native
CPH_FLAGS_w1ct9 := --nav-off=stallintent --traffic-on=yieldfit2 --brains-off=native
# Round 32: H1b's judged arm through the same runner (base = `off`; H1b's counters ride on MANOEUVRE_TURNS and FIGHT_CENSUS).
CPH_FLAGS_h1b := --nav-off=h1b --brains-off=native
CPH_FLAGS = $(CPH_FLAGS_$(CPH_ARM))
# CPH_SEEDS=a-b (make remote's T is word-split, so a range, not a list): the stage's seeds; empty = the stage's default.
CPH_SEEDS ?=
CPH_SEED_LIST = $(if $(CPH_SEEDS),$(shell seq $(subst -, ,$(CPH_SEEDS))))
CPH_SEED_VARS = $(if $(CPH_SEEDS),"CENSUS_SEEDS=$(CPH_SEED_LIST)" "DRIVE_SEEDS=$(CPH_SEED_LIST)" "FIGHT_SEEDS=$(CPH_SEED_LIST)" "HULL_SEEDS=$(CPH_SEED_LIST)" "BRIDGE_POOLED_SEEDS=$(CPH_SEED_LIST)")
.PHONY: manoeuvre-cph
manoeuvre-cph: import ## manoeuvre CP-H: one consumer arm (CPH_ARM=off|all|allnoghost|unstickback|kturnarc|realspeed|ghost|realslow) on one stage (CPH_STAGE=census|drive|fights|hull|bridge), GDScript path enforced
	@flags='$(CPH_FLAGS)'; [ -n "$$flags" ] || { echo ">> manoeuvre-cph: no such arm '$(CPH_ARM)'"; exit 2; }; \
	case "$$flags" in *--brains-off=native*) ;; *) echo ">> manoeuvre-cph: REFUSED arm '$(CPH_ARM)': no --brains-off=native (R31.1: it would run native's OFF path)"; exit 2;; esac; \
	echo ">> manoeuvre-cph: arm $(CPH_ARM) stage $(CPH_STAGE) on $$(hostname) commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-?}) | flags $$flags | seeds $(or $(CPH_SEED_LIST),default)"
	@case "$(CPH_STAGE)" in \
	census) $(MAKE) --no-print-directory manoeuvre-census CENSUS_WORKLOADS=terminus $(CPH_SEED_VARS) 'NAV_FLAGS=$(CPH_FLAGS)';; \
	drive) $(MAKE) --no-print-directory nav-terminus-drive $(CPH_SEED_VARS) 'NAV_FLAGS=$(CPH_FLAGS) --turn-states';; \
	fights) $(MAKE) --no-print-directory manoeuvre-fights $(CPH_SEED_VARS) 'NAV_FLAGS=$(CPH_FLAGS)';; \
	hull) $(MAKE) --no-print-directory manoeuvre-hull-rest M1_ARMS=cph-$(CPH_ARM)_drawn $(CPH_SEED_VARS) 'M1_FLAGS=--turn-states $(CPH_FLAGS)';; \
	bridge) $(MAKE) --no-print-directory bridge-pooled $(CPH_SEED_VARS) 'BRIDGE_FLAGS=$(CPH_FLAGS)';; \
	sbf) $(MAKE) --no-print-directory sbf-series SBF_UNITS=gang_ifv $(if $(CPH_SEEDS),"SBF_SEEDS=$(CPH_SEED_LIST)") 'SBF_FLAGS=$(CPH_FLAGS)';; \
	*) echo ">> manoeuvre-cph: no such stage '$(CPH_STAGE)'"; exit 2;; esac

# ---- round 31 (M6, C31.3/C31.9): the census's early-stop reading (traffic's hook, the Terminus form) ---------------
# Two census folders (base, new) -> tests/manoeuvre/terminus_ab.py's paired table -> tools/judge/sequential.py's walk
# per squad over the runs that exist (CONTINUE / SERIES PASS at run j / SERIES FAIL at run j). It never stops a run: the
# stream decides by judging.md's one rule and records the row. SEQ_TERMINUS_LINES = the bar's lines in sequential's form.
SEQ_TERMINUS_LINES ?= arrived:guard:0.10
.PHONY: manoeuvre-census-seq
manoeuvre-census-seq: ## manoeuvre: the early-stop reading of a Terminus census A/B (SEQ_BASE_DIR, SEQ_NEW_DIR: two census folders) per squad
	@[ -d "$(SEQ_BASE_DIR)" ] && [ -d "$(SEQ_NEW_DIR)" ] || { echo ">> manoeuvre-census-seq: SEQ_BASE_DIR and SEQ_NEW_DIR must be census folders"; exit 2; }
	@mkdir -p $(BUILD_DIR)/manoeuvre && $(PYTHON) tests/manoeuvre/terminus_ab.py $(SEQ_BASE_DIR) $(SEQ_NEW_DIR) > $(BUILD_DIR)/manoeuvre/census_ab.txt
	@cat $(BUILD_DIR)/manoeuvre/census_ab.txt
	@for squad in mixed rigs; do echo ">> early-stop reading, $$squad:"; \
		$(PYTHON) tools/judge/sequential.py --terminus $(BUILD_DIR)/manoeuvre/census_ab.txt --squad $$squad --lines $(SEQ_TERMINUS_LINES) | sed 's/^/  /' || true; done

# Round 31 (CP-H's clip for the lead): one Terminus drive filmed twice on the same seed, today (every consumer OFF) and
# shipped (the four CP-H consumers ON by name, = the ship tree's defaults), side by side -> MOVIE (default
# build/manoeuvre/pin_clip.mp4). The drive is the measured one (tests/manoeuvre/pin_clip.gd adds only a camera and a
# caption). Needs a display: make remote LIGHT=1 T="manoeuvre-pin-clip CLIP_SEED=134 CLIP_FOLLOW=Green_S0_3".
# CLIP_FROM/CLIP_TO: the window in sim seconds; CLIP_FOLLOW2 frames the squadmate too.
CLIP_SQUAD ?= rigs
CLIP_SEED ?= 134
CLIP_FOLLOW ?= Green_S0_3
CLIP_FOLLOW2 ?=
CLIP_FROM ?= 0
CLIP_TO ?= 120
# CLIP_SPEED: playback speed-up of the stacked clip (2 = twice real time).
CLIP_SPEED ?= 1
CLIP_SHIPPED_FLAGS := --nav-off=unstickback,kturnarc --gun-off=realspeed --brains-off=native,realslow
.PHONY: manoeuvre-pin-clip
manoeuvre-pin-clip: import ## manoeuvre: a Terminus drive filmed today v shipped (CP-H's consumers), side by side -> MOVIE (needs a display; CLIP_SEED, CLIP_SQUAD, CLIP_FOLLOW, CLIP_FOLLOW2, CLIP_FROM, CLIP_TO, CLIP_SPEED)
	@out=$(BUILD_DIR)/manoeuvre/pin-clip; rm -rf $$out && mkdir -p $$out; \
	movie="$(or $(MOVIE),$(CURDIR)/$(BUILD_DIR)/manoeuvre/pin_clip.mp4)"; case "$$movie" in /*) ;; *) movie="$(CURDIR)/$$movie" ;; esac; \
	commit=$$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-?}); \
	echo ">> manoeuvre-pin-clip on $$(hostname) commit $$commit | $(CLIP_SQUAD) seed $(CLIP_SEED) | $(CLIP_FOLLOW) $(CLIP_FOLLOW2) | $(CLIP_FROM)-$(CLIP_TO) s"; \
	for arm in today shipped; do \
		if [ $$arm = today ]; then flags="--brains-off=native"; cap="TODAY"; else flags="$(CLIP_SHIPPED_FLAGS)"; cap="SHIPPED"; fi; \
		timeout 1800 $(GODOT) --path . --fixed-fps $(DEMO_FPS) --resolution 960x540 --write-movie $(CURDIR)/$$out/$$arm.avi \
			--script res://tests/manoeuvre/pin_clip.gd -- --squad=$(CLIP_SQUAD) --seed=$(CLIP_SEED) --follow=$(CLIP_FOLLOW) \
			--follow2=$(CLIP_FOLLOW2) --clip-to=$(CLIP_TO) "--caption=$$cap ($$commit)" $$flags > $$out/$$arm.log 2>&1 || true; \
		grep -E "PIN_CLIP_DONE|SCRIPT ERROR|NAV_DRIVE_CONTROL" $$out/$$arm.log | cut -c1-300 || true; \
	done; \
	command -v ffmpeg >/dev/null || { echo ">> manoeuvre-pin-clip: no ffmpeg; the AVIs are in $$out"; exit 0; }; \
	ffmpeg -loglevel error -y -ss $(CLIP_FROM) -i $$out/today.avi -ss $(CLIP_FROM) -i $$out/shipped.avi \
		-filter_complex "[0:v][1:v]hstack=inputs=2,scale=1920:-2,setpts=PTS/$(CLIP_SPEED)[v]" -map "[v]" -c:v libx264 -preset slow -crf 20 \
		-pix_fmt yuv420p -movflags +faststart "$$movie" && echo "PIN_CLIP_MOVIE $$movie"

# ---- round 32 (H1b, C32.2): the ask that never frees, on the Terminus drive ----------------------------------------
# Both arms on the GDScript path (R31.1): base `--brains-off=native`, H1b `--nav-off=h1b --brains-off=native`, per
# H1B_SQUADS x H1B_SEEDS, each run its own process -> build/manoeuvre/h1b-drive/<arm>-<squad>-<seed>.log; prints each
# run's NAV_DRIVE_LEG rows and its H1B_DRIVE line (H1b's counters and the escape's arms).
H1B_SQUADS ?= rigs
H1B_SEEDS ?= 31
# H1B_SEEDS=a-b is a range (make remote's T is word-split, so a list cannot be passed through it).
H1B_SEED_LIST = $(if $(findstring -,$(H1B_SEEDS)),$(shell seq $(subst -, ,$(H1B_SEEDS))),$(H1B_SEEDS))
# H1B_SQUADS=both runs rigs and mixed (the same word-split reason).
H1B_SQUAD_LIST = $(if $(filter both,$(H1B_SQUADS)),rigs mixed,$(H1B_SQUADS))
H1B_JOBS ?= 4
.PHONY: manoeuvre-h1b-drive
manoeuvre-h1b-drive: import ## manoeuvre H1b: the Terminus drive base v H1b on the GDScript path (H1B_SQUADS, H1B_SEEDS) -> build/manoeuvre/h1b-drive/
	@out=$(BUILD_DIR)/manoeuvre/h1b-drive; rm -rf $$out && mkdir -p $$out; \
	echo ">> manoeuvre-h1b-drive on $$(hostname) commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-?}) | $(H1B_SQUAD_LIST) | seeds $(H1B_SEED_LIST)"; \
	for arm in base h1b; do for squad in $(H1B_SQUAD_LIST); do for seed in $(H1B_SEED_LIST); do echo $$arm-$$squad-$$seed; done; done; done | \
	xargs -P $(H1B_JOBS) -I{} sh -c 'run={}; arm=$${run%%-*}; rest=$${run#*-}; \
		if [ $$arm = h1b ]; then flags="--nav-off=h1b --brains-off=native"; else flags="--brains-off=native"; fi; \
		timeout 1800 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/manoeuvre/h1b_drive.gd -- \
			--squad=$${rest%-*} --seed=$${rest##*-} --arena=terminus --leg-time=$(or $(DRIVE_LEG_TIME),90) --turn-states $$flags $(NAV_FLAGS) \
			> '$$out'/{}.log 2>&1; echo ">> manoeuvre-h1b-drive: {} done"'
	@for f in $(BUILD_DIR)/manoeuvre/h1b-drive/*.log; do echo "== $$f"; grep -E "^NAV_DRIVE_LEG|^H1B_DRIVE|SCRIPT ERROR|control FAILED" $$f | cut -c1-900 || true; done
	@$(PYTHON) tests/manoeuvre/h1b_table.py $(BUILD_DIR)/manoeuvre/h1b-drive/*.log
	@# PINNED / STUCK per squad (pinned_table.py pairs <root>/<seed>/drive/run.log across the two arms).
	@out=$(BUILD_DIR)/manoeuvre/h1b-drive; for f in $$out/*.log; do b=$$(basename $$f .log); arm=$${b%%-*}; rest=$${b#*-}; \
		d=$$out/pinned/$$arm-$${rest%-*}/$${rest##*-}/drive; mkdir -p $$d; ln -sf $(CURDIR)/$$f $$d/run.log; done; \
	for squad in $(H1B_SQUAD_LIST); do echo "== pinned $$squad (base v h1b)"; \
		$(PYTHON) tests/manoeuvre/pinned_table.py $$out/pinned/base-$$squad $$out/pinned/h1b-$$squad || true; done

# ---- round 33 (stretch): the War Rig told to face, filmed before and after CP-F ------------------------------------
# His gesture, the screen test's faced right-drag (faced_right) on gangs (War Rigs), filmed windowed on ONE seed twice:
# BEFORE = today (round 8's decline: the turret takes the drawn facing, the hull stays) and AFTER = turnhull ON (the hull
# turns to it). Both arms on the GDScript path (R31.1). Side by side -> FACE_CLIP_MOVIE (default
# build/manoeuvre/face_clip.mp4). Needs a display (the laptop). FACE_CLIP_ON: the AFTER arm's switch; on a tree where
# TURN_HULL_DEFAULT is already true, pass FACE_CLIP_ON= and FACE_CLIP_OFF=--nav-off=turnhull.
FACE_CLIP_SEED ?= 5
FACE_CLIP_FACTION ?= gangs
FACE_CLIP_TASK ?= faced_right
FACE_CLIP_OFF ?=
FACE_CLIP_ON ?= --nav-off=turnhull
FACE_CLIP_SPEED ?= 2
# The drawn angle off the travel (180 = behind; the screen test's own default is 60).
FACE_CLIP_DEG ?= 180
# The squads the drag selects (1 = squad 1 alone; empty = the probe's own 1 and 2).
FACE_CLIP_SQUADS ?=
.PHONY: manoeuvre-face-clip
manoeuvre-face-clip: import ## manoeuvre stretch: a drawn facing on War Rigs filmed before v after CP-F (turnhull), side by side -> FACE_CLIP_MOVIE (needs a display)
	@out=$(BUILD_DIR)/manoeuvre/face-clip; rm -rf $$out && mkdir -p $$out; \
	movie="$(or $(FACE_CLIP_MOVIE),$(CURDIR)/$(BUILD_DIR)/manoeuvre/face_clip.mp4)"; case "$$movie" in /*) ;; *) movie="$(CURDIR)/$$movie" ;; esac; \
	commit=$$(git rev-parse --short HEAD 2>/dev/null || echo ?); enemy=law; [ "$(FACE_CLIP_FACTION)" = law ] && enemy=gangs; \
	echo ">> manoeuvre-face-clip on $$(hostname) commit $$commit | $(FACE_CLIP_FACTION) $(FACE_CLIP_TASK) $(FACE_CLIP_DEG) deg seed $(FACE_CLIP_SEED)"; \
	for arm in before after; do \
		if [ $$arm = before ]; then off="$(FACE_CLIP_OFF)"; else off="$(FACE_CLIP_ON)"; fi; mkdir -p $$out/$$arm; \
		timeout 600 $(GODOT) --path . --fixed-fps $(DEMO_FPS) --resolution 960x540 --write-movie $(CURDIR)/$$out/$$arm.avi \
			-- --skirmish --seed=$(FACE_CLIP_SEED) --no-pick-faction --mute --arena=$(FACING_ARENA) \
			--player-faction=$(FACE_CLIP_FACTION) --enemy-faction=$$enemy --tune=match.no_damage=1 --enemy=$(FACING_QUIET_ENEMY) \
			--no-element-cpu $$off --brains-off=native --turn-states --screen-test=$(CURDIR)/$$out/$$arm \
			--screen-only=$(FACE_CLIP_TASK) --faced-off-deg=$(FACE_CLIP_DEG) $(if $(FACE_CLIP_SQUADS),--faced-squads=$(FACE_CLIP_SQUADS)) > $$out/$$arm.log 2>&1 || true; \
		grep -E "^SCREEN |SCREEN_DONE|SCRIPT ERROR" $$out/$$arm.log | cut -c1-300 || true; \
	done; \
	command -v ffmpeg >/dev/null || { echo ">> manoeuvre-face-clip: no ffmpeg; the AVIs are in $$out"; exit 0; }; \
	ffmpeg -loglevel error -y -i $$out/before.avi -i $$out/after.avi -filter_complex \
		"[0:v]drawtext=text='BEFORE (today)':x=20:y=20:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.5[a];[1:v]drawtext=text='AFTER (CP-F, $$commit)':x=20:y=20:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.5[b];[a][b]hstack=inputs=2:shortest=0,scale=1920:-2,setpts=PTS/$(FACE_CLIP_SPEED)[v]" \
		-map "[v]" -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart "$$movie" && echo "FACE_CLIP_MOVIE $$movie"

# ---- round 33 (C33.9, his scout out-turned by an orbiting attacker) ---------------------------------------------------
C339_SEEDS ?= 11-16
C339_JOBS ?= 1
# C339_SET=report: the reported cell (gang_scout v syn_lancer 15 m post) instead of the bar's 24 cells (round 34).
C339_SET ?=
manoeuvre-c339-cells: import ## manoeuvre: C33.9's bar cells (turn-in ON v OFF, both GDScript; C339_JOBS seeds at once, one --fixed-fps process a seed: the box's load never paces the sim) -> build/manoeuvre/c339_cells.jsonl
	@d=$(BUILD_DIR)/manoeuvre/c339; rm -rf $$d; mkdir -p $$d; first=$${C339_SEEDS%-*}; last=$${C339_SEEDS#*-}; status=0; \
	for seed in $$(seq $$first $$last); do \
		while [ $$(jobs -rp | wc -l) -ge $(C339_JOBS) ]; do sleep 1; done; \
		( C339_CELLS=$$seed-$$seed C339_SET=$(C339_SET) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/run_tests.gd -- --filter=c339_cells \
			> $$d/$$seed.log 2>&1; echo $$? > $$d/$$seed.status ) & \
	done; wait; \
	for seed in $$(seq $$first $$last); do [ "$$(cat $$d/$$seed.status)" = 0 ] || status=1; tail -1 $$d/$$seed.log | sed "s/^/   seed $$seed: /"; done; \
	cat $$d/*.log > $(BUILD_DIR)/manoeuvre/c339_cells.log; \
	grep -h '^C339_CELL ' $$d/*.log | cut -d' ' -f2- > $(BUILD_DIR)/manoeuvre/c339_cells.jsonl; \
	echo ">> manoeuvre-c339-cells: seeds $(C339_SEEDS), jobs $(C339_JOBS), $$(wc -l < $(BUILD_DIR)/manoeuvre/c339_cells.jsonl) cells, commit $$(git rev-parse --short HEAD 2>/dev/null || echo none)"; \
	exit $$status

# Round 35 (W1, C35.6): why crews die wedged. WEDGE_AT x WEDGE_RANGE showmatch fights through tests/manoeuvre/wedge_trace.gd
# (WEDGE_EP per wedged episode, WEDGE_DEATH with a 10 s timeline per stuck:wedged death) -> WEDGE_DIR + the table.
# Measurement only; judged/traced on the native path: run as `native manoeuvre-wedge-trace`.
WEDGE_RANGE ?= 3500-3503
WEDGE_AT ?= locks,terminus
WEDGE_JOBS ?= 4
WEDGE_SECONDS ?= 180
WEDGE_FLAGS ?=
WEDGE_DIR ?= $(BUILD_DIR)/manoeuvre/wedge
.PHONY: manoeuvre-wedge-trace
manoeuvre-wedge-trace: import ## manoeuvre W1: wedged episodes and wedged deaths, what moved each hull (ORCA, holds, yields, unstick, the drive), WEDGE_AT x WEDGE_RANGE -> WEDGE_DIR + table
	@rm -rf $(WEDGE_DIR); mkdir -p $(WEDGE_DIR)
	@echo ">> manoeuvre-wedge-trace on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | arenas '$(WEDGE_AT)' seeds '$(WEDGE_RANGE)' | flags '$(WEDGE_FLAGS)' | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for seed in $$(seq $(subst -, ,$(WEDGE_RANGE))); do for arena in $(subst $(comma), ,$(WEDGE_AT)); do echo "$$arena $$seed"; done; done | \
		xargs -P $(WEDGE_JOBS) -L 1 sh -c 'timeout 1200 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . \
		--script res://tests/manoeuvre/wedge_trace.gd -- --skirmish --demo-match --clean --seed=$$1 --arena=$$0 --mute \
		--seconds=$(WEDGE_SECONDS) $(WEDGE_FLAGS) > $(WEDGE_DIR)/$$0-$$1.log 2>&1 || true; \
		grep -q "^WEDGE_TRACE" $(WEDGE_DIR)/$$0-$$1.log && echo "  ran $$0 s$$1" || echo "  MISSING WEDGE_TRACE $$0 s$$1"'
	@grep -l "NATIVE" $(WEDGE_DIR)/*.log | head -1 | xargs -r grep -m1 "NATIVE" || true
	@$(PYTHON) tests/manoeuvre/wedge_table.py $(WEDGE_DIR) --top 3

# Round 35 (W1, the orchestrator's relay of brains' E1 census): ONE hull-rest cell (manoeuvre-hull-rest's own flags) under
# tests/manoeuvre/wedge_trace.gd, with HT_CREW's state every 0.5 s (WEDGE_TICK) -> build/manoeuvre/hull-trace/<cell>.log.
# HT_OFF a --nav-off list (empty = the tree's default, native); HT_FLAGS anything else (e.g. --brains-off=native).
HT_FACTION ?= law
HT_SEED ?= 605
HT_TASK ?= faced_attack_move
HT_CREW ?= Green_Eyes_4
HT_OFF ?=
HT_FLAGS ?=
.PHONY: manoeuvre-hull-trace
manoeuvre-hull-trace: import ## manoeuvre W1: one hull-rest cell (HT_FACTION HT_SEED HT_TASK) traced, HT_CREW every 0.5 s (what moves it, unstick, colliders, Traffic) -> build/manoeuvre/hull-trace/
	@d=$(BUILD_DIR)/manoeuvre/hull-trace/$(HT_FACTION)-$(HT_TASK)-$(HT_SEED); rm -rf $$d; mkdir -p $$d; enemy=law; [ $(HT_FACTION) = law ] && enemy=gangs; \
	echo ">> manoeuvre-hull-trace on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-?}) | $(HT_FACTION) $(HT_TASK) $(HT_SEED) $(HT_CREW) | off '$(HT_OFF)' flags '$(HT_FLAGS)'"; \
	timeout 600 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/manoeuvre/wedge_trace.gd -- --skirmish --seed=$(HT_SEED) \
		--no-pick-faction --mute --arena=$(FACING_ARENA) --player-faction=$(HT_FACTION) --enemy-faction=$$enemy --tune=match.no_damage=1 \
		--enemy=$(FACING_QUIET_ENEMY) --no-element-cpu $(if $(HT_OFF),--nav-off=$(HT_OFF)) $(HT_FLAGS) $(call _hull_jitter,$(HT_SEED)) $(_hull_shift) \
		--screen-test=$(CURDIR)/$$d --screen-only=$(HT_TASK) --trace-crew=$(HT_CREW) --seconds=0 > $$d/run.log 2>&1 || true; \
	grep -c '^WEDGE_TICK' $$d/run.log | xargs echo "manoeuvre-hull-trace: WEDGE_TICK rows"; grep -m1 NATIVE_EXEC $$d/run.log || true; \
	grep -m1 "SCRIPT ERROR" $$d/run.log || true

# Round 38 (manoeuvre M7 = O5 v2's trace, measurement only): tests/manoeuvre/aside_trace.gd (orders' seat_yield_census + the
# asker's ways) on ASIDE_AT x ASIDE_SEEDS showmatch fights -> ASIDE_DIR/<arena>-<seed>.log. ASIDE_FLAGS e.g. --seat-aside=on.
ASIDE_AT ?= locks gorge terminus
ASIDE_SEEDS ?= 3801-3806
ASIDE_FLAGS ?=
ASIDE_JOBS ?= $(JOBS)
ASIDE_DIR ?= $(BUILD_DIR)/manoeuvre/aside
.PHONY: manoeuvre-aside-trace
manoeuvre-aside-trace: import ## manoeuvre M7: seat give-ways to another element's crew + the asker's ways (ASIDE_AT ASIDE_SEEDS ASIDE_FLAGS) -> build/manoeuvre/aside/
	@rm -rf $(ASIDE_DIR); mkdir -p $(ASIDE_DIR)
	@echo ">> manoeuvre-aside-trace on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | flags '$(ASIDE_FLAGS)'"
	@for seed in $(shell seq $(subst -, ,$(ASIDE_SEEDS))); do for arena in $(ASIDE_AT); do echo "$$arena $$seed"; done; done | xargs -P $(ASIDE_JOBS) -L 1 sh -c \
		'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/manoeuvre/aside_trace.gd -- \
		--skirmish --demo-match --clean --seed=$$1 --arena=$$0 --mute --seconds=180 $(ASIDE_FLAGS) > $(ASIDE_DIR)/$$0-$$1.log 2>&1 || true'
	@grep -h '^SEAT_YIELD_CENSUS' $(ASIDE_DIR)/*.log | wc -l | xargs echo ">> manoeuvre-aside-trace: fights with a census row:"

# ---- round 39 (M1's G5 fail): who a never-in squad is stuck behind --------------------------------------------------
# Orders' probe cells (map:squads:route:seed, PW_CELLS) in each arm (PW_ARMS, orders-probe's name:flags form), run under
# tests/manoeuvre/probe_wedge.gd (the probe unchanged + the partner of every still crew under way) -> PROBE_WEDGE rows and the
# probe's own ORDERS_PROBE_SQUAD rows in $(PW_DIR)/*.log, then tests/manoeuvre/probe_wedge_table.py.
PW_CELLS ?= terminus:5:route:6117
PW_ARMS ?= main: chain:--giveway-chain
PW_DIR ?= $(BUILD_DIR)/manoeuvre/probe-wedge
PW_JOBS ?= 4
.PHONY: manoeuvre-probe-wedge
manoeuvre-probe-wedge: import ## manoeuvre (R39, M1 G5): orders-probe cells (PW_CELLS map:squads:route:seed) x PW_ARMS under probe_wedge.gd -> $(PW_DIR)/*.log + the partner table
	@rm -rf $(PW_DIR) && mkdir -p $(PW_DIR)
	@echo ">> manoeuvre-probe-wedge on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off)"
	@for cell in $(PW_CELLS); do for arm in $(PW_ARMS); do echo "$$(echo $$cell | tr ':' ' ') $$arm"; done; done | xargs -P $(PW_JOBS) -L 1 sh -c \
		'name=$${4%%:*}; flags=$$(echo "$${4#*:}" | tr "," " "); \
		timeout 600 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/manoeuvre/probe_wedge.gd -- --arena=$$0 --seed=$$3 \
			--probe-squads=$$1 --probe-route=$$2 --probe-arm=$$name $$flags > $(PW_DIR)/$$0-$$1-$$2-$$name-s$$3.log 2>&1 || true'
	@grep -L '^ORDERS_PROBE {' $(PW_DIR)/*.log | sed 's/^/MISSING (no ORDERS_PROBE line): /' || true
	$(PYTHON) tests/manoeuvre/probe_wedge_table.py $(PW_DIR)

# ---- round 41 (Q1): the jam census on the group-order workload -------------------------------------------------------------
# Orders' O1 group-order probe (tests/orders_probe_group.gd: his five full squads, 25 crews, one click across the map) on PJ_CELLS
# (map:route:seed) x PJ_ARMS (name:flags) x PJ_HEADINGS (crew: every hull a seeded random heading before the click; formed: the
# control), under tests/manoeuvre/probe_jam.gd (the probe unchanged + every stretch a crew is slowed by a friend: who the blocker
# was, what it was doing, how long, what the asker did, and when the blocker cleared the asker's frozen lane) -> JAM_EP / JAM_RUN
# rows in $(PJ_DIR)/*.log, then tests/manoeuvre/probe_jam_table.py. Measurement only; a judged read is `native manoeuvre-probe-jam`
# (remote_builds.md: a probe target runs whatever library the folder last built).
PJ_CELLS ?= terminus:click:7001 locks:click:7001 crossing:click:7001
PJ_ARMS ?= main:
PJ_HEADINGS ?= formed crew
PJ_TARGET ?= across
PJ_DIR ?= $(BUILD_DIR)/manoeuvre/probe-jam
PJ_JOBS ?= 4
.PHONY: manoeuvre-probe-jam
manoeuvre-probe-jam: import ## manoeuvre Q1 (round 41): the jam census on his group order (orders' O1 probe), PJ_CELLS x PJ_ARMS x PJ_HEADINGS -> $(PJ_DIR)/*.log + the table
	@rm -rf $(PJ_DIR) && mkdir -p $(PJ_DIR)
	@echo ">> manoeuvre-probe-jam on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | cells '$(PJ_CELLS)' arms '$(PJ_ARMS)' headings '$(PJ_HEADINGS)' target $(PJ_TARGET) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for cell in $(PJ_CELLS); do for arm in $(PJ_ARMS); do for h in $(PJ_HEADINGS); do echo "$$(echo $$cell | tr ':' ' ') $$arm $$h"; done; done; done | xargs -P $(PJ_JOBS) -L 1 sh -c \
		'name=$${3%%:*}; flags=$$(echo "$${3#*:}" | tr "," " "); \
		timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/manoeuvre/probe_jam.gd -- --arena=$$0 --seed=$$2 \
			--probe-squads=5 --probe-army=res://tests/control/orders_probe_group_5.json --probe-target=$(PJ_TARGET) --probe-headings=$$4 \
			--probe-route=$$1 --probe-arm=$$name $$flags > $(PJ_DIR)/$$0-$$1-$$name-$$4-s$$2.log 2>&1 || true'
	@grep -L '^JAM_RUN' $(PJ_DIR)/*.log | sed 's/^/MISSING (no JAM_RUN line): /' || true
	$(PYTHON) tests/manoeuvre/probe_jam_table.py $(PJ_DIR)

# ---- round 43 (S1): rebuild a recorded match's START and trace its crews per tick -------------------------------------
# tests/manoeuvre/start_trace.gd on a recording (ST_RECORDING: a plain .jsonl; zcat a references/*.jsonl.gz into build/ first),
# the arena and seed on the REAL command line (Arena._ready reads OS args, not Main.next_flags: R43.1), the laptop's squad
# cap (ST_SQUAD_CAP=4 reproduces his 4 x 5 army), the squads traced (ST_CREWS), ST_SECONDS, ST_FLAGS for any game switch.
# Rows START_ROW / START_SEAT / START_YIELD / START_GAP -> ST_LOG; tests/manoeuvre/start_table.py prints the per-crew table
# (--crew=Guns_3 for one crew's timeline). On his Locks 56416 recording the rebuild is within 0.1 m of his census for 10 s.
ST_RECORDING ?=  # a recording's .jsonl; empty = his first-order shape synthesised from the deploy (Bar S's workload)
ST_ARENA ?= locks
ST_SEED ?= 56416
ST_SQUAD_CAP ?= 4
ST_CREWS ?= Guns,Hunters
ST_SECONDS ?= 20
ST_FLAGS ?=
ST_LOG ?= $(BUILD_DIR)/manoeuvre/start_trace.log
.PHONY: manoeuvre-start-trace
manoeuvre-start-trace: import ## manoeuvre S1 (round 43): rebuild ST_RECORDING's start (ST_ARENA, ST_SEED, ST_SQUAD_CAP) and trace ST_CREWS per tick for ST_SECONDS -> ST_LOG + the per-crew table
	@mkdir -p $(dir $(ST_LOG))
	@echo ">> manoeuvre-start-trace on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | $(ST_RECORDING) $(ST_ARENA) $(ST_SEED) cap $(ST_SQUAD_CAP) crews $(ST_CREWS) | flags '$(ST_FLAGS)'"
	@timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/manoeuvre/start_trace.gd -- \
		$(if $(strip $(ST_RECORDING)),--orders=$(strip $(ST_RECORDING))) --arena=$(ST_ARENA) --seed=$(ST_SEED) --squad-cap=$(ST_SQUAD_CAP) $(if $(strip $(ST_CREWS)),--crews=$(strip $(ST_CREWS))) \
		--trace-seconds=$(ST_SECONDS) --mute $(ST_FLAGS) > $(ST_LOG) 2>&1 || true
	@grep -E '^START_(SETUP|DONE)' $(ST_LOG) || true
	@$(PYTHON) tests/manoeuvre/start_table.py $(ST_LOG)

# ---- round 43 (Bar S, C43.5): his first-order shape, BS_CELLS (arena:seed) x BS_ARMS (name:flags) --------------------------------
# tests/manoeuvre/start_trace.gd with no --orders synthesises his first order from the deploy (the header of that file), his
# laptop's squad cap, the Gangs (BS_PLAYER) against BS_ENEMY; one START_RUN row per log -> tests/manoeuvre/s_judge.py. Arms are
# switch sets: base = --shape-latch=off (the seat bound is off by default); bound = --seat-bound=on,--shape-latch=off; latch = (none);
# both = --seat-bound=on. A judged read is `native manoeuvre-bar-s` (the drive is twinned; neither rule touches Movement).
BS_CELLS ?= locks:7001 terminus:7001 crossing:7001
BS_ARMS ?= base:--shape-latch=off both:--seat-bound=on
BS_PLAYER ?= gangs
BS_ENEMY ?= syndicate
BS_SECONDS ?= 20
BS_DIR ?= $(BUILD_DIR)/manoeuvre/bar-s
BS_JOBS ?= 4
.PHONY: manoeuvre-bar-s
manoeuvre-bar-s: import ## manoeuvre Bar S (round 43): his first-order shape on BS_CELLS x BS_ARMS -> $(BS_DIR)/*.log + s_judge (BS_PLAYER v BS_ENEMY, BS_SECONDS)
	@rm -rf $(BS_DIR) && mkdir -p $(BS_DIR)
	@echo ">> manoeuvre-bar-s on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | cells '$(BS_CELLS)' arms '$(BS_ARMS)' | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for cell in $(BS_CELLS); do for arm in $(BS_ARMS); do echo "$$(echo $$cell | tr ':' ' ') $$arm"; done; done | xargs -P $(BS_JOBS) -L 1 sh -c \
		'name=$${2%%:*}; flags=$$(echo "$${2#*:}" | tr "," " "); \
		timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/manoeuvre/start_trace.gd -- --arena=$$0 --seed=$$1 \
			--squad-cap=4 --player-faction=$(BS_PLAYER) --enemy-faction=$(BS_ENEMY) --trace-seconds=$(BS_SECONDS) --every=5 --mute \
			--probe-arm=$$name $$flags > $(BS_DIR)/$$0-$$name-s$$1.log 2>&1 || true'
	@grep -L '^START_RUN' $(BS_DIR)/*.log | sed 's/^/MISSING (no START_RUN line): /' || true
	$(PYTHON) tests/manoeuvre/s_judge.py $(BS_DIR) --base=base --arm=both --cells || true

# ---- round 44 (M2): his recorded start replayed IN A WINDOW and photographed (needs a display: make remote T=...) -----------------
# tests/manoeuvre/start_shot.gd: the faithful replay's setup with the RTS camera following SS_FOLLOW; a PNG per tick of SS_TICKS.
# SS_FLAGS = the arm, SS_NAME the file prefix -> build/manoeuvre/shots/<SS_NAME>-t<tick>.png (+ the run's log).
SS_RECORDING ?= _agents/streams/references/round43/playtest/2026-10-28T08-15-42-locks.jsonl
SS_TICKS ?= 30,60,90,120
SS_FOLLOW ?= Green_Guns_2
SS_FLAGS ?=
SS_NAME ?= base
SS_DIR ?= $(BUILD_DIR)/manoeuvre/shots
.PHONY: manoeuvre-start-shots
manoeuvre-start-shots: import ## manoeuvre M2: SS_RECORDING's start replayed in a window, the camera on SS_FOLLOW, a PNG at each tick of SS_TICKS (SS_FLAGS = the arm, SS_NAME) -> build/manoeuvre/shots/ (needs a display)
	@mkdir -p $(SS_DIR)
	@timeout 900 $(GODOT) --fixed-fps $(SIM_HZ) --resolution 1920x1080 --path . --script res://tests/manoeuvre/start_shot.gd -- \
		--orders=$(CURDIR)/$(SS_RECORDING) --shots=$(SS_TICKS) --follow=$(SS_FOLLOW) --out=$(CURDIR)/$(SS_DIR) --name=$(SS_NAME) --mute \
		$(SS_FLAGS) > $(SS_DIR)/$(SS_NAME).log 2>&1 || true
	@grep -E '^SHOT_' $(SS_DIR)/$(SS_NAME).log | cut -c1-200

# Round 44 (Bar B1): the staged nose-on corpus test runs only with NOSED_CORPUS=on (make test FILTER=nosed_corpus NOSED_CORPUS=on).
NOSED_CORPUS ?=
export NOSED_CORPUS
NOSED_GDSCRIPT ?=
export NOSED_GDSCRIPT
NOSED_SEEDS ?=
export NOSED_SEEDS
# Round 45 (M1, dev only): NOSED_POSES=13 (a comma list of dev poses) and NOSED_TRACE=on (the rig traced, NOSED_SETUP / NOSED_TICK rows).
NOSED_POSES ?=
export NOSED_POSES
NOSED_TRACE ?=
export NOSED_TRACE
NOSED_SETUP_ONLY ?=
export NOSED_SETUP_ONLY
# Round 45 (R45.4): NOSED_GUARD=on runs the six guard poses (round 44's mis-staged stagings kept: no back-up possible, ON no worse).
NOSED_GUARD ?=
export NOSED_GUARD
