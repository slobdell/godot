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
		$(if $(FIGHT_BUSY),--busy=$(FIGHT_BUSY)) $(NAV_FLAGS) 2>&1 | grep -E "NAV_FIGHT|SCRIPT ERROR|ERROR" || true

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

# ROT_CASES, not $(or $(ROT_CASES),a,b,c): make's `or` splits on commas, so that default was silently just "pivot".
ROT_CASES ?= pivot,car,wheel,truck

.PHONY: nav-rotation-numbers
nav-rotation-numbers: import ## nav: nav-rotation's measurements only, headless (seconds): NAV_ROTATION + NAV_ROTATION_INPLACE lines (ROT_CASES=pivot,car,wheel,truck)
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/rotation_capture.gd -- --no-frames \
		--cases=$(ROT_CASES) $(NAV_FLAGS) 2>&1 | grep -E "NAV_ROTATION|SCRIPT ERROR|ERROR" || true

# FIGHT_MAPS/FIGHT_BUSY_LEVELS, not ARENA/…: plain names collide with other mk files' globals (lesson 44).
# Round 9 CORRECTION: this is NOT "every map --arena=random can pick", which is what this line used to claim and what
# nav then wrote into a pre-registration. `--arena=random` deals from `Arena.ROTATION` = yard, pit, terminus
# (arena.gd:63, :613) -- THREE maps. This default holds two the player never sees (boulevard, boneyard) and omits one
# they do (terminus). It is left as-is deliberately: round 8's numbers were measured on this set and changing it
# silently would break every comparison against them. Pass FIGHT_MAPS explicitly for a rotation run:
#     make nav-fight-maps FIGHT_MAPS=rotation
#
# ROTATION is READ FROM THE CODE, never re-typed here: a second copy of the list is a second thing to drift, and the
# drift is exactly what went wrong. `FIGHT_MAPS=rotation` expands to it, and any run whose set is not a subset of it
# prints a loud line into its own output naming the strays.
#
# Deliberately a WARNING and not a refusal (the orchestrator asked for a refusal; this is nav's answer and the reason
# is on the record). Refusing would make round 8's numbers unreproducible -- they were measured on the default set --
# and would refuse the off-rotation runs that established A4 has no headroom on boulevard and boneyard, which is a
# real result. Silently re-defaulting to the rotation would break every comparison against round 8 instead. A line in
# the run's own log is what a pre-registration copies from, so that is where the correction belongs.
FIGHT_ROTATION := $(shell sed -n 's/^const ROTATION := \[\(.*\)\]/\1/p' game/arena/arena.gd | tr -d '"' | tr ',' ' ')
FIGHT_MAPS ?= yard boulevard pit boneyard
ifeq ($(strip $(FIGHT_MAPS)),rotation)
override FIGHT_MAPS := $(FIGHT_ROTATION)
endif
# Every map asked for that the game would never deal, and every map it deals that is not being run.
FIGHT_STRAYS := $(filter-out $(FIGHT_ROTATION),$(FIGHT_MAPS))
FIGHT_MISSING := $(filter-out $(FIGHT_MAPS),$(FIGHT_ROTATION))
FIGHT_BUSY_LEVELS ?= 0 4

.PHONY: nav-fight-maps
nav-fight-maps: import ## nav (round 8): nav-fight on each of FIGHT_MAPS (NOT the rotation -- see the note above the default) x scripted/busy player (FIGHT_BUSY_LEVELS seconds between re-orders; 0 = scripted), with arena's pre-registered stall counters -> build/nav-maps/*.log, one line per run naming the arena
	@echo ">> nav-fight-maps: maps [$(FIGHT_MAPS)]; Arena.ROTATION is [$(FIGHT_ROTATION)]"
ifneq ($(FIGHT_STRAYS),)
	@echo ">> nav-fight-maps: WARNING - [$(FIGHT_STRAYS)] are NOT in Arena.ROTATION, so --arena=random never deals them. A result on them is a result about a map the lead does not play."
endif
ifneq ($(FIGHT_MISSING),)
	@echo ">> nav-fight-maps: WARNING - [$(FIGHT_MISSING)] ARE in Arena.ROTATION and are NOT being run. Use FIGHT_MAPS=rotation for the set the game deals."
endif
	@rm -rf $(BUILD_DIR)/nav-maps && mkdir -p $(BUILD_DIR)/nav-maps
	@for map in $(FIGHT_MAPS); do for busy in $(FIGHT_BUSY_LEVELS); do echo "$$map:$$busy"; done; done | \
		xargs -P $(NAV_JOBS) -I{} sh -c 'map=$${1%%:*}; busy=$${1##*:}; \
			$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/fight_probe.gd -- \
				--arena=$$map --seed=$(or $(FIGHT_SEED),3) --time-limit=$(or $(NAV_TIME),120) --budget=$(or $(FIGHT_BUDGET),6500) --busy=$$busy $(if $(STALL_VERB),--stall-verb=$(STALL_VERB)) \
				$(if $(FIGHT_GREEN_FACTION),--green-faction=$(FIGHT_GREEN_FACTION)) $(if $(FIGHT_RUST_FACTION),--rust-faction=$(FIGHT_RUST_FACTION)) \
				$(if $(FIGHT_GREEN_ARMY),--green-army=$(FIGHT_GREEN_ARMY)) $(if $(FIGHT_RUST_ARMY),--rust-army=$(FIGHT_RUST_ARMY)) \
				$(if $(FIGHT_REQUIRE),--require=$(FIGHT_REQUIRE)) $(NAV_FLAGS) \
				> $(BUILD_DIR)/nav-maps/$$map-busy$$busy.log 2>&1; echo ">> nav-fight-maps: $$map busy=$$busy done"' _ {}
	@for f in $(BUILD_DIR)/nav-maps/*.log; do echo "$$(basename $$f .log) $$(grep -E '^NAV_FIGHT ' $$f | head -1 | cut -c1-40)"; done
	@! grep -l "control FAILED" $(BUILD_DIR)/nav-maps/*.log || { echo ">> nav-fight-maps: a run REFUSED (its control failed): no numbers from it"; exit 1; }

# Round 10 (nav item 2): the round's bar. One player squad ordered street to street across Terminus through control's
# Orders on the DEFAULT path (spawn -> ring road -> west street -> plaza -> far ring road), a mixed Condemned squad and
# a squad of War Rigs, each in its own process; WallContact counts every hull-wall contact by cause. DRIVE_SQUADS,
# DRIVE_ARENA, DRIVE_LEG_TIME (not ARENA/SQUADS: lesson 44's globals).
DRIVE_SQUADS ?= mixed rigs

.PHONY: nav-terminus-drive
nav-terminus-drive: import ## nav (round 10): the Terminus drive test -- a mixed squad and a War Rig squad driven street to street; wall contacts by cause, arrival per leg -> build/nav-drive/*.log, NAV_DRIVE lines (DRIVE_SQUADS="mixed rigs" DRIVE_ARENA=terminus DRIVE_LEG_TIME=90)
	@rm -rf $(BUILD_DIR)/nav-drive && mkdir -p $(BUILD_DIR)/nav-drive
	@for squad in $(DRIVE_SQUADS); do echo $$squad; done | xargs -P $(NAV_JOBS) -I{} sh -c '\
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/terminus_drive.gd -- \
			--squad={} --arena=$(or $(DRIVE_ARENA),terminus) --leg-time=$(or $(DRIVE_LEG_TIME),90) $(NAV_FLAGS) \
			> $(BUILD_DIR)/nav-drive/{}.log 2>&1; echo ">> nav-terminus-drive: {} done"'
	@for f in $(BUILD_DIR)/nav-drive/*.log; do grep -E "^NAV_DRIVE_CONTROL|^NAV_DRIVE_LEG|SCRIPT ERROR|control FAILED" $$f || true; \
		grep -E "^NAV_DRIVE " $$f | cut -c1-600 || echo ">> nav-terminus-drive: $$f has NO NAV_DRIVE line (the run did not finish)"; done
	@! grep -l "control FAILED\|SCRIPT ERROR" $(BUILD_DIR)/nav-drive/*.log || { echo ">> nav-terminus-drive: a run REFUSED or errored: no numbers from it"; exit 1; }

# Round 10: which nav arm moves the sim baseline. The sim-baseline match (SIM_HASH_READ's exact command) read once per
# --nav-off arm in SIM_ARMS (a comma list per arm; "none" = the default path), so a pre-registered MOVED names its cause.
SIM_ARMS ?= none notready press,inflate,nosestop

.PHONY: nav-sim-arms
nav-sim-arms: import ## nav: the sim-baseline match's state hash under each --nav-off arm in SIM_ARMS (attributes a baseline move to one mechanism)
	@for arm in $(SIM_ARMS); do flags=""; [ "$$arm" = none ] || flags="--nav-off=$$arm"; \
		hash=$$($(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --green-doctrine=res://doctrines/sim_baseline_green.json \
			--rust-doctrine=res://doctrines/sim_baseline_rust.json --time-limit=40 --seed=3 $$flags 2>/dev/null | grep MATCH_RESULT | \
			$(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"); \
		echo "NAV_SIM_ARM off=$$arm hash=$$hash"; done
	@echo "NAV_SIM_ARM recorded: $$(grep "glibc-$$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)" tests/baselines/sim_state_hash.txt)"

# Round 10 item 4's falsifier (and any nav arm's): squad's defile probe (tests/tactics/defile_probe.gd, read-only here)
# over PAIRED seeds, both arms on the same seeds: "off" = the default path, "on" = --nav-off=$(AB_ARM) (an opt-in row
# turns ON by its name). Prints one DEFILE_PROBE line per (arm, locomotion, seed) -> build/nav-defile/*.log.
DEFILE_SEEDS ?= 1 2 3 4 5 6 7 8
AB_ARM ?= oriented

.PHONY: nav-defile-ab
nav-defile-ab: import ## nav: squad's defile probe over DEFILE_SEEDS x ARM=wheeled,tracked x {default, --nav-off=$(AB_ARM)} (paired seeds) -> build/nav-defile/, DEFILE_PROBE lines
	@rm -rf $(BUILD_DIR)/nav-defile && mkdir -p $(BUILD_DIR)/nav-defile
	@for seed in $(DEFILE_SEEDS); do for loco in wheeled tracked; do for arm in off on; do echo "$$seed:$$loco:$$arm"; done; done; done | \
		xargs -P $(NAV_JOBS) -I{} sh -c 'set -- $$(echo {} | tr ":" " "); flags=""; [ "$$3" = on ] && flags="--nav-off=$(AB_ARM)"; \
			$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/defile_arm_probe.gd -- \
				--arm=$$2 --deform=on --seed=$$1 --seconds=$(or $(DEFILE_SECONDS),40) --formation=wedge --tube=off $$flags \
				> $(BUILD_DIR)/nav-defile/$$3-$$2-s$$1.log 2>&1'
	@for f in $(BUILD_DIR)/nav-defile/*.log; do echo "$$(basename $$f .log) $$(grep -E '^DEFILE_ARM' $$f | head -1)"; done
	@! grep -l "SCRIPT ERROR" $(BUILD_DIR)/nav-defile/*.log || { echo ">> nav-defile-ab: a run errored"; exit 1; }

# Round 10: an opt-in nav row judged by A12 and nothing else (legibility.md §7). nav-fight on each map of A12_MAPS
# (default Arena.ROTATION) x {default, --nav-off=$(A12_ARM) (the row ON)} at FIGHT_SEED, each fight's trajectory
# logged, then metrics pooled per arm over attack-move ticks of team 0. A6's pre-registration (research_catalog):
# off-corridor 30-36 % -> < 10 % without a fall in exchange ratio; the leash clamp's: formation residual and
# off-corridor share not worse, active fraction beside them. Logs are ~100 MB each: build/nav-a6/, summarised.
A12_ARM ?= a6
A12_MAPS ?= $(FIGHT_ROTATION)
comma := ,
# Flags BOTH arms carry (a row that only runs under another, like A6 at A7's level 3: A12_BASE=a7). Empty = default.
A12_BASE ?=
.PHONY: nav-a6-ab
nav-a6-ab: import ## nav: an opt-in row through A12 -- nav-fight x A12_MAPS x {default, --nav-off=A12_ARM} with trajectories, pooled per arm (A12_ARM=a6|leash FIGHT_SEED=3 NAV_TIME=120)
	@rm -rf $(BUILD_DIR)/nav-a6 && mkdir -p $(BUILD_DIR)/nav-a6
	@for map in $(A12_MAPS); do for arm in off on; do echo "$$map:$$arm"; done; done | \
		xargs -P $(NAV_JOBS) -I{} sh -c 'map=$${1%%:*}; arm=$${1##*:}; flags="$(if $(A12_BASE),--nav-off=$(A12_BASE))"; \
			[ "$$arm" = on ] && flags="--nav-off=$(if $(A12_BASE),$(A12_BASE)$(comma))$(A12_ARM)"; \
			$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/fight_probe.gd -- \
				--arena=$$map --seed=$(or $(FIGHT_SEED),3) --time-limit=$(or $(NAV_TIME),120) --budget=$(or $(FIGHT_BUDGET),6500) \
				--trajectory=$(CURDIR)/$(BUILD_DIR)/nav-a6/$$map-$$arm.jsonl $$flags \
				> $(BUILD_DIR)/nav-a6/$$map-$$arm.log 2>&1; echo ">> nav-a6-ab: $$map $$arm done"' _ {}
	@for arm in off on; do echo ">> nav-a6-ab: A12 pooled, arm $$arm (on = $(A12_ARM) ON)"; \
		$(PYTHON) tools/metrics/run_metrics.py "$(BUILD_DIR)/nav-a6/*-$$arm.jsonl" $(if $(word 2,$(A12_MAPS)),--pool) --order-verb attack_move --team 0 \
			--json $(BUILD_DIR)/nav-a6/metrics-$$arm.json | tail -25; done
	@for f in $(BUILD_DIR)/nav-a6/*.log; do echo "$$(basename $$f .log) $$(grep -E '^NAV_FIGHT_ARM' $$f | head -1 | cut -c1-200)"; done
