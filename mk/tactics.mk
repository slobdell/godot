# Elements, doctrine tables and battle drills (doctrine stream; _agents/doctrine.md).
# Owner: doctrine (see _agents/workstreams.md). Included by the root Makefile.

tactics-test: import ## The doctrine stream's tests (formations, tables, drills, elements, scenarios)
	$(MAKE) --no-print-directory test FILTER=tactics

tactics-drills: import ## Seeded battle-drill scenarios, faster than real time: every drill fires on its trigger (IDLE_FACE=on|off: round 13's S6 arm)
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/run_tactics.gd -- --drills $(if $(FILTER),--filter=$(FILTER)) \
		$(if $(IDLE_FACE),--idle-face=$(IDLE_FACE)) 2>&1 | tee $(BUILD_DIR)/tactics-drills.log | grep -E "TACTICS|ERROR" || true
	grep -q "TACTICS_DONE failures=0" $(BUILD_DIR)/tactics-drills.log

tactics-measure: import ## X4: what each formation and technique is worth, under identical conditions -> build/tactics/measurements.json
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/run_tactics.gd -- --measure $(if $(FILTER),--filter=$(FILTER)) \
		2>&1 | tee $(BUILD_DIR)/tactics-measure.log | grep -E "TACTICS|ERROR" || true
	grep -q "TACTICS_DONE" $(BUILD_DIR)/tactics-measure.log

tactics-shots: import ## Doctrine in pictures: elements moving, ambushed and bounding, frames in build/tactics-shots/ (needs a display: make remote T=tactics-shots)
	mkdir -p $(BUILD_DIR)/tactics-shots
	$(GODOT) --path . --fixed-fps $(SIM_HZ) --resolution 1280x960 --script res://tests/tactics/tactics_shots.gd -- $(if $(STAGE),--stage=$(STAGE)) \
		2>&1 | tee $(BUILD_DIR)/tactics-shots/log.txt | grep -E "TACTICS_SHOT|ERROR" || true
	grep -q TACTICS_SHOTS_DONE $(BUILD_DIR)/tactics-shots/log.txt

formation-shots: import ## Round 12 (S5): a plain move at HIS pose (21 deg, FOV 35, 49 m, following from behind) as a column and as a wedge, frames at 10 s and at arrival: build/formation-shots/<arena>_<shape>_{10s,arrival}.png (needs a display: make remote T=formation-shots). ARENAS="yard terminus" SHAPES="column wedge" SEED=3. Round 13: UNITS=scout:scout:ifv:ifv:tank IDLE_FACE=off|on SETTLE=on (frames when settled and at 25 s, slots drawn)
	mkdir -p $(BUILD_DIR)/formation-shots
	$(GODOT) --path . --fixed-fps $(SIM_HZ) --resolution 1280x720 --script res://tests/tactics/formation_shots.gd -- \
		--arenas="$(or $(ARENAS),yard terminus)" --shapes="$(or $(SHAPES),column wedge)" --seed=$(or $(SEED),3) \
		$(if $(UNITS),--units=$(UNITS)) $(if $(IDLE_FACE),--idle-face=$(IDLE_FACE)) $(if $(SETTLE),--settle=$(SETTLE)) \
		2>&1 | tee $(BUILD_DIR)/formation-shots/log.txt | grep -E "FORMATION_SHOT|FORMATION_SETTLED|ERROR" || true
	grep -q FORMATION_SHOTS_DONE $(BUILD_DIR)/formation-shots/log.txt

tactics-parity: import ## X5: a scripted match where BOTH sides run doctrine; prints what a spectator sees
	@echo ">> tactics-parity: PARITY_SECONDS=$(PARITY_SECONDS)"
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/run_parity.gd -- $(if $(PARITY_SECONDS),--seconds=$(PARITY_SECONDS)) \
		2>&1 | tee $(BUILD_DIR)/tactics-parity.log | grep -E "PARITY|ERROR" || true
	grep -q PARITY_DONE $(BUILD_DIR)/tactics-parity.log

doctrine-page: ## The lead's read-only doctrine view: every table, its rules and its drill numbers -> build/doctrine/index.html
	$(PYTHON) tools/tactics/doctrine_page.py --out $(BUILD_DIR)/doctrine

# Knobs this file owns carry its prefix; the old names work only from the command line (see mk/ai.mk's `cmdline`,
# which the root Makefile includes first).
PARITY_SECONDS ?= $(call cmdline,SECONDS,)
TACTICS_SIDES_DEFAULT := brains=x4t9,standard=x4t9:standard,faction=x4t9:
TACTICS_SIDES ?= $(call cmdline,SIDES,$(TACTICS_SIDES_DEFAULT))
TACTICS_ARENAS_DEFAULT := foundry,yard,boulevard,pit,boneyard
TACTICS_ARENAS ?= $(call cmdline,ARENAS,$(TACTICS_ARENAS_DEFAULT))
TACTICS_ARMY ?= $(call cmdline,ARMY,combined_arms)
TACTICS_RUNS ?= $(call cmdline,RUNS,2)
tactics-ladder: import ## Round-5 X3: doctrine vs doctrine vs brains, mirror TACTICS_ARMY, every TACTICS_ARENAS, TACTICS_SIDES=label=brain[:table], FACTIONS=gangs,law for faction armies; ELO and a per-drill exchange report -> build/tactics-ladder.json (TACTICS_RUNS=2 TIME=240; heavy: make remote T=tactics-ladder)
	@echo ">> tactics-ladder: TACTICS_SIDES=$(TACTICS_SIDES) TACTICS_ARENAS=$(TACTICS_ARENAS) TACTICS_ARMY=$(TACTICS_ARMY) TACTICS_RUNS=$(TACTICS_RUNS)"
	$(PYTHON) tools/tactics_ladder.py --godot $(GODOT) --sides $(TACTICS_SIDES) --arenas $(TACTICS_ARENAS) --army $(TACTICS_ARMY) \
		--runs $(TACTICS_RUNS) --jobs $(JOBS) --time-limit $(or $(TIME),240) $(if $(FACTIONS),--factions $(FACTIONS)) $(if $(CONTROL),--control $(CONTROL)) --json $(BUILD_DIR)/tactics-ladder.json

squad-coherence: import ## Round-6 X6: legibility as numbers (idle in contact, drill flip-flops, order thrash, off-slot, stale orders) over SEEDS faction matches in the shipped configuration (GREEN_FACTION= RUST_FACTION= TIME=180 EXTRA="--green-elements --rust-elements") -> build/squad-coherence.json
	$(PYTHON) tools/tactics/coherence.py --godot $(GODOT) --seeds $(or $(SEEDS),4) --jobs $(JOBS) \
		--green $(or $(GREEN_FACTION),condemned) --rust $(or $(RUST_FACTION),law) --time-limit $(or $(TIME),180) \
		$(if $(EXTRA),--extra="$(EXTRA)") --json $(BUILD_DIR)/squad-coherence.json

squad-decisions: import ## Round 7: split attack-move's "re-task events" (drive target jumping > 8 m, nav-fight's measure) into decisions (option/target changed) vs motion inside one decision, and count A->B->A reversals, in nav-fight's own fight, and A1's brain half measured where it can be measured: TUBE=on|off reports redecides/skips/held_share over the GREEN roster (ARENA=yard SEED=3 NAV_TIME=120 BUDGET=6500)
	@echo ">> squad-decisions: ARENA=$(or $(ARENA),yard) SEED=$(or $(SEED),3) NAV_TIME=$(or $(NAV_TIME),120)"
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/decision_probe.gd -- \
		--arena=$(or $(ARENA),yard) --seed=$(or $(SEED),3) --time-limit=$(or $(NAV_TIME),120) --budget=$(or $(BUDGET),6500) \
		--tube=$(or $(TUBE),off) \
		2>&1 | grep -E "DECISION_PROBE|SCRIPT ERROR|ERROR" || true

squad-defile: import ## Round 9 X2/X3/A1: an element through the maze's 11 m gap -- crossings, rank inversions, post-defile recovery, arrival dispersion, stationary share, and brain re-decides. ARM=wheeled|tracked DEFORM=on|off TUBE=on|off SEED=3 DEFILE_SECONDS=40. The control arm is LOCOMOTION, not faction (metrics CP1: the shuffle is a wheels property), so both arms are Condemned.
	@echo ">> squad-defile: ARM=$(or $(ARM),wheeled) DEFORM=$(or $(DEFORM),on) SEED=$(or $(SEED),3) TECHNIQUE=$(TECHNIQUE)"
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/defile_probe.gd -- \
		--arm=$(or $(ARM),wheeled) --deform=$(or $(DEFORM),on) --seed=$(or $(SEED),3) \
		--seconds=$(or $(DEFILE_SECONDS),40) $(if $(TECHNIQUE),--technique=$(TECHNIQUE)) \
		--formation=$(or $(FORMATION),wedge) --tube=$(or $(TUBE),off) \
		2>&1 | grep -E "DEFILE_PROBE|SCRIPT ERROR|ERROR" || true

squad-fallin-series: import ## Round 12 (S3): squad-settle at TRANSIT_METRES (80) over paired seeds, both arms of FALLIN (the fall-in rule; both ride the anchor) on the same seeds, the yard and the Terminus, forward and side, a tracked/wheeled squad and a mixed one. Reports stop, arrival, the in-transit station error and its first 10 s. FALLIN_ARM=on|lane|wait (the ON arm's mode), TRANSIT_SEEDS="1 2 3 4" -> build/squad-fallin.jsonl
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/squad-fallin.jsonl
	@for arena in yard terminus; do for dir in forward side; do for units in tank:tank:ifv:ifv scout:scout:ifv:ifv:tank; do for seed in $(or $(TRANSIT_SEEDS),1 2 3 4); do for fallin in off $(or $(FALLIN_ARM),on); do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/settle_probe.gd -- \
			--arena=$$arena --dir=$$dir --seed=$$seed --units=$$units --fallin=$$fallin --metres=$(or $(TRANSIT_METRES),80) \
			--seconds=$(or $(SETTLE_SECONDS),90) --drills=off 2>&1 \
			| grep "^SETTLE_PROBE {" | sed 's/^SETTLE_PROBE //' >> $(BUILD_DIR)/squad-fallin.jsonl & \
		done; wait; done; done; done; done
	@$(PYTHON) tools/tactics/transit_series.py $(BUILD_DIR)/squad-fallin.jsonl --arm=fallin

squad-partial: import ## Round 12 (S4): a PARTIAL (3 of a 5-unit squad) / MIXED (2+2 across squads) / WHOLE selection ordered 80 m on the default path (RtsControls.order_selection, squads on number keys as skirmish puts them): which path it takes, the card's readout, the spread while moving, arrival. CASE=partial|mixed|whole ARENA=yard SEED=3; TRACKS=on adds SETTLE_TRACK lines for tools/tactics/plot_tracks.py
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/partial_probe.gd -- \
		--case=$(or $(CASE),partial) --arena=$(or $(ARENA),yard) --seed=$(or $(SEED),3) --metres=$(or $(METRES),80) \
		2>&1 | grep -E "PARTIAL_PROBE|$(if $(filter on,$(TRACKS)),SETTLE_TRACK|)SCRIPT ERROR|ERROR" || true

squad-partial-series: import ## Round 12 (S4): squad-partial for every CASE on the yard and the Terminus over PARTIAL_SEEDS (default 1 2 3 4) -> build/squad-partial.jsonl and a summary
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/squad-partial.jsonl
	@for arena in yard terminus; do for seed in $(or $(PARTIAL_SEEDS),1 2 3 4); do for c in whole partial mixed; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/partial_probe.gd -- \
			--case=$$c --arena=$$arena --seed=$$seed 2>&1 | grep "^PARTIAL_PROBE {" | sed 's/^PARTIAL_PROBE //' >> $(BUILD_DIR)/squad-partial.jsonl & \
		done; wait; done; done
	@$(PYTHON) tools/tactics/partial_series.py $(BUILD_DIR)/squad-partial.jsonl

squad-shape-series: import ## Round 12 (S5): a plain move 80 m ordered as a COLUMN (reported "off") and as a WEDGE ("on"), both with G so each holds its shape at every phase (C12.5), same seeds, the yard and the Terminus, forward and side, a tracked/wheeled squad and a mixed one: stop, arrival, station error in transit and its first 10 s. TRANSIT_SEEDS="1 2 3 4" -> build/squad-shape.jsonl
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/squad-shape.jsonl
	@for arena in yard terminus; do for dir in forward side; do for units in tank:tank:ifv:ifv scout:scout:ifv:ifv:tank; do for seed in $(or $(TRANSIT_SEEDS),1 2 3 4); do for shape in column wedge; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/settle_probe.gd -- \
			--arena=$$arena --dir=$$dir --seed=$$seed --units=$$units --shape=$$shape --metres=$(or $(TRANSIT_METRES),80) \
			--seconds=$(or $(SETTLE_SECONDS),90) --drills=off 2>&1 \
			| grep "^SETTLE_PROBE {" | sed 's/^SETTLE_PROBE //' >> $(BUILD_DIR)/squad-shape.jsonl & \
		done; wait; done; done; done; done
	@$(PYTHON) tools/tactics/transit_series.py $(BUILD_DIR)/squad-shape.jsonl --arm=shape --off=column

squad-idleface-series: import ## Round 13 (Q2, S6): a plain move of METRES 80, both arms of IDLE_FACE (on = a no-pivot fixed gun with nothing in sight is not told to face) on the same seeds, the yard and the Terminus, forward and side, the mixed squad (scouts) and the tracked/wheeled control (no scouts: must not move). IDLEFACE_SEEDS="1 2 3 4 5 6 7 8" -> build/squad-idleface.jsonl
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/squad-idleface.jsonl
	@for arena in yard terminus; do for dir in forward side; do for units in tank:tank:ifv:ifv scout:scout:ifv:ifv:tank; do for seed in $(or $(IDLEFACE_SEEDS),1 2 3 4 5 6 7 8); do for arm in off on; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/settle_probe.gd -- \
			--arena=$$arena --dir=$$dir --seed=$$seed --units=$$units --idle-face=$$arm --metres=$(or $(METRES),80) \
			--seconds=$(or $(SETTLE_SECONDS),90) --drills=off 2>&1 \
			| grep "^SETTLE_PROBE {" | sed 's/^SETTLE_PROBE //' >> $(BUILD_DIR)/squad-idleface.jsonl & \
		done; wait; done; done; done; done
	@$(PYTHON) tools/tactics/idleface_series.py $(BUILD_DIR)/squad-idleface.jsonl

tactics-terrain: import ## Round 12 (S1/S5): the doctrine's terrain class (open/lanes/dense) at every rotation map's spawns and every 10 m along an 80 m move forward and to the side, with AUTO's pick at the order. Light (no physics)
	$(GODOT) --headless --path . --script res://tests/tactics/terrain_probe.gd 2>&1 | grep -E "^TERRAIN|SCRIPT ERROR|ERROR" || true

squad-settle: import ## Round 10 item 3: a squad's plain move end to end -- order acknowledged, arrival declared (COMPLETED), every crew stopped -- on the default path's element. ARENA= (default scene) or terminus, DIR=forward|side|back, METRES=20, UNITS=tank:tank:ifv:ifv, SEED=3. Round 12: TRANSIT=off is the control arm (no travelling anchor); transit_gap_m / transit_s report the shape on the way. S3: FALLIN=off is the fall-in rule's control arm
	@echo ">> squad-settle: ARENA=$(or $(ARENA),default) SEED=$(call cmdline,SEED,3) DIR=$(or $(DIR),forward) METRES=$(or $(METRES),20) TRANSIT=$(or $(TRANSIT),on)"
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/settle_probe.gd -- \
		--arena=$(ARENA) --dir=$(or $(DIR),forward) --metres=$(or $(METRES),20) --seed=$(call cmdline,SEED,3) \
		--units=$(or $(UNITS),tank:tank:ifv:ifv) --seconds=$(or $(SETTLE_SECONDS),45) --trace=$(or $(TRACE),off) \
		--transit=$(or $(TRANSIT),on) --fallin=$(or $(FALLIN),default) $(if $(SHAPE),--shape=$(SHAPE)) \
		2>&1 | grep -E "SETTLE_PROBE|SETTLE_TRACE|SETTLE_TRACK|SCRIPT ERROR|ERROR" || true

squad-settle-series: import ## Round 10 item 3: squad-settle over paired seeds, both arms of PIN (the leader pinned to the head of a plain move's shape) on the same seeds, every ARENA and DIR. SETTLE_SEEDS="1 2 3 4 5 6 7 8" -> build/squad-settle.jsonl
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/squad-settle.jsonl
	@for arena in "" terminus; do for dir in forward side back; do for seed in $(or $(SETTLE_SEEDS),1 2 3 4 5 6 7 8); do for pin in off on; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/settle_probe.gd -- \
			--arena=$$arena --dir=$$dir --seed=$$seed --pin=$$pin --seconds=$(or $(SETTLE_SECONDS),45) \
			--drills=$(or $(SETTLE_DRILLS),off) 2>&1 \
			| grep "^SETTLE_PROBE {" | sed 's/^SETTLE_PROBE //' >> $(BUILD_DIR)/squad-settle.jsonl & \
		done; wait; done; done; done
	@$(PYTHON) tools/tactics/settle_series.py $(BUILD_DIR)/squad-settle.jsonl

squad-transit-series: import ## Round 12: squad-settle at TRANSIT_METRES (80) over paired seeds, both arms of TRANSIT (the travelling anchor) on the same seeds, the yard and the Terminus (maps he plays; the default scene is the foundry, which is not dealt), forward and side, a tracked/wheeled squad and a mixed one. TRANSIT_SEEDS="1 2 3 4" TRANSIT_JOBS=4 -> build/squad-transit.jsonl
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/squad-transit.jsonl
	@for arena in yard terminus; do for dir in forward side; do for units in tank:tank:ifv:ifv scout:scout:ifv:ifv:tank; do for seed in $(or $(TRANSIT_SEEDS),1 2 3 4); do for transit in off on; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/settle_probe.gd -- \
			--arena=$$arena --dir=$$dir --seed=$$seed --units=$$units --transit=$$transit --metres=$(or $(TRANSIT_METRES),80) \
			--seconds=$(or $(SETTLE_SECONDS),90) --drills=off 2>&1 \
			| grep "^SETTLE_PROBE {" | sed 's/^SETTLE_PROBE //' >> $(BUILD_DIR)/squad-transit.jsonl & \
		done; wait; done; done; done; done
	@$(PYTHON) tools/tactics/transit_series.py $(BUILD_DIR)/squad-transit.jsonl
