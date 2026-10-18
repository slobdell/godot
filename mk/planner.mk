# ---- planner (round 30): a local motion planner for long wheeled hulls, isolated this round (C30.4) -----------------
# Owner: the planner stream (_agents/streams/archive/round32/planner.md). Nothing here is reached in play. Every Godot run goes to
# builder0 (`make remote LIGHT=1 T=planner-...`: one process, the light lane, one at a time).

# P0 reproductions on main's code, each the exact command the problem statement cites
# (_agents/streams/references/round30/planner/problem.md). Logs: build/planner/.

# The wedge (round 29 M4's trace): the War Rig squad driven across the Terminus, seed 9, the GDScript plant and brains
# (--brains-off=native), every rig's drive traced per tick (DRIVE_TRACE: tank.gd prints wanted v moved) and the turn
# census logged. A pinned rig reads a speed with no displacement.
PLANNER_WEDGE_SEED ?= 9
PLANNER_WEDGE_TRACE ?= Green_S0_1,Green_S0_2,Green_S0_3,Green_S0_4
.PHONY: planner-repro-wedge
planner-repro-wedge: import ## planner P0: the wedged rig reproduced (Terminus rigs drive, seed PLANNER_WEDGE_SEED, DRIVE_TRACE on every rig, --turn-log) -> build/planner/wedge-<seed>.log
	@mkdir -p $(BUILD_DIR)/planner
	@echo ">> planner-repro-wedge on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | seed $(PLANNER_WEDGE_SEED)"
	@DRIVE_TRACE=$(PLANNER_WEDGE_TRACE) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/terminus_drive.gd -- \
		--squad=rigs --seed=$(PLANNER_WEDGE_SEED) --arena=terminus --leg-time=90 --turn-log --brains-off=native $(PLANNER_FLAGS) \
		> $(BUILD_DIR)/planner/wedge-$(PLANNER_WEDGE_SEED).log 2>&1 || true
	@grep -E "^NAV_DRIVE_LEG|^NAV_DRIVE |SCRIPT ERROR|control FAILED" $(BUILD_DIR)/planner/wedge-$(PLANNER_WEDGE_SEED).log | cut -c1-400 || true
	@$(PYTHON) tests/planner/wedge_table.py $(BUILD_DIR)/planner/wedge-$(PLANNER_WEDGE_SEED).log || true

# The creep (round 29 M2's base census): the mixed squad across the Terminus, seed PLANNER_CREEP_SEED, every turn
# episode logged with its cause (creep / kturn / circle / press / ...) and what was in the way.
PLANNER_CREEP_SEED ?= 1
.PHONY: planner-repro-creep
planner-repro-creep: import ## planner P0: the creep reproduced (Terminus mixed drive, seed PLANNER_CREEP_SEED, --turn-log) -> build/planner/creep-<seed>.log + the census table
	@mkdir -p $(BUILD_DIR)/planner
	@echo ">> planner-repro-creep on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | seed $(PLANNER_CREEP_SEED)"
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/terminus_drive.gd -- \
		--squad=mixed --seed=$(PLANNER_CREEP_SEED) --arena=terminus --leg-time=90 --turn-log --brains-off=native $(PLANNER_FLAGS) \
		> $(BUILD_DIR)/planner/creep-$(PLANNER_CREEP_SEED).log 2>&1 || true
	@grep -E "^NAV_DRIVE_LEG|^NAV_DRIVE |SCRIPT ERROR|control FAILED" $(BUILD_DIR)/planner/creep-$(PLANNER_CREEP_SEED).log | cut -c1-400 || true
	@$(PYTHON) tests/manoeuvre/census_table.py $(BUILD_DIR)/planner/creep-$(PLANNER_CREEP_SEED).log || true

# The boxed-in face (F3) and the arrival gate (F4) on main's code, in a TacticsLab (tests/planner/boxed_face_probe.gd).
PLANNER_PROBE_CASE ?= all
.PHONY: planner-repro-face
planner-repro-face: import ## planner P0: four War Rigs in a line abreast each told to face east, and a car's 180-degree arrival through today's gate (PLANNER_PROBE_CASE=face|gate|all, PLANNER_FLAGS) -> build/planner/face.log
	@mkdir -p $(BUILD_DIR)/planner
	@echo ">> planner-repro-face on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | case $(PLANNER_PROBE_CASE)"
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/planner/boxed_face_probe.gd -- \
		--case=$(PLANNER_PROBE_CASE) --brains-off=native $(PLANNER_FLAGS) > $(BUILD_DIR)/planner/face.log 2>&1 || true
	@grep -E "PLANNER_PROBE_DONE|SCRIPT ERROR" $(BUILD_DIR)/planner/face.log | cut -c1-900 || true

# P3: the lab scene (needs a display: builder0's). One real hull on a real arena cut, the planner's legs driven by
# PlannerExecutor beside the same hull under today's code; frames + PLANNER_LAB rows -> build/planner-lab/.
# PLANNER_FIXTURES=turnround,slot180,tjunction,yardcorner PLANNER_ARMS=planner,today PLANNER_SECONDS=60
# MOVIE=path.mp4 records the whole run (renders slower than real time; ffmpeg makes the .mp4 from Godot's .avi).
PLANNER_LAB_DIR ?= $(BUILD_DIR)/planner-lab
# Defaults with ?=, not $(or ...): make's `or` splits on the commas and keeps only the first fixture (the first run).
PLANNER_FIXTURES ?= turnround,slot180,tjunction
PLANNER_ARMS ?= planner,today
PLANNER_SECONDS ?= 60
.PHONY: planner-lab
planner-lab: import ## planner P3: the planner v today's drive on real arena cuts, frames + rows -> build/planner-lab/ (needs a display: make remote LIGHT=1 T=planner-lab; PLANNER_FIXTURES, PLANNER_ARMS, PLANNER_SECONDS, MOVIE=out.mp4)
	@rm -rf $(PLANNER_LAB_DIR) && mkdir -p $(PLANNER_LAB_DIR)
	@echo ">> planner-lab on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown})"
	@movie="$(MOVIE)"; record=""; avi=""; if [ -n "$$movie" ]; then case "$$movie" in /*) ;; *) movie="$(CURDIR)/$$movie" ;; esac; \
		avi="$${movie%.*}.avi"; record="--write-movie $$avi"; fi; \
	timeout 1500 $(GODOT) --path . --fixed-fps $(SIM_HZ) --resolution 1280x720 $$record --script res://tests/planner/planner_lab.gd -- \
		--fixtures=$(PLANNER_FIXTURES) --arms=$(PLANNER_ARMS) \
		--seconds=$(PLANNER_SECONDS) --out=res://$(PLANNER_LAB_DIR) $(if $(MOVIE),--movie=1) --brains-off=native $(PLANNER_FLAGS) \
		> $(PLANNER_LAB_DIR)/run.log 2>&1 || true; \
	grep -E "PLANNER_LAB |PLANNER_LAB_PLAN|PLANNER_LAB_SHOT|SCRIPT ERROR" $(PLANNER_LAB_DIR)/run.log | cut -c1-600 || true; \
	grep -q PLANNER_LAB_DONE $(PLANNER_LAB_DIR)/run.log || echo ">> planner-lab: did not finish"; \
	if [ -n "$$movie" ] && command -v ffmpeg >/dev/null && [ -f "$$avi" ]; then ffmpeg -loglevel error -y -i "$$avi" -c:v libx264 -preset slow -crf 18 \
		-pix_fmt yuv420p -movflags +faststart "$$movie" && rm -f "$$avi" && echo "PLANNER_LAB_MOVIE $$movie"; elif [ -n "$$avi" ]; then echo "PLANNER_LAB_MOVIE $$avi"; fi

# ---- round 31 (CP-P0 / P6): the C++ twin and the plan-event census ----------------------------------------------------
# The twin test alone, the library built first, pinned when asked (PLANNER_CPUS=0-3 on builder0: the price line is a
# builder0 number, _agents/remote_builds.md "builder0 is two machines"). `make remote T="planner-twin PLANNER_CPUS=0-3"`.
PLANNER_CPUS ?=
.PHONY: planner-twin
planner-twin: native import ## planner CP-P0: tests/test_native_planner.gd alone (every fixture both ways, the table, the slice; us a plan each way), pinned with PLANNER_CPUS=0-3
	@mkdir -p $(BUILD_DIR)/planner
	@echo ">> planner-twin on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | cpus $(or $(PLANNER_CPUS),any) | load $$(cut -d' ' -f1 /proc/loadavg)"
	@PLANNER_TWIN_ALL=1 $(if $(PLANNER_CPUS),taskset -c $(PLANNER_CPUS)) $(GODOT) --headless --path . --script res://tests/run_tests.gd -- '--filter=native_planner' \
		> $(BUILD_DIR)/planner/twin.log 2>&1; s=$$?; \
	grep -E "NATIVE_PLANNER |NATIVE_PLANNER_SLICE|MEASURE|PASS|FAIL|passed|SCRIPT ERROR" $(BUILD_DIR)/planner/twin.log | cut -c1-300; \
	echo ">> planner-twin: runner exited $$s (build/planner/twin.log)"; exit $$s

# P6's census: plan REQUESTS a tick in a real fight on the GDScript drive (tests/planner/plan_census.gd): his Sumps at
# PLANNER_CENSUS_N a side with leaders (perf_armies), PLANNER_CENSUS_SEEDS, PLANNER_CENSUS_TIME s each; one
# PLANNER_CENSUS line per run -> build/planner/census-<seed>.log. One process at a time (the light lane fits).
PLANNER_CENSUS_N ?= 25
PLANNER_CENSUS_SEEDS ?= 92721 31337
PLANNER_CENSUS_TIME ?= 120
PLANNER_CENSUS_ARENA ?= sumps
# PLANNER_CENSUS_PROBE=30: every 30 ticks plan one fixture inside the fight and keep its us (the price under load; the
# fight itself stays on --brains-off=native, so the probe says which path it took: with native off it is the GDScript's).
PLANNER_CENSUS_PROBE ?= 0
.PHONY: planner-census
planner-census: native import ## planner P6: plan requests a tick in a PLANNER_CENSUS_ARENA fight at PLANNER_CENSUS_N a side, PLANNER_CENSUS_SEEDS, PLANNER_FLAGS=--brains-off=native for the GDScript drive -> build/planner/census-<seed>.log
	@mkdir -p $(BUILD_DIR)/planner $(BUILD_DIR)/perf-armies
	@$(PYTHON) tools/perf_armies.py size $(PLANNER_CENSUS_N) $(BUILD_DIR)/perf-armies
	@for seed in $(PLANNER_CENSUS_SEEDS); do log=$(BUILD_DIR)/planner/census-$$seed.log; \
		echo ">> planner-census: $(PLANNER_CENSUS_N) a side, seed $$seed on $$(hostname) at $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-?})"; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/planner/plan_census.gd -- --match --elimination --control \
			--green-doctrine=res://$(BUILD_DIR)/perf-armies/green_$(PLANNER_CENSUS_N).json \
			--rust-doctrine=res://$(BUILD_DIR)/perf-armies/rust_$(PLANNER_CENSUS_N).json --budget=100000 \
			--time-limit=$(PLANNER_CENSUS_TIME) --seed=$$seed --arena=$(PLANNER_CENSUS_ARENA) --green-elements --rust-elements \
			--plan-probe=$(PLANNER_CENSUS_PROBE) $(PLANNER_FLAGS) > $$log 2>&1 || true; \
		grep -h "^PLANNER_CENSUS" $$log | cut -c1-600 || { echo "   no PLANNER_CENSUS line: see $$log"; tail -3 $$log; }; \
	done

# Round 31 (planner CP-P1, bar line (a)): the judged Terminus series. nav-terminus-drive over PLANNER_SERIES_SEEDS x
# PLANNER_SERIES_SQUADS in TWO arms on the GDScript drive: base = `--brains-off=native_drive` (today's drive, the C++
# planner idle), candidate = the same + `--nav-off=planner` (the seam ON). Both arms one build, the same seeds; read by
# tests/planner/series_verdict.py as the bar is written (paired arrivals <= 1.645 se, contact-ticks reported, the
# seam's per-run report). Heavy (NAV_JOBS runs at once): make remote T="planner-series". The seeds are the bar's
# FRESH ones (133-145); tuning never touches them.
PLANNER_SERIES_SEEDS ?= 133 134 135 136 137 138 139 140 141 142 143 144 145
# Round 31 (the orchestrator's ruling on the first judged series, 2026-10-15 ~09:30 PDT): 133-145 became the DIAGNOSIS
# set; the second (last) judged series runs on these FRESH seeds -- `make planner-series-fresh`.
PLANNER_SERIES_FRESH_SEEDS ?= 172 173 174 175 176 177 178 179 180 181 182 183 184
PLANNER_SERIES_SQUADS ?= mixed rigs
PLANNER_SERIES_DIR := $(BUILD_DIR)/planner-series
# Each arm's flags (round 31's: the GDScript drive, the candidate with the seam switched -- note PLANNER_DEFAULT is true
# since CP-P1 shipped, so on today's tree that flag turns the seam OFF). Round 32's queue series: base "" (FIFO, the
# native drive) v candidate "--planner-queue=shared" (`make planner-series-queue`).
PLANNER_SERIES_BASE_FLAGS ?= --brains-off=native_drive
PLANNER_SERIES_CAND_FLAGS ?= --brains-off=native_drive --nav-off=planner
# Round 33 overnight: `both` when the seam runs in BOTH arms (the switch under test is the queue or the face keep), so
# series_verdict reports the base's seam instead of refusing on it. Empty = round 31's guard (the base never seams).
PLANNER_SERIES_SEAM ?=

.PHONY: planner-series
planner-series: native import ## planner CP-P1: the judged Terminus series, base v the seam ON over PLANNER_SERIES_SEEDS x PLANNER_SERIES_SQUADS, read by series_verdict.py -> build/planner-series/
	@rm -rf $(PLANNER_SERIES_DIR) && mkdir -p $(PLANNER_SERIES_DIR)
	@echo ">> planner-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | seeds $(PLANNER_SERIES_SEEDS) | squads $(PLANNER_SERIES_SQUADS)"
	@for arm in base candidate; do flags="$(PLANNER_SERIES_BASE_FLAGS)"; [ "$$arm" = base ] || flags="$(PLANNER_SERIES_CAND_FLAGS)"; \
		echo ">> planner-series: arm $$arm ($$flags)"; \
		$(MAKE) --no-print-directory nav-terminus-drive DRIVE_SQUADS="$(PLANNER_SERIES_SQUADS)" DRIVE_SEEDS="$(PLANNER_SERIES_SEEDS)" \
			NAV_FLAGS="$$flags" > $(PLANNER_SERIES_DIR)/$$arm.out 2>&1 || { tail -20 $(PLANNER_SERIES_DIR)/$$arm.out; echo ">> planner-series: arm $$arm REFUSED"; exit 1; }; \
		mv $(BUILD_DIR)/nav-drive $(PLANNER_SERIES_DIR)/$$arm; done
	@$(PYTHON) tests/planner/series_verdict.py base=$(PLANNER_SERIES_DIR)/base candidate=$(PLANNER_SERIES_DIR)/candidate $(if $(PLANNER_SERIES_SEAM),seam=$(PLANNER_SERIES_SEAM)) | tee $(PLANNER_SERIES_DIR)/verdict.txt

# Round 31 (planner CP-P1, bar lines (c)-(e)): the judged chain's other stages on manoeuvre's / tactics' targets with
# the bar's two arms, ONE arm a call (lesson 311). PLANNER_JUDGE_ARM = base | candidate: both arms the GDScript drive
# (--brains-off=native_drive) with the C++ planner on; the candidate adds --nav-off=planner (the seam ON). The seeds
# are the bar's FRESH ones (hull-rest 60-65, fights 181-204); tuning never touches them. Heavy: make remote T=...
PLANNER_JUDGE_ARM ?= base
PLANNER_JUDGE_FLAGS = --brains-off=native_drive$(if $(filter candidate,$(PLANNER_JUDGE_ARM)), --nav-off=planner)
PLANNER_JUDGE_DIR := $(BUILD_DIR)/planner-judge
PLANNER_HULL_SEEDS ?= 60 61 62 63 64 65
PLANNER_FIGHT_SEEDS ?= 181 182 183 184 185 186 187 188 189 190 191 192 193 194 195 196 197 198 199 200 201 202 203 204

.PHONY: planner-judge-hull-rest
planner-judge-hull-rest: native import ## planner CP-P1 (d): manoeuvre-hull-rest, PLANNER_JUDGE_ARM's two arms (drawn + clicked) on PLANNER_HULL_SEEDS; both arms called = the A/B tables
	@echo ">> planner-judge-hull-rest on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | arm $(PLANNER_JUDGE_ARM)"
	@$(MAKE) --no-print-directory manoeuvre-hull-rest M1_ARMS="$(if $(filter candidate,$(PLANNER_JUDGE_ARM)),new_drawn new_clicked,base_drawn base_clicked)" \
		M1_BASE_OFF= M1_NEW_OFF=planner M1_FLAGS="--turn-states --brains-off=native_drive" HULL_SEEDS="$(PLANNER_HULL_SEEDS)"

.PHONY: planner-series-fresh
planner-series-fresh: ## planner CP-P1: the second judged series on the FRESH seeds (PLANNER_SERIES_FRESH_SEEDS), the first's seeds being the diagnosis set
	@$(MAKE) --no-print-directory planner-series PLANNER_SERIES_SEEDS="$(PLANNER_SERIES_FRESH_SEEDS)"

.PHONY: planner-judge-fights
planner-judge-fights: native import ## planner CP-P1 (e): manoeuvre-fights on PLANNER_FIGHT_SEEDS for PLANNER_JUDGE_ARM -> build/planner-judge/fights-<arm>; both arms present = fight_table.py base v candidate
	@mkdir -p $(PLANNER_JUDGE_DIR)
	@echo ">> planner-judge-fights on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | arm $(PLANNER_JUDGE_ARM) ($(PLANNER_JUDGE_FLAGS))"
	@$(MAKE) --no-print-directory manoeuvre-fights FIGHT_SEEDS="$(PLANNER_FIGHT_SEEDS)" NAV_FLAGS="$(PLANNER_JUDGE_FLAGS)"
	@rm -rf $(PLANNER_JUDGE_DIR)/fights-$(PLANNER_JUDGE_ARM) && mv $(BUILD_DIR)/manoeuvre/fights $(PLANNER_JUDGE_DIR)/fights-$(PLANNER_JUDGE_ARM)
	@if [ -d $(PLANNER_JUDGE_DIR)/fights-base ] && [ -d $(PLANNER_JUDGE_DIR)/fights-candidate ]; then \
		$(PYTHON) tests/manoeuvre/fight_table.py $(PLANNER_JUDGE_DIR)/fights-base $(PLANNER_JUDGE_DIR)/fights-candidate | tee $(PLANNER_JUDGE_DIR)/fights-table.txt; fi

.PHONY: planner-judge-bridge
planner-judge-bridge: native import ## planner CP-P1 (e): bridge-pooled (18 runs, deterministic row) for PLANNER_JUDGE_ARM
	@echo ">> planner-judge-bridge | arm $(PLANNER_JUDGE_ARM) ($(PLANNER_JUDGE_FLAGS))"
	@$(MAKE) --no-print-directory bridge-pooled BRIDGE_FLAGS="$(PLANNER_JUDGE_FLAGS)"

.PHONY: planner-judge-cp2
planner-judge-cp2: native import ## planner CP-P1 (c): scenario_cp2 (the scout's orbit, a no-change guard) for PLANNER_JUDGE_ARM
	@echo ">> planner-judge-cp2 | arm $(PLANNER_JUDGE_ARM) ($(PLANNER_JUDGE_FLAGS))"
	@$(MAKE) --no-print-directory ai-scenarios FILTER=scenario_cp2 AI_SCEN_FLAGS="$(PLANNER_JUDGE_FLAGS)"

# Round 31 (CP-P1's diagnosis set, the orchestrator's ruling on the first judged series): ONE Terminus drive run of the
# series' recipe with one hull traced -- the drive script's `--trace=<unit>` (its driving twice a second) and the
# census's `--turn-trace=<unit>` (the seam's own lines: taken, planned, released, aborted). Light lane.
PLANNER_TRACE_SEED ?= 134
PLANNER_TRACE_SQUAD ?= rigs
PLANNER_TRACE_UNIT ?= Green_S0_4
PLANNER_TRACE_ARM ?= candidate
PLANNER_TRACE_DIR := $(BUILD_DIR)/planner-trace
.PHONY: planner-trace-drive
planner-trace-drive: native import ## planner CP-P1 diagnosis: the series' drive, one seed, one hull traced (PLANNER_TRACE_SEED/SQUAD/UNIT/ARM) -> build/planner-trace/<arm>-<squad>-<seed>.log
	@mkdir -p $(PLANNER_TRACE_DIR)
	@echo ">> planner-trace-drive on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | $(PLANNER_TRACE_ARM) $(PLANNER_TRACE_SQUAD)-$(PLANNER_TRACE_SEED) trace $(PLANNER_TRACE_UNIT)"
	@flags="--brains-off=native_drive --trace=$(PLANNER_TRACE_UNIT) --turn-trace=$(PLANNER_TRACE_UNIT)"; \
		[ "$(PLANNER_TRACE_ARM)" = base ] || flags="$$flags --nav-off=planner"; \
		$(MAKE) --no-print-directory nav-terminus-drive DRIVE_SQUADS="$(PLANNER_TRACE_SQUAD)" DRIVE_SEEDS="$(PLANNER_TRACE_SEED)" NAV_FLAGS="$$flags" NAV_JOBS=1
	@cp $(BUILD_DIR)/nav-drive/$(PLANNER_TRACE_SQUAD)-$(PLANNER_TRACE_SEED).log $(PLANNER_TRACE_DIR)/$(PLANNER_TRACE_ARM)-$(PLANNER_TRACE_SQUAD)-$(PLANNER_TRACE_SEED).log
	@grep -cE "^NAV_DRIVE_TRACE |^PLANNER_SEAM " $(PLANNER_TRACE_DIR)/$(PLANNER_TRACE_ARM)-$(PLANNER_TRACE_SQUAD)-$(PLANNER_TRACE_SEED).log | sed 's/^/>> planner-trace-drive: trace lines /'

# ---- round 32 (hand-over (3)): the gang-press queue, FIFO v --planner-queue=shared --------------------------------------
# One arm a call (PLANNER_QUEUE_ARM=base|candidate): manoeuvre-hull-rest's drawn + clicked arms on the gangs (the only
# faction with a hull the seam takes: the War Rig), the native drive both arms (the shipped default), the candidate
# with --planner-queue=shared, the base with --planner-queue=fifo (explicit: the arms read the same on either
# QUEUE_DEFAULT, so the series runs on the pair tree). Then tests/planner/queue_table.py over what is there (both arms called = the A/B).
PLANNER_QUEUE_SEEDS ?= 66 67 68 69 70 71
PLANNER_QUEUE_ARM ?= base
PLANNER_QUEUE_FACTIONS ?= gangs
.PHONY: planner-judge-queue
planner-judge-queue: native import ## planner round 32: hull-rest's gang arm, PLANNER_QUEUE_ARM=base (FIFO) | candidate (--planner-queue=shared) on PLANNER_QUEUE_SEEDS -> the queue table
	@echo ">> planner-judge-queue on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | arm $(PLANNER_QUEUE_ARM) | seeds $(PLANNER_QUEUE_SEEDS)"
	@$(MAKE) --no-print-directory manoeuvre-hull-rest M1_ARMS="$(if $(filter candidate,$(PLANNER_QUEUE_ARM)),new_drawn new_clicked,base_drawn base_clicked)" \
		M1_BASE_OFF= M1_NEW_OFF= M1_FLAGS="--turn-states $(if $(filter candidate,$(PLANNER_QUEUE_ARM)),--planner-queue=shared,--planner-queue=fifo)" \
		HULL_SEEDS="$(PLANNER_QUEUE_SEEDS)" HULL_FACTIONS="$(PLANNER_QUEUE_FACTIONS)"
	@$(PYTHON) tests/planner/queue_table.py $(BUILD_DIR)/manoeuvre/hull-rest

# The queue's Terminus rig series (the hold per rig event line): FIFO v shared on fresh seeds, the native drive both arms.
PLANNER_QUEUE_SERIES_SEEDS ?= 205 206 207 208 209 210 211 212 213 214 215 216 217
.PHONY: planner-series-queue
planner-series-queue: ## planner round 32: planner-series with base = the FIFO, candidate = --planner-queue=shared, on PLANNER_QUEUE_SERIES_SEEDS
	@$(MAKE) --no-print-directory planner-series PLANNER_SERIES_SEEDS="$(PLANNER_QUEUE_SERIES_SEEDS)" \
		PLANNER_SERIES_BASE_FLAGS=--planner-queue=fifo PLANNER_SERIES_CAND_FLAGS=--planner-queue=shared

# Round 32 (CP-Q's park, the round-33 hand-over): ONE hull-rest run on both queue arms with the per-unit trace
# (--turn-trace: MANOEUVRE_TRACE rows + the seam's PLANNER_SEAM lines for that hull). Light lane:
# make remote LIGHT=1 T="planner-trace-hull-rest PLANNER_HR_TASK=faced_move PLANNER_HR_SEED=66 PLANNER_HR_UNIT=Green_Guns_5"
# PLANNER_HR_CLICK=1 for the clicked arm. -> build/planner/trace-<task>-<seed>-<arm>.log (+ the screen's json).
PLANNER_HR_TASK ?= faced_move
PLANNER_HR_SEED ?= 66
PLANNER_HR_UNIT ?= Green_Guns_5
PLANNER_HR_CLICK ?=
.PHONY: planner-trace-hull-rest
planner-trace-hull-rest: native import ## planner round 32: one hull-rest run (PLANNER_HR_TASK/SEED, gangs) on fifo and shared with --turn-trace=PLANNER_HR_UNIT -> build/planner/trace-*
	@mkdir -p $(BUILD_DIR)/planner
	@for arm in fifo shared; do d=$(BUILD_DIR)/planner/trace-$(PLANNER_HR_TASK)-$(PLANNER_HR_SEED)-$$arm; rm -rf $$d; mkdir -p $$d; \
		echo ">> planner-trace-hull-rest on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | $$arm | $(PLANNER_HR_TASK) seed $(PLANNER_HR_SEED) | $(PLANNER_HR_UNIT)"; \
		timeout 300 $(GODOT) --headless --path . -- --skirmish --seed=$(PLANNER_HR_SEED) --no-pick-faction --mute --arena=$(FACING_ARENA) \
			--player-faction=gangs --enemy-faction=law --tune=match.no_damage=1 --enemy=$(FACING_QUIET_ENEMY) --no-element-cpu \
			$(if $(PLANNER_HR_CLICK),--faced-click) --turn-states --planner-queue=$$arm "--turn-trace=$(PLANNER_HR_UNIT)" \
			--screen-test=$(CURDIR)/$$d --screen-only=$(PLANNER_HR_TASK) > $$d/run.log 2>&1; \
		grep -c "^MANOEUVRE_TRACE" $$d/run.log | sed "s/^/   trace rows: /"; grep -E "^PLANNER_SEAM $(PLANNER_HR_UNIT) " $$d/run.log | cut -c1-300 || true; done

# Round 32 (CP-Q's park: the Terminus rig contact rise, a deterministic harness): ONE Terminus drive run on both queue
# arms (the native drive, the shipped default) with one hull traced (the drive's --trace and the census's --turn-trace).
# make remote LIGHT=1 T="planner-trace-drive-queue PLANNER_TQ_SEED=207 PLANNER_TQ_UNIT=Green_S0_4" -> build/planner-trace/{fifo,shared}-rigs-<seed>.log
PLANNER_TQ_SEED ?= 207
PLANNER_TQ_SQUAD ?= rigs
PLANNER_TQ_UNIT ?= Green_S0_4
.PHONY: planner-trace-drive-queue
planner-trace-drive-queue: native import ## planner round 32: the Terminus drive, one seed, both queue arms, one hull traced (PLANNER_TQ_SEED/SQUAD/UNIT) -> build/planner-trace/
	@mkdir -p $(PLANNER_TRACE_DIR)
	@for arm in fifo shared; do \
		echo ">> planner-trace-drive-queue on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | $$arm $(PLANNER_TQ_SQUAD)-$(PLANNER_TQ_SEED) trace $(PLANNER_TQ_UNIT)"; \
		$(MAKE) --no-print-directory nav-terminus-drive DRIVE_SQUADS="$(PLANNER_TQ_SQUAD)" DRIVE_SEEDS="$(PLANNER_TQ_SEED)" \
			NAV_FLAGS="--planner-queue=$$arm --trace=$(PLANNER_TQ_UNIT) --turn-trace=$(PLANNER_TQ_UNIT)" NAV_JOBS=1 > /dev/null 2>&1 || true; \
		cp $(BUILD_DIR)/nav-drive/$(PLANNER_TQ_SQUAD)-$(PLANNER_TQ_SEED).log $(PLANNER_TRACE_DIR)/$$arm-$(PLANNER_TQ_SQUAD)-$(PLANNER_TQ_SEED).log; \
		grep -E "^PLANNER_SEAM $(PLANNER_TQ_UNIT) " $(PLANNER_TRACE_DIR)/$$arm-$(PLANNER_TQ_SQUAD)-$(PLANNER_TQ_SEED).log | cut -c1-260 || true; done

# Round 32's s207 stage (planner-stage-s207, tests/planner/stage_s207.py) is RETIRED (round 33 overnight): its control
# (--planner-queue=shared-rolling pinning Green_S0_4 on Block_7) no longer reproduces, and the shared queue it guarded
# failed P2 (R33.13) and does not ship. Re-make it with a new control seed if the shared queue is ever re-filed.

# The planner's own Python tool tests (series_verdict's both-arms-seam mode). Laptop-light: make planner-pytest
.PHONY: planner-pytest
planner-pytest: ## planner: the planner tools' own Python tests (tests/planner/test_*.py)
	$(PYTHON) -m unittest discover -s tests/planner -p 'test_*.py'

# ---- round 33 (P1, C33.6 (a)): line (3)'s noise, the hull-rest gang arm A/A -------------------------------------------
# The FIFO both arms: base_* and new_* run the SAME flags (--planner-queue=fifo, the native drive) on the SAME seeds, so
# every difference is the probe's run-to-run noise (hull-rest is not deterministic). Read by tests/planner/hull_aa.py
# (per-class sd a run, round 32's lines read on the null) -> build/planner/hull-aa.txt + hull-aa-rows.jsonl. Heavy:
# make remote T=planner-aa-queue (144 runs at the default seeds).
PLANNER_AA_SEEDS ?= 66 67 68 69 70 71
.PHONY: planner-aa-queue
planner-aa-queue: native import ## planner round 33 P1: hull-rest's gang arm fifo v fifo (A/A) on PLANNER_AA_SEEDS -> build/planner/hull-aa.txt
	@mkdir -p $(BUILD_DIR)/planner
	@echo ">> planner-aa-queue on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | seeds $(PLANNER_AA_SEEDS)"
	@$(MAKE) --no-print-directory manoeuvre-hull-rest M1_ARMS="base_drawn base_clicked new_drawn new_clicked" \
		M1_BASE_OFF= M1_NEW_OFF= M1_FLAGS="--turn-states --planner-queue=fifo" \
		HULL_SEEDS="$(PLANNER_AA_SEEDS)" HULL_FACTIONS="$(PLANNER_QUEUE_FACTIONS)" > $(BUILD_DIR)/planner/hull-aa-runs.txt 2>&1 || true
	@grep -E "no SCREEN_DONE|SCRIPT ERROR" $(BUILD_DIR)/planner/hull-aa-runs.txt | head -5 || true
	@$(PYTHON) tests/planner/queue_table.py $(BUILD_DIR)/manoeuvre/hull-rest | tee $(BUILD_DIR)/planner/hull-aa.txt
	@$(PYTHON) tests/planner/hull_aa.py $(BUILD_DIR)/manoeuvre/hull-rest --rows $(BUILD_DIR)/planner/hull-aa-rows.jsonl | tee -a $(BUILD_DIR)/planner/hull-aa.txt

# ---- round 33 (P3, C33.6 (c)): the face searches' census at each weight ------------------------------------------------
# hull-rest's gang arm, drawn only, the FIFO (today), with --planner-face-shadow: every face search the seam begins is
# also planned whole at 1.5 / 2.0 / 3.0 (measurement; the hull drives today's). The DIAGNOSIS seeds (66-71: P1's A/A
# set), never P2's or P3's judged ones. -> build/planner/face-shadow.txt
PLANNER_SHADOW_SEEDS ?= 66 67 68 69 70 71
.PHONY: planner-face-shadow
planner-face-shadow: native import ## planner round 33 P3: which face searches land inside the hold at each weight (hull-rest gangs drawn, PLANNER_SHADOW_SEEDS) -> build/planner/face-shadow.txt
	@mkdir -p $(BUILD_DIR)/planner
	@echo ">> planner-face-shadow on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | seeds $(PLANNER_SHADOW_SEEDS)"
	@$(MAKE) --no-print-directory manoeuvre-hull-rest M1_ARMS=base_drawn M1_BASE_OFF= \
		M1_FLAGS="--turn-states --planner-queue=fifo --planner-face-shadow" HULL_SEEDS="$(PLANNER_SHADOW_SEEDS)" \
		HULL_FACTIONS="$(PLANNER_QUEUE_FACTIONS)" > $(BUILD_DIR)/planner/face-shadow-runs.txt 2>&1 || true
	@$(PYTHON) tests/planner/face_shadow_table.py $(BUILD_DIR)/manoeuvre/hull-rest/base_drawn | tee $(BUILD_DIR)/planner/face-shadow.txt

# ---- round 33 (P3, C33.6 (c)): the face keep circle's judged series ----------------------------------------------------
# One arm a call (PLANNER_FACE_ARM=base|candidate) on the pair tree (FACE_KEEP_DEFAULT 1): hull-rest's gang arm drawn +
# clicked, the native drive, the FIFO both arms (main's queue, R33.13), the keep EXPLICIT on each arm (base
# --planner-face-keep=0, candidate =1). Both arms called = the A/B: hull_aa.py --verdict (P2's pooled guards, line (2a))
# and face_keep_table.py (lines (2b) the FACE asks' abandoned share, (2c) the drift line).
PLANNER_FACE_SEEDS ?= 84 85 86 87 88 89 90 91 92 93 94 95
PLANNER_FACE_ARM ?= base
.PHONY: planner-judge-face
planner-judge-face: native import ## planner round 33 P3: hull-rest's gang arm, PLANNER_FACE_ARM=base (keep 0) | candidate (keep 1) on PLANNER_FACE_SEEDS
	@echo ">> planner-judge-face on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | arm $(PLANNER_FACE_ARM) | seeds $(PLANNER_FACE_SEEDS)"
	@$(MAKE) --no-print-directory manoeuvre-hull-rest M1_ARMS="$(if $(filter candidate,$(PLANNER_FACE_ARM)),new_drawn new_clicked,base_drawn base_clicked)" \
		M1_BASE_OFF= M1_NEW_OFF= M1_FLAGS="--turn-states --planner-queue=fifo --planner-face-keep=$(if $(filter candidate,$(PLANNER_FACE_ARM)),1,0)" \
		HULL_SEEDS="$(PLANNER_FACE_SEEDS)" HULL_FACTIONS="$(PLANNER_QUEUE_FACTIONS)"
	@$(PYTHON) tests/planner/face_keep_table.py $(BUILD_DIR)/manoeuvre/hull-rest --seeds "$(PLANNER_FACE_SEEDS)"

# The keep's Terminus rig series (line (3), arrivals): keep 0 v keep 1 on fresh seeds, the FIFO both arms.
PLANNER_FACE_SERIES_SEEDS ?= 231 232 233 234 235 236 237 238 239 240 241 242 243
.PHONY: planner-series-face
planner-series-face: ## planner round 33 P3: planner-series with base = --planner-face-keep=0, candidate = 1 (FIFO both), on PLANNER_FACE_SERIES_SEEDS
	@$(MAKE) --no-print-directory planner-series PLANNER_SERIES_SEEDS="$(PLANNER_FACE_SERIES_SEEDS)" \
		PLANNER_SERIES_BASE_FLAGS="--planner-queue=fifo --planner-face-keep=0" PLANNER_SERIES_CAND_FLAGS="--planner-queue=fifo --planner-face-keep=1" \
		PLANNER_SERIES_SEAM=both
