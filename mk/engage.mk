# ---- engage (round 42): "in range" means a clear shot ---------------------------------------------------------------
# Owner: the engage stream (_agents/streams/archive/round42/engage.md). The rule is `--attack-shot=on|off` (env ATTACK_SHOT).

# E1: his crew behind the container, rebuilt (Locks, seed 49326, the census's places), one ENGAGE_TRACE row per sample tick
# (and on every change): the element's order, the brain's choice and move, the mover's phase, the gun, both sight reads, the HUD's
# words. ENGAGE_ARM=on|off selects the rule; ENGAGE_SECONDS the window.
ENGAGE_ARM ?= off
ENGAGE_SECONDS ?= 40
.PHONY: engage-far-trace
engage-far-trace: import ## engage R42.10: the far_ambush drill's stage with one FAR_TRACE line per crew per sample (ENGAGE_ARM=on|off) -> build/engage/far_trace_<arm>.log
	@mkdir -p $(BUILD_DIR)/engage
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/engage/far_ambush_trace.gd -- \
		--seconds=26 --every=30 --attack-shot=$(ENGAGE_ARM) > $(BUILD_DIR)/engage/far_trace_$(ENGAGE_ARM).log 2>&1 || true
	@grep -E "FAR_HP|FAR_TRACE_FLAG|FAR_TRACE_DONE|ERROR" $(BUILD_DIR)/engage/far_trace_$(ENGAGE_ARM).log || true

.PHONY: engage-replay
engage-replay: import ## engage E1: replay his crew behind the container (ENGAGE_ARM=on|off, ENGAGE_SECONDS) -> build/engage/replay_<arm>.log
	@mkdir -p $(BUILD_DIR)/engage
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/engage/replay_probe.gd -- \
		--seconds=$(ENGAGE_SECONDS) --every=30 --attack-shot=$(ENGAGE_ARM) > $(BUILD_DIR)/engage/replay_$(ENGAGE_ARM).log 2>&1 || true
	@grep -E "ENGAGE_REPLAY|SCRIPT ERROR" $(BUILD_DIR)/engage/replay_$(ENGAGE_ARM).log

# E4 (Bar E1's deciding workload): his case as a probe. ENGAGE_SEEDS x the arena cycle (locks / terminus / crossing by seed), 2-5
# crews ordered to attack a target behind cover, crews on both sides of it; one ENGAGE_PROBE json line per run. ENGAGE_ARM as above.
ENGAGE_SEEDS ?= 7001 7002 7003
ENGAGE_PROBE_SECONDS ?= 60
ENGAGE_JOBS ?= 4
.PHONY: engage-probe
# Round 42 (v2's lab): ENGAGE_TAG names the result folder (default: the arm), so two arms of a SECOND switch can sit side
# by side under the same --attack-shot arm: ENGAGE_ARM=on ENGAGE_TAG=v2off / ENGAGE_FLAGS=--attack-shot-suppress=on ENGAGE_TAG=v2on.
ENGAGE_TAG ?= $(ENGAGE_ARM)

engage-probe: import ## engage E4: the attack-shot probe over ENGAGE_SEEDS (ENGAGE_ARM=on|off, ENGAGE_PROBE_SECONDS, ENGAGE_JOBS) -> build/engage/probe/<arm>/<seed>.log + the table
	@mkdir -p $(BUILD_DIR)/engage/probe/$(ENGAGE_TAG)
	@echo ">> engage-probe on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | arm $(ENGAGE_ARM) | seeds $(firstword $(ENGAGE_SEEDS))+ | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for seed in $(ENGAGE_SEEDS); do echo $$seed; done | xargs -r -P $(ENGAGE_JOBS) -I{} sh -c \
		'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/engage/attack_shot_probe.gd -- \
		--seed={} --seconds=$(ENGAGE_PROBE_SECONDS) --attack-shot=$(ENGAGE_ARM) $(ENGAGE_FLAGS) > $(BUILD_DIR)/engage/probe/$(ENGAGE_TAG)/{}.log 2>&1 || true; \
		grep -q "^ENGAGE_PROBE " $(BUILD_DIR)/engage/probe/$(ENGAGE_TAG)/{}.log || echo "  MISSING ENGAGE_PROBE seed {}"'
	$(PYTHON) tests/engage/attack_shot_table.py $(BUILD_DIR)/engage/probe/$(ENGAGE_TAG)

# Both arms on the same seeds, then the paired table (Bar E1's lines read from it).
.PHONY: engage-bar
engage-bar: import ## engage E4: engage-probe in both arms on ENGAGE_SEEDS, then the paired table (tests/engage/attack_shot_table.py --pair)
	@$(MAKE) --no-print-directory engage-probe ENGAGE_ARM=off
	@$(MAKE) --no-print-directory engage-probe ENGAGE_ARM=on
	$(PYTHON) tests/engage/attack_shot_table.py --pair $(BUILD_DIR)/engage/probe/off $(BUILD_DIR)/engage/probe/on

# Round 42 (Bar E2, R42.14): v2's two arms under --attack-shot ON (today's default): OFF = the stand as shipped, ON = + the
# SUPPRESS stand's own line (--attack-shot-suppress=on); the table's --deciding=suppress mode (the dominance line, the floor).
.PHONY: engage-bar2
engage-bar2: import ## engage Bar E2: engage-probe v2off/v2on on ENGAGE_SEEDS (both under --attack-shot=on), then the paired table --deciding=suppress
	@$(MAKE) --no-print-directory engage-probe ENGAGE_ARM=on ENGAGE_TAG=v2off
	@$(MAKE) --no-print-directory engage-probe ENGAGE_ARM=on ENGAGE_TAG=v2on ENGAGE_FLAGS=--attack-shot-suppress=on
	$(PYTHON) tests/engage/attack_shot_table.py --pair $(BUILD_DIR)/engage/probe/v2off $(BUILD_DIR)/engage/probe/v2on --deciding=suppress

# A quick parse check of the stream's own scripts.
ENGAGE_PARSE ?= game/tactics/firing_position.gd game/tactics/element_situation.gd game/tactics/element_plan.gd game/ai/tank_brain.gd \
	game/control/rts_controls.gd tests/tactics/test_engage_shot.gd tests/engage/replay_probe.gd tests/engage/attack_shot_probe.gd \
	tests/engage/test_engage_hud_words.gd tests/tactics/test_engage_flank_side.gd tests/engage/far_ambush_trace.gd
.PHONY: engage-parse
engage-parse: import ## engage: --check-only on the stream's scripts (ENGAGE_PARSE), the real messages printed
	@for f in $(ENGAGE_PARSE); do out=$$($(GODOT) --headless --path . --check-only --script res://$$f 2>&1 | grep -E "Parse Error|SCRIPT ERROR|ERROR" | grep -v "depended scripts" || true); \
		if [ -n "$$out" ]; then echo "== $$f"; echo "$$out" | head -8; else echo "ok $$f"; fi; done

# ---- engage (round 43): his War Rig's turnaround under attack-move (A1) ---------------------------------------------
# Owner: the engage stream (_agents/streams/engage.md). His recording: _agents/streams/references/round42/playtest/ (gzipped);
# `engage-his` unpacks it to build/engage/his.jsonl (the probes read plain jsonl).
ENGAGE_HIS_GZ ?= _agents/streams/references/round42/playtest/2026-10-27T20-00-48-locks.jsonl.gz
ENGAGE_HIS ?= $(BUILD_DIR)/engage/his.jsonl
ENGAGE_CREW ?= Green_Guns_1
ENGAGE_FROM ?= 630
ENGAGE_TA_SECONDS ?= 30
$(ENGAGE_HIS): $(ENGAGE_HIS_GZ)
	@mkdir -p $(BUILD_DIR)/engage
	zcat $(ENGAGE_HIS_GZ) > $(ENGAGE_HIS)

.PHONY: engage-his engage-rebuild engage-replay-trace engage-paths
engage-his: $(ENGAGE_HIS) ## engage A1: unpack his Locks 56416 recording to build/engage/his.jsonl

engage-rebuild: import $(ENGAGE_HIS) ## engage A1: census-places rebuild of his match from ENGAGE_FROM, ENGAGE_CREW traced (ENGAGE_FLAGS) -> build/engage/ta_<from>.log
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/engage/turnaround_probe.gd -- \
		--recording=$(ENGAGE_HIS) --from=$(ENGAGE_FROM) --seconds=$(ENGAGE_TA_SECONDS) --every=30 --crew=$(ENGAGE_CREW) \
		--crew-trace=$(ENGAGE_CREW) --element-trace=Guns $(ENGAGE_FLAGS) > $(BUILD_DIR)/engage/ta_$(ENGAGE_FROM).log 2>&1 || true
	@grep -E "ENGAGE_TA_SETUP|ENGAGE_TA_SUMMARY|SCRIPT ERROR" $(BUILD_DIR)/engage/ta_$(ENGAGE_FROM).log | cut -c1-400

# The faithful replay (native's tests/replay_orders.gd, CP43.0) with the crew and element traces on; its own recording
# lands in build/engage/rec/<tag>/ (read it with tools/recording_arrivals.py and tests/replay/divergence.py). ENGAGE_TAG
# names the run (an arm); ENGAGE_FLAGS are the switches under test (e.g. --attack-shot=off, --nav-off=a11).
ENGAGE_REPLAY_SECONDS ?= 50
engage-replay-trace: import $(ENGAGE_HIS) ## engage A1: his match replayed (CP43.0) with --crew-trace=ENGAGE_CREW, ENGAGE_FLAGS -> build/engage/replay_<tag>.log + rec/<tag>/
	@mkdir -p $(BUILD_DIR)/engage/rec/$(ENGAGE_TAG)
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/replay_orders.gd -- --orders=$(ENGAGE_HIS) \
		--seconds=$(ENGAGE_REPLAY_SECONDS) --record-dir=$(BUILD_DIR)/engage/rec/$(ENGAGE_TAG) --crew-trace=$(ENGAGE_CREW) \
		--element-trace=Guns $(ENGAGE_FLAGS) > $(BUILD_DIR)/engage/replay_$(ENGAGE_TAG).log 2>&1 || true
	@grep -E "REPLAY_SETUP|REPLAY_SPAWN|REPLAY_NATIVE|REPLAY_ROSTER|REPLAY_DONE|SCRIPT ERROR" $(BUILD_DIR)/engage/replay_$(ENGAGE_TAG).log | cut -c1-300
	@$(PYTHON) tools/recording_arrivals.py $$(ls -t $(BUILD_DIR)/engage/rec/$(ENGAGE_TAG)/*.jsonl | head -1) | grep -E "attack_move|===" || true

engage-paths: import ## engage A1: the navmesh's routes on Locks for ENGAGE_LEGS ("x,z>x,z;...")
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/engage/path_probe.gd -- "--legs=$(ENGAGE_LEGS)" 2>&1 | grep -E "ENGAGE_PATH|SCRIPT ERROR"

# ---- engage (round 43): Bar A, the street hold's far crew (A3 `holdfar`, A4) ----------------------------------------
# Workload: tests/engage/hold_probe.gd (two friendly squads head-on in a street, the waiting squad's rear crews 55-95 m back).
# ENGAGE_HOLD_ARM=off|on selects the arm (on = --traffic-on=$(ENGAGE_HOLD_SWITCH)); ENGAGE_HOLD_SEEDS the seeds (Bar A: 10301-10324,
# FAILED R43.18; Bar A6: 10373-10396).
ENGAGE_HOLD_SEEDS ?= 10301 10302 10303
ENGAGE_HOLD_ARM ?= off
ENGAGE_HOLD_SECONDS ?= 75
ENGAGE_HOLD_TAG ?= $(ENGAGE_HOLD_ARM)
## The Traffic switch the ARM turns on: holdfar (Bar A, FAILED R43.18) or holdway (Bar A6).
ENGAGE_HOLD_SWITCH ?= holdway
.PHONY: engage-hold engage-bar-a
engage-hold: import ## engage A4: the street-hold probe over ENGAGE_HOLD_SEEDS (ENGAGE_HOLD_ARM=off|on, ENGAGE_JOBS) -> build/engage/hold/<tag>/<seed>.log + the table
	@mkdir -p $(BUILD_DIR)/engage/hold/$(ENGAGE_HOLD_TAG)
	@rm -f $(BUILD_DIR)/engage/hold/$(ENGAGE_HOLD_TAG)/*.log  # one series per folder: an earlier run's rows would pair with this one's
	@echo ">> engage-hold on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | arm $(ENGAGE_HOLD_ARM) | seeds $(firstword $(ENGAGE_HOLD_SEEDS))+ | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for seed in $(ENGAGE_HOLD_SEEDS); do echo $$seed; done | xargs -r -P $(ENGAGE_JOBS) -I{} sh -c \
		'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/engage/hold_probe.gd -- \
		--seed={} --seconds=$(ENGAGE_HOLD_SECONDS) $(if $(filter on,$(ENGAGE_HOLD_ARM)),--traffic-on=$(ENGAGE_HOLD_SWITCH),) $(ENGAGE_FLAGS) > $(BUILD_DIR)/engage/hold/$(ENGAGE_HOLD_TAG)/{}.log 2>&1 || true; \
		grep -q "^ENGAGE_HOLD " $(BUILD_DIR)/engage/hold/$(ENGAGE_HOLD_TAG)/{}.log || echo "  MISSING ENGAGE_HOLD seed {}"'
	$(PYTHON) tests/engage/hold_table.py $(BUILD_DIR)/engage/hold/$(ENGAGE_HOLD_TAG)

engage-bar-a: import ## engage Bar A / A6: engage-hold in both arms on ENGAGE_HOLD_SEEDS, then the paired table (tests/engage/hold_table.py --pair)
	@$(MAKE) --no-print-directory engage-hold ENGAGE_HOLD_ARM=off
	@$(MAKE) --no-print-directory engage-hold ENGAGE_HOLD_ARM=on
	$(PYTHON) tests/engage/hold_table.py --pair $(BUILD_DIR)/engage/hold/off $(BUILD_DIR)/engage/hold/on --by-stage

# Round 43 (Bar A6 v2, R43.20): two arms against one base. ARM-W = the ordered-way read alone (holdway), ARM-WR = the read +
# the release judged on the crew's route to its squad's destination (holdway,holdroute). Each arm's table against the base.
.PHONY: engage-bar-a6
engage-bar-a6: import ## engage Bar A6 v2: engage-hold off / w / wr on ENGAGE_HOLD_SEEDS, then the two paired tables by stage
	@$(MAKE) --no-print-directory engage-hold ENGAGE_HOLD_ARM=off ENGAGE_HOLD_TAG=off
	@$(MAKE) --no-print-directory engage-hold ENGAGE_HOLD_ARM=on ENGAGE_HOLD_SWITCH=holdway ENGAGE_HOLD_TAG=w
	@$(MAKE) --no-print-directory engage-hold ENGAGE_HOLD_ARM=on ENGAGE_HOLD_SWITCH=holdway,holdroute ENGAGE_HOLD_TAG=wr
	@echo "##### ARM-W (holdway) v BASE"; $(PYTHON) tests/engage/hold_table.py --pair $(BUILD_DIR)/engage/hold/off $(BUILD_DIR)/engage/hold/w --by-stage
	@echo "##### ARM-WR (holdway,holdroute) v BASE"; $(PYTHON) tests/engage/hold_table.py --pair $(BUILD_DIR)/engage/hold/off $(BUILD_DIR)/engage/hold/wr --by-stage
