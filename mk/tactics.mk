# Elements, doctrine tables and battle drills (doctrine stream; _agents/doctrine.md).
# Owner: doctrine (see _agents/workstreams.md). Included by the root Makefile.

tactics-test: import ## The doctrine stream's tests (formations, tables, drills, elements, scenarios)
	$(MAKE) --no-print-directory test FILTER=tactics

tactics-drills: import ## Seeded battle-drill scenarios, faster than real time: every drill fires on its trigger (IDLE_FACE=on|off: round 13's S6 arm)
	s=0; $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/run_tactics.gd -- --drills $(if $(FILTER),--filter=$(FILTER)) \
		$(if $(IDLE_FACE),--idle-face=$(IDLE_FACE)) $(if $(MUTATE),--mutate=$(MUTATE)) > $(BUILD_DIR)/tactics-drills.log 2>&1 || s=$$?; \
	grep -E "TACTICS|ERROR" $(BUILD_DIR)/tactics-drills.log || true; \
	tools/exit_gate.sh tactics-drills $$s $(BUILD_DIR)/tactics-drills.log $(if $(MUTATE),1)
	grep -q "TACTICS_DONE failures=0" $(BUILD_DIR)/tactics-drills.log

tactics-measure: import ## X4: what each formation and technique is worth, under identical conditions -> build/tactics/measurements.json
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/run_tactics.gd -- --measure $(if $(FILTER),--filter=$(FILTER)) \
		2>&1 | tee $(BUILD_DIR)/tactics-measure.log | grep -E "TACTICS|ERROR" || true
	grep -q "TACTICS_DONE" $(BUILD_DIR)/tactics-measure.log

tactics-shots: import ## Doctrine in pictures: elements moving, ambushed and bounding, frames in build/tactics-shots/ (needs a display: make remote T=tactics-shots; round 14: STAGE=gang_pack SHOT_ARGS="--pose=his --chasers --table=standard")
	mkdir -p $(BUILD_DIR)/tactics-shots
	$(GODOT) --path . --fixed-fps $(SIM_HZ) --resolution 1280x960 --script res://tests/tactics/tactics_shots.gd -- $(if $(STAGE),--stage=$(STAGE)) $(SHOT_ARGS) \
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
		--runs $(TACTICS_RUNS) --jobs $(JOBS) --time-limit $(or $(TIME),240) $(if $(FACTIONS),--factions $(FACTIONS)) $(if $(CONTROL),--control $(CONTROL)) --json $(BUILD_DIR)/tactics-ladder.json \
		$(if $(LADDER_COMPARE),--compare $(LADDER_COMPARE))

# Round 15 (squad P2): the reference ladder, taken under the CURRENT winner rule on main as it stands, kept in the tree
# (tools/tactics/ladder_reference.json). Every later `make tactics-ladder LADDER_COMPARE=tools/tactics/ladder_reference.json`
# with the default workload is set beside it -- or refused (exit 3) when the winner rule or the workload differs.
tactics-ladder-reference: import ## Round 15 (squad P2): make tactics-ladder with the defaults, then keep build/tactics-ladder.json as tools/tactics/ladder_reference.json (the reference, its winner rule and commit inside; heavy: make remote T=tactics-ladder-reference, then copy build/tactics-ladder.json)
	$(MAKE) --no-print-directory tactics-ladder
	cp $(BUILD_DIR)/tactics-ladder.json $(BUILD_DIR)/ladder_reference.json
	@echo ">> tactics-ladder-reference: build/ladder_reference.json -- commit it as tools/tactics/ladder_reference.json"

tactics-pytest: ## Round 15 (squad): the tactics tools' own known-answer tests (the ladder's winner-rule refusal, the doctrine series' pairing); FAILS if it collected nothing
	@status=0; out=$$($(PYTHON) -m unittest discover -s tools/tactics -p 'test_*.py' -v 2>&1) || status=$$?; \
	echo "$$out" | tail -3; \
	ran=$$(echo "$$out" | grep -oE '^Ran [0-9]+ test' | grep -oE '[0-9]+' || echo 0); \
	echo "tactics-pytest: collected $$ran tests"; \
	[ "$$ran" -gt 0 ] && [ $$status -eq 0 ]

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

squad-doctrine-series: import ## Round 15 (squad P1): the gangs' flipped encircle/bait verdicts over seeds. The gang pack under four ARMS of its table (shipped = encircle off + bait on; encircle; nobait; both: built in memory, never written) vs OPPONENTS (guns chasers standard) on ARENAS (yard terminus lane), DOCTRINE_SEEDS="1 2 3 4 5 6 7 8", same seeds every arm, DOCTRINE_SECONDS=90 -> build/squad-doctrine.jsonl + build/squad-doctrine.json (heavy: make remote T=squad-doctrine-series)
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/squad-doctrine.jsonl
	@for opponent in $(or $(OPPONENTS),guns chasers standard); do for arena in $(or $(DOCTRINE_ARENAS),yard terminus lane); do for seed in $(or $(DOCTRINE_SEEDS),1 2 3 4 5 6 7 8); do for arm in shipped encircle nobait both; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/gang_probe.gd -- \
			--arm=$$arm --opponent=$$opponent --map=$$arena --seed=$$seed --seconds=$(or $(DOCTRINE_SECONDS),90) 2>&1 \
			| grep "^GANG_PROBE {" >> $(BUILD_DIR)/squad-doctrine.jsonl & \
		done; wait; done; done; done
	@$(PYTHON) tools/tactics/doctrine_series.py $(BUILD_DIR)/squad-doctrine.jsonl --json $(BUILD_DIR)/squad-doctrine.json

gang-probe: import ## Round 15 (squad P1): ONE cell of squad-doctrine-series: ARM=shipped|encircle|nobait|both OPPONENT=guns|chasers|standard ARENA=lane|yard|terminus SEED=1 DOCTRINE_SECONDS=90 (SEED=0 ARENA=lane = round 14's drill exactly)
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/gang_probe.gd -- \
		--arm=$(or $(ARM),shipped) --opponent=$(or $(OPPONENT),guns) --map=$(or $(ARENA),lane) --seed=$(call cmdline,SEED,1) \
		--seconds=$(or $(DOCTRINE_SECONDS),90) 2>&1 | grep -E "GANG_PROBE|SCRIPT ERROR|ERROR" || true

gang-trace: import ## Round 15 (squad P4): one unit's brain, tick by tick, in a gang_probe fight (default: round 14's drill, the eastern flanker 14-28 s): GANG_TRACE lines -> build/gang-trace.log. TRACE=Green_A_4 FROM=14 TO=28 EVERY=6 ARM= OPPONENT= ARENA=lane SEED=0
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/gang_probe.gd -- \
		--arm=$(or $(ARM),shipped) --opponent=$(or $(OPPONENT),guns) --map=$(or $(ARENA),lane) --seed=$(call cmdline,SEED,0) \
		--seconds=$(or $(DOCTRINE_SECONDS),30) --trace=$(or $(TRACE),Green_A_4) --trace-from=$(or $(FROM),14) --trace-to=$(or $(TO),28) \
		--trace-every=$(or $(EVERY),6) $(if $(FLANK_TURN_IN),--flank-turn-in=$(FLANK_TURN_IN)) 2>&1 | grep -E "GANG_TRACE|GANG_PROBE|SCRIPT ERROR|ERROR" | tee $(BUILD_DIR)/gang-trace.log || true

sim-hash-arm: import ## Round 15 (squad P4): the sim baseline's own match (SIM_HASH_READ's flags) with SIM_ARGS appended, read TWICE; prints SIM_HASH_ARM <args> <hash> <hash>. SIM_ARGS=--flank-turn-in=distance reads the pre-P4 turn-in (must equal 6313a38d7ecd99bb on builder0)
	@a=$$($(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --green-doctrine=res://doctrines/sim_baseline_green.json --rust-doctrine=res://doctrines/sim_baseline_rust.json --time-limit=40 --seed=3 $(SIM_ARGS) 2>/dev/null | grep MATCH_RESULT | $(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"); \
	b=$$($(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --green-doctrine=res://doctrines/sim_baseline_green.json --rust-doctrine=res://doctrines/sim_baseline_rust.json --time-limit=40 --seed=3 $(SIM_ARGS) 2>/dev/null | grep MATCH_RESULT | $(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"); \
	echo "SIM_HASH_ARM [$(SIM_ARGS)] $$a $$b glibc-$$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)"; [ -n "$$a" ] && [ "$$a" = "$$b" ]

# Round 18 (brains): the ELEMENT DIGEST — equal-answer proof for work on the element machinery (seating, slot grounding,
# plans, feeds). The sim baselines and ai-parity run no elements, so they cannot see such a change; this can. The settle
# probe as HIS element over a fixed set (squads x maps x seeds, his plain move and his attack-move), each run's md5 of
# what the element decided every tick (seats, slots, stations, anchor, formation, technique, drill, every crew's order),
# and one combined ELEMENT_DIGEST line. Same tree twice: identical (checked). DIGEST_MAPS, DIGEST_SEEDS, DIGEST_SECONDS.
DIGEST_MAPS ?= sumps parade yard terminus
DIGEST_SEEDS ?= 1 2
## Round 19 (B3): extra probe flags, e.g. DIGEST_FLAGS=--brains-off=ground_clear for a cut's old path on the same tree.
DIGEST_FLAGS ?=
DIGEST_SQUADS ?= law_tank:law_tank:law_tank:law_tank law_scout:law_scout:law_ifv:law_tank law_ifv:law_ifv:law_suppressor:law_tank scout:scout:ifv:tank
.PHONY: element-digest
element-digest: import ## Round 18: md5 of every element decision over tasked and plain moves (squads x DIGEST_MAPS x DIGEST_SEEDS) -> ELEMENT_DIGEST line (build/element-digest.txt)
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/element-digest.txt
	@for map in $(DIGEST_MAPS); do for squad in $(DIGEST_SQUADS); do for seed in $(DIGEST_SEEDS); do for drills in on off; do \
		d=$$($(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/settle_probe.gd -- \
			--arena=$$map --dir=forward --metres=150 --seed=$$seed --units=$$squad --seconds=$(or $(DIGEST_SECONDS),60) \
			--drills=$$drills --digest=on $(DIGEST_FLAGS) 2>/dev/null | grep -o '"element_digest":"[0-9a-f]*"' | cut -d'"' -f4); \
		echo "$$map $$squad seed=$$seed drills=$$drills $${d:-MISSING}" | tee -a $(BUILD_DIR)/element-digest.txt; \
	done; done; done; done
	@echo "ELEMENT_DIGEST $$(md5sum < $(BUILD_DIR)/element-digest.txt | cut -c1-32) ($$(wc -l < $(BUILD_DIR)/element-digest.txt) runs; $$(grep -c MISSING $(BUILD_DIR)/element-digest.txt) missing)"
	@! grep -q MISSING $(BUILD_DIR)/element-digest.txt

# Round 19 (brains B4): HIS attack-move (an element task with drills) 150 m forward for every squad of round 18's 80-run
# table, on ARRIVE_MAPS x ARRIVE_SEEDS, with MAKE_ROOM on and off on the same runs (Element.MAKE_ROOM_ENABLED).
# One SETTLE_PROBE line per run -> build/squad-arrive.jsonl; then a table: arrived k of n (median s), re-seats, swaps.
ARRIVE_MAPS ?= yard terminus pit sumps cut
ARRIVE_SEEDS ?= 1 2 3 4
ARRIVE_ARMS ?= on off
## Round 20 (M1): which switch the arms toggle (make-room, or converge: form up on the move) and whether the move is his
## attack-move (drills on: no travelling anchor) or a plain move (drills off: the anchor, where M1 lives).
ARRIVE_ARM_FLAG ?= make-room
ARRIVE_DRILLS ?= on
ARRIVE_SQUADS ?= scout:scout:ifv:tank law_scout:law_scout:law_ifv:law_tank law_scout:law_ifv:law_tank:law_tank law_ifv:law_ifv:law_suppressor:law_tank law_tank:law_tank:law_tank:law_tank
.PHONY: squad-arrive-series
squad-arrive-series: import ## Round 19 (B4): his attack-move 150 m for round 18's five squads x ARRIVE_MAPS x ARRIVE_SEEDS, MAKE_ROOM on/off -> build/squad-arrive.jsonl + table
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/squad-arrive.jsonl
	@echo ">> squad-arrive-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for map in $(ARRIVE_MAPS); do for squad in $(ARRIVE_SQUADS); do for seed in $(ARRIVE_SEEDS); do for arm in $(ARRIVE_ARMS); do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/settle_probe.gd -- \
			--arena=$$map --dir=forward --metres=150 --seed=$$seed --units=$$squad --seconds=$(or $(ARRIVE_SECONDS),120) \
			--drills=$(ARRIVE_DRILLS) --$(ARRIVE_ARM_FLAG)=$$arm 2>/dev/null | grep -o 'SETTLE_PROBE {.*' | sed "s/^SETTLE_PROBE {/{\"arm\":\"$$arm\",/" >> $(BUILD_DIR)/squad-arrive.jsonl \
			|| echo "{\"arm\":\"$$arm\",\"arena\":\"$$map\",\"units\":\"$$squad\",\"seed\":$$seed,\"missing\":true}" >> $(BUILD_DIR)/squad-arrive.jsonl; \
	done; done; done; done
	@$(PYTHON) tools/tactics/squad_arrive_table.py $(BUILD_DIR)/squad-arrive.jsonl $(ARRIVE_ARM_FLAG)

# Round 20 (brains M1, C20.3): orders' two-squad probe (READ-ONLY: game/control/two_squads_playtest.gd) on CONVERGE_MAPS,
# both arms of form-up-on-the-move (--converge=on|off) on the same tree and seed; its three selection shapes (selected,
# grouped, single) per run; then the worst away-from-the-click and worst off-line in the first 5 s, per case and arm.
CONVERGE_MAPS ?= parade sumps
CONVERGE_ARMS ?= on off
## The probe runs in real time, so one run is not repeatable: each arm runs CONVERGE_REPS times (the table lists each).
CONVERGE_REPS ?= 1
CONVERGE_DIR := build/converge-probe
.PHONY: converge-probe
converge-probe: import ## Round 20 (M1): orders' two-squad probe on CONVERGE_MAPS (parade sumps) x --converge=CONVERGE_ARMS (on off; leadN) x CONVERGE_REPS -> build/converge-probe/<map>-<arm>-r<rep>/two_squads.json + a table (worst away / off-line in 5 s)
	@rm -rf $(CONVERGE_DIR); mkdir -p $(CONVERGE_DIR)
	@echo ">> converge-probe on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for rep in $$(seq 1 $(CONVERGE_REPS)); do for map in $(CONVERGE_MAPS); do for arm in $(CONVERGE_ARMS); do \
		d=$(CURDIR)/$(CONVERGE_DIR)/$$map-$$arm-r$$rep; mkdir -p $$d; s=0; \
		timeout 240 $(GODOT) --headless --path . -- --skirmish --enemy=cpu --seed=3 --control-playtest=$$d --two-squads \
			$(TWO_ARMY) --arena=$$map --converge=$$arm > $$d/run.log 2>&1 || s=$$?; \
		echo "$$map converge=$$arm rep $$rep: exit $$s $$(grep -o 'TWO_SQUADS_DONE ok=[a-z]*' $$d/run.log || true)"; \
	done; done; done
	@$(PYTHON) tools/tactics/converge_table.py $(CONVERGE_DIR)

# Round 20 (brains M2): THE OPENING, paired. tests/tactics/opening_probe.gd (both sides from their spawns, 0 to 0, his
# eight vehicles setting off at once toward the CPU's near ring) on OPENING_MAPS x OPENING_SEEDS, --opening=on|off on the
# same seeds and tree -> build/opening-series.jsonl and a table (ambushes taken / sprung, refusals, losses, score; the
# per-seed difference with its spread).
OPENING_MAPS ?= parade sumps
OPENING_SEEDS ?= 1 2 3 4 5 6 7 8
OPENING_ARGS ?=
.PHONY: opening-series
opening-series: import ## Round 20 (M2): the CPU's opening from the spawns, --opening=on|off paired over OPENING_SEEDS on OPENING_MAPS (parade sumps); OPENING_ARGS="--his-to=x,z --seconds=120" -> build/opening-series.jsonl + table
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/opening-series.jsonl
	@echo ">> opening-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for map in $(OPENING_MAPS); do for seed in $(OPENING_SEEDS); do for arm in on off; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/opening_probe.gd -- \
			--arena=$$map --seed=$$seed --opening=$$arm $(OPENING_ARGS) 2>/dev/null | grep -o 'OPENING_PROBE {.*' | sed 's/^OPENING_PROBE //' >> $(BUILD_DIR)/opening-series.jsonl \
			|| echo "{\"arena\":\"$$map\",\"seed\":$$seed,\"opening\":\"$$arm\",\"missing\":true}" >> $(BUILD_DIR)/opening-series.jsonl; \
	done; done; done
	@$(PYTHON) tools/tactics/opening_table.py $(BUILD_DIR)/opening-series.jsonl

# Round 20 (brains M3): the ambush hides the LINE. Round 19's hold stage (tests/tactics/hold_probe.gd: the CPU on its
# depot and ahead, his line crossing the floor toward it) on HIDES_MAPS x HIDES_SEEDS, --hides=line|point paired:
# when and where the ambush springs, what each side lost -> build/hides-series.jsonl + table.
HIDES_MAPS ?= parade yard_open
HIDES_SEEDS ?= 1 2 3 4 5 6 7 8
.PHONY: hides-series
hides-series: import ## Round 20 (M3): round 19's hold stage, --hides=line|point paired over HIDES_SEEDS on HIDES_MAPS (parade yard_open) -> build/hides-series.jsonl + table
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/hides-series.jsonl
	@echo ">> hides-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for map in $(HIDES_MAPS); do for seed in $(HIDES_SEEDS); do for arm in line point; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/hold_probe.gd -- \
			--arena=$$map --seed=$$seed --hides=$$arm --seconds=60 2>/dev/null | grep -o 'HOLD_PROBE {.*' | sed 's/^HOLD_PROBE //' >> $(BUILD_DIR)/hides-series.jsonl \
			|| echo "{\"arena\":\"$$map\",\"seed\":$$seed,\"hides\":\"$$arm\",\"missing\":true}" >> $(BUILD_DIR)/hides-series.jsonl; \
	done; done; done
	@$(PYTHON) tools/tactics/hides_table.py $(BUILD_DIR)/hides-series.jsonl

# Round 21 (brains P2): an attack on a target that RUNS (tests/tactics/pursuit_probe.gd: his gang scouts, two squads of
# five, on the Syndicate's spotter; its pair under the CPU's squad leader) on PURSUIT_MAPS x PURSUIT_SEEDS,
# --pursuit=on|off paired: the target killed and when, what each side lost -> build/pursuit-series.jsonl + table.
PURSUIT_MAPS ?= yard_open foundry
PURSUIT_SEEDS ?= 1 2 3 4 5 6 7 8
PURSUIT_SECONDS ?= 60
## Extra probe flags for every run (round 24: --l1=... for L1's paired series).
PURSUIT_EXTRA ?=
.PHONY: pursuit-series
pursuit-series: import ## Round 21 (P2): his scouts attack a Syndicate spotter that runs, --pursuit=on|off paired over PURSUIT_SEEDS on PURSUIT_MAPS (yard_open foundry) -> build/pursuit-series.jsonl + table
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/pursuit-series.jsonl
	@echo ">> pursuit-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for map in $(PURSUIT_MAPS); do for seed in $(PURSUIT_SEEDS); do for arm in on off; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/pursuit_probe.gd -- \
			--arena=$$map --seed=$$seed --pursuit=$$arm --seconds=$(PURSUIT_SECONDS) $(PURSUIT_EXTRA) 2>/dev/null | grep -o 'PURSUIT_PROBE {.*' | sed 's/^PURSUIT_PROBE //' >> $(BUILD_DIR)/pursuit-series.jsonl \
			|| echo "{\"arena\":\"$$map\",\"seed\":$$seed,\"pursuit\":\"$$arm\",\"missing\":true}" >> $(BUILD_DIR)/pursuit-series.jsonl; \
	done; done; done
	@$(PYTHON) tools/tactics/pursuit_table.py $(BUILD_DIR)/pursuit-series.jsonl $(PURSUIT_SECONDS)

# Round 21 (brains P2): the pursuit in pictures, top-down with every vehicle's trail, --pursuit=on and off, at his window
# and the phone's aspect -> build/tactics-shots/<size>/pursuit_{on,off}_NNs.png (needs a display: make remote T=pursuit-shots).
# The engine's exit code is judged first; the last grep only echoes what each frame shows (exit 1 = no such line, not a
# failure: the frame check is TACTICS_SHOTS_DONE above it).
PURSUIT_SHOT_SIZES ?= 1920x1080 1200x540
.PHONY: pursuit-shots
pursuit-shots: import ## Round 21 (P2): his scouts chasing a spotter that runs, top-down with trails, both arms at his window and phone aspect -> build/tactics-shots/<size>/pursuit_*.png (needs a display)
	@for size in $(PURSUIT_SHOT_SIZES); do for arm in on off; do \
		mkdir -p $(BUILD_DIR)/tactics-shots/$$size; \
		s=0; timeout 300 $(GODOT) --path . --fixed-fps $(SIM_HZ) --resolution $$size --script res://tests/tactics/tactics_shots.gd -- \
			--stage=pursuit --pursuit=$$arm > $(BUILD_DIR)/tactics-shots/$$size/pursuit_$$arm.log 2>&1 || s=$$?; \
		[ $$s -eq 0 ] || { echo "pursuit-shots $$size $$arm: exited $$s"; tail -5 $(BUILD_DIR)/tactics-shots/$$size/pursuit_$$arm.log; exit 1; }; \
		grep -q TACTICS_SHOTS_DONE $(BUILD_DIR)/tactics-shots/$$size/pursuit_$$arm.log; \
		! grep -E "SCRIPT ERROR|^ERROR" $(BUILD_DIR)/tactics-shots/$$size/pursuit_$$arm.log; \
		for f in $(BUILD_DIR)/tactics-shots/pursuit_$${arm}_*.png; do mv $$f $(BUILD_DIR)/tactics-shots/$$size/; done; \
		grep TACTICS_SHOT $(BUILD_DIR)/tactics-shots/$$size/pursuit_$$arm.log | grep -v png || true; \
	done; done

# Round 21 (brains stretch a): a holding element that is LOSING ITS TRADE falls back one bound toward its zone. Round
# 19's hold stage (tests/tactics/hold_probe.gd) on FALLBACK_MAPS x FALLBACK_SEEDS, --fallback=on|off paired ->
# build/fallback-series.jsonl + table.
FALLBACK_MAPS ?= parade yard_open
FALLBACK_SEEDS ?= 1 2 3 4 5 6 7 8
.PHONY: fallback-series
fallback-series: import ## Round 21 (stretch a): round 19's hold stage, --fallback=on|off paired over FALLBACK_SEEDS on FALLBACK_MAPS (parade yard_open) -> build/fallback-series.jsonl + table
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/fallback-series.jsonl
	@echo ">> fallback-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for map in $(FALLBACK_MAPS); do for seed in $(FALLBACK_SEEDS); do for arm in on off; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/hold_probe.gd -- \
			--arena=$$map --seed=$$seed --fallback=$$arm --seconds=60 2>/dev/null | grep -o 'HOLD_PROBE {.*' | sed 's/^HOLD_PROBE //' >> $(BUILD_DIR)/fallback-series.jsonl \
			|| echo "{\"arena\":\"$$map\",\"seed\":$$seed,\"fallback\":\"$$arm\",\"missing\":true}" >> $(BUILD_DIR)/fallback-series.jsonl; \
	done; done; done
	@$(PYTHON) tools/tactics/fallback_table.py $(BUILD_DIR)/fallback-series.jsonl

# Round 22 (brains B1, DECLARED): a crew under fire it cannot return leaves its post (UnansweredFire). Round 19's hold
# stage (tests/tactics/hold_probe.gd: the CPU on its depot, his four Law tanks crossing) on DUCK_MAPS x DUCK_SEEDS,
# --duck=on|off paired: alive, loss and score margin -> build/duck-series.jsonl + table.
# Two stages: `law` is round 19's (his four Law tanks: nobody is out-ranged, so it must come out unchanged) and `lancers`
# his recording's matchup (his Lancers, a tank and an IFV, setting off at once, v four Syndicate holders without the
# railgun: the CPU's crews are the ones lased from beyond their reach).
DUCK_MAPS ?= parade foundry
DUCK_SEEDS ?= 1 2 3 4 5 6 7 8
DUCK_STAGES ?= law lancers
## Extra hold_probe flags for every run (e.g. DUCK_EXTRA=--duck-leash=20: outcome (a)'s leash, a measurement arm).
DUCK_EXTRA ?=
## Round 23 (B3): which switch the arms toggle: duck (round 22's rule itself) or duck-urgent (acting inside the grace).
DUCK_ARM_FLAG ?= duck
DUCK_STAGE_law :=
DUCK_STAGE_lancers := --his-units=lancer,lancer,tank,ifv --cpu-units=syn_ifv,syn_ifv,syn_scout,syn_ifv --his-delay=0
.PHONY: duck-series
duck-series: import ## Round 22 (B1): round 19's hold stage (DUCK_STAGES law lancers), --duck=on|off paired over DUCK_SEEDS on DUCK_MAPS (parade foundry) -> build/duck-series.jsonl + table
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/duck-series.jsonl
	@echo ">> duck-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@$(foreach stage,$(DUCK_STAGES),for map in $(DUCK_MAPS); do for seed in $(DUCK_SEEDS); do for arm in on off; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/hold_probe.gd -- $(DUCK_STAGE_$(stage)) $(DUCK_EXTRA) \
			--arena=$$map --seed=$$seed --$(DUCK_ARM_FLAG)=$$arm --seconds=60 2>/dev/null | grep -o 'HOLD_PROBE {.*' | sed "s/^HOLD_PROBE {/{\"arm\":\"$$arm\",/" >> $(BUILD_DIR)/duck-series.jsonl \
			|| echo "{\"arena\":\"$$map\",\"seed\":$$seed,\"duck\":\"$$arm\",\"missing\":true}" >> $(BUILD_DIR)/duck-series.jsonl; \
	done; done; done;)
	@$(PYTHON) tools/tactics/duck_table.py $(BUILD_DIR)/duck-series.jsonl

# Round 22 (brains B1): his recording's stage (tests/tactics/duck_probe.gd: the gunship on its ambush post, Lancers lasing
# it from 84 m) over DUCK_STAGE_SEEDS x lancers 1..3 x side cpu/his, --duck=on|off -> build/duck-stage.jsonl + table.
DUCK_STAGE_SEEDS ?= 1 2 3 4
## Round 23 (B3): which switch the arms toggle: duck (round 22's rule itself) or duck-urgent (acting inside the grace).
DUCK_STAGE_ARM_FLAG ?= duck
.PHONY: duck-stage-series
duck-stage-series: import ## Round 22 (B1): his recording's gunship under a Lancer's laser, --duck=on|off x 1-3 Lancers x side cpu|his over DUCK_STAGE_SEEDS -> build/duck-stage.jsonl + table
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/duck-stage.jsonl
	@echo ">> duck-stage-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for side in cpu his; do for lancers in 1 2 3; do for seed in $(DUCK_STAGE_SEEDS); do for arm in on off; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/duck_probe.gd -- \
			--side=$$side --lancers=$$lancers --seed=$$seed --$(DUCK_STAGE_ARM_FLAG)=$$arm --seconds=30 2>/dev/null | grep -o 'DUCK_PROBE {.*' | sed "s/^DUCK_PROBE {/{\"arm\":\"$$arm\",/" >> $(BUILD_DIR)/duck-stage.jsonl \
			|| echo "{\"side\":\"$$side\",\"lancers\":$$lancers,\"seed\":$$seed,\"duck\":\"$$arm\",\"missing\":true}" >> $(BUILD_DIR)/duck-stage.jsonl; \
	done; done; done; done
	@$(PYTHON) tools/tactics/duck_table.py $(BUILD_DIR)/duck-stage.jsonl

# Round 22 (brains B2): the computer's squad leaders at TEN SQUADS A SIDE. A CPU-v-CPU fight of two garage armies at
# ARMY_CREDITS (ten squads of five) on ARMY_MAPS x ARMY_SEEDS x ARMY_PAIRS (green:rust factions), both sides commanded
# by ElementCommander, to a result: elements <= 10 a side, none over 5, every vehicle inside the arena, no error lines
# -> build/army-series.jsonl + table. FAILS on an error line, a missing run, or a broken invariant.
ARMY_MAPS ?= parade foundry
ARMY_SEEDS ?= 1 2
ARMY_PAIRS ?= gangs:gangs gangs:law condemned:syndicate
ARMY_CREDITS ?= 2000
ARMY_SECONDS ?= 240
ARMY_KINDS ?= opponent full
## Extra probe flags for every run (round 24: --l1=... for L1's win-rate symmetry series).
ARMY_EXTRA ?=
.PHONY: army-series
army-series: import ## Round 22 (B2): CPU v CPU at ten squads a side (ARMY_CREDITS 2000), ARMY_MAPS x ARMY_SEEDS x ARMY_PAIRS -> build/army-series.jsonl + table; fails on an error line or a broken invariant
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/army-series.jsonl; : > $(BUILD_DIR)/army-series.errors
	@echo ">> army-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for kind in $(ARMY_KINDS); do for map in $(ARMY_MAPS); do for seed in $(ARMY_SEEDS); do for pair in $(ARMY_PAIRS); do \
		g=$${pair%%:*}; r=$${pair##*:}; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/army_probe.gd -- \
			--arena=$$map --seed=$$seed --green=$$g --rust=$$r --credits=$(ARMY_CREDITS) --army=$$kind --seconds=$(ARMY_SECONDS) $(ARMY_EXTRA) \
			> $(BUILD_DIR)/army-series.run.log 2>&1 || true; \
		{ grep -E "SCRIPT ERROR|^ERROR|USER ERROR" $(BUILD_DIR)/army-series.run.log || true; } | sed "s|^|$$kind $$map $$seed $$pair: |" >> $(BUILD_DIR)/army-series.errors; \
		grep -o 'ARMY_PROBE {.*' $(BUILD_DIR)/army-series.run.log | sed 's/^ARMY_PROBE //' >> $(BUILD_DIR)/army-series.jsonl \
			|| echo "{\"arena\":\"$$map\",\"seed\":$$seed,\"army\":\"$$kind\",\"green\":\"$$g\",\"rust\":\"$$r\",\"missing\":true}" >> $(BUILD_DIR)/army-series.jsonl; \
	done; done; done; done
	@$(PYTHON) tools/tactics/army_table.py $(BUILD_DIR)/army-series.jsonl $(BUILD_DIR)/army-series.errors

# Round 22 (brains B4): the Syndicate-over-gangs range gap, MEASURED for him (no price moves, C12.6). Both sides under
# their own doctrine's default behaviour (the computer's squad leader each): GAP_CASES squad (10 Rat Rods v 4 Syndicate)
# and spotter (5 Rat Rods v 1 spotter platform) on GAP_MAPS x GAP_SEEDS, --duck=on|off (B1 before/after) ->
# build/gap-series.jsonl + table.
GAP_MAPS ?= yard_open parade
GAP_SEEDS ?= 1 2 3 4 5 6 7 8
GAP_CASES ?= squad spotter
.PHONY: gap-series
gap-series: import ## Round 22 (B4): 10 Rat Rods v 4 Syndicate and 5 Rat Rods v 1 spotter, both sides on their doctrine, --duck=on|off over GAP_SEEDS on GAP_MAPS -> build/gap-series.jsonl + table
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/gap-series.jsonl
	@echo ">> gap-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for c in $(GAP_CASES); do for map in $(GAP_MAPS); do for seed in $(GAP_SEEDS); do for arm in on off; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/gap_probe.gd -- \
			--case=$$c --arena=$$map --seed=$$seed --duck=$$arm --seconds=90 2>/dev/null | grep -o 'GAP_PROBE {.*' | sed 's/^GAP_PROBE //' >> $(BUILD_DIR)/gap-series.jsonl \
			|| echo "{\"case\":\"$$c\",\"arena\":\"$$map\",\"seed\":$$seed,\"duck\":\"$$arm\",\"missing\":true}" >> $(BUILD_DIR)/gap-series.jsonl; \
	done; done; done; done
	@$(PYTHON) tools/tactics/gap_table.py $(BUILD_DIR)/gap-series.jsonl

# Round 22 (brains B1): his recording's gunship in pictures, top-down with trails, --duck=on and off, one Lancer (it
# closes) and two (it takes cover), at his window and the phone's aspect -> build/tactics-shots/<size>/duck_*.png (needs a
# display: make remote T=duck-shots).
DUCK_SHOT_SIZES ?= 1920x1080 1200x540
.PHONY: duck-shots
duck-shots: import ## Round 22 (B1): the gunship under a Lancer's laser, top-down with trails, both arms, 1 and 2 Lancers, his window and phone aspect -> build/tactics-shots/<size>/duck_*.png (needs a display)
	@for size in $(DUCK_SHOT_SIZES); do for arm in on off; do for n in 1 2; do \
		mkdir -p $(BUILD_DIR)/tactics-shots/$$size; \
		s=0; timeout 300 $(GODOT) --path . --fixed-fps $(SIM_HZ) --resolution $$size --script res://tests/tactics/tactics_shots.gd -- \
			--stage=duck --duck=$$arm --lancers=$$n > $(BUILD_DIR)/tactics-shots/$$size/duck_$${arm}_$$n.log 2>&1 || s=$$?; \
		[ $$s -eq 0 ] || { echo "duck-shots $$size $$arm $$n: exited $$s"; tail -5 $(BUILD_DIR)/tactics-shots/$$size/duck_$${arm}_$$n.log; exit 1; }; \
		grep -q TACTICS_SHOTS_DONE $(BUILD_DIR)/tactics-shots/$$size/duck_$${arm}_$$n.log; \
		! grep -E "SCRIPT ERROR|^ERROR" $(BUILD_DIR)/tactics-shots/$$size/duck_$${arm}_$$n.log; \
		for f in $(BUILD_DIR)/tactics-shots/duck_$${arm}*.png; do mv $$f $(BUILD_DIR)/tactics-shots/$$size/; done; \
		grep TACTICS_SHOT $(BUILD_DIR)/tactics-shots/$$size/duck_$${arm}_$$n.log | grep -v png || true; \
	done; done; done

# Round 23 (brains B0/B1): HIS CASE (tests/tactics/pace_probe.gd / pace_stage.gd: a line whose own axis points at the
# click, one crew already nearest it) over PACE_CASES (arena,units,metres,layout[,shape]; "" arena = the parade ground's
# open middle) x PACE_SEEDS x --pace=PACE_ARMS -> build/pace-series.jsonl + a table (tools/tactics/pace_table.py):
# formed_m (the anchor's progress when every crew was within 3 m of its shape station), rms, the lead crew's speed and
# pace over 10 s, the anchor's lowest pace, crews that stopped dead, arrived / in-slot / stopped times. A missing row
# fails the target. PACE_TRACE=on prints PACE_TRACK lines for one run (tools/tactics/plot_tracks.py reads them).
PACE_SEEDS ?= 1 2 3
PACE_ARMS ?= on off
PACE_CASES ?= ,law_tank:law_tank:law_tank:law_tank:law_tank,150,along,line \
	,law_scout:law_scout:law_ifv:law_tank:law_tank,150,along,line \
	,law_tank:law_tank:law_tank:law_tank:law_tank,150,along,wedge \
	yard,law_tank:law_tank:law_tank:law_tank:law_tank,100,across,line \
	yard,scout:scout:ifv:ifv:tank,100,across,wedge
.PHONY: pace-series
pace-series: import ## Round 23 (B0/B1): his line-along-its-axis case, PACE_CASES x PACE_SEEDS x --pace=PACE_ARMS -> build/pace-series.jsonl + table
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/pace-series.jsonl
	@echo ">> pace-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for case in $(PACE_CASES); do IFS=, read -r arena units metres layout shape <<< "$$case"; for seed in $(PACE_SEEDS); do for arm in $(PACE_ARMS); do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/pace_probe.gd -- \
			--arena=$$arena --units=$$units --metres=$$metres --layout=$$layout --shape=$$shape --seed=$$seed --pace=$$arm --seconds=$(or $(PACE_SECONDS),90) $(PACE_FLAGS) 2>/dev/null | grep -o 'PACE_PROBE {.*' | sed 's/^PACE_PROBE //' >> $(BUILD_DIR)/pace-series.jsonl \
			|| echo "{\"arena\":\"$$arena\",\"units\":\"$$units\",\"metres\":$$metres,\"layout\":\"$$layout\",\"shape\":\"$$shape\",\"seed\":$$seed,\"pace\":\"$$arm\",\"missing\":true}" >> $(BUILD_DIR)/pace-series.jsonl; \
	done; done; done
	@$(PYTHON) tools/tactics/pace_table.py $(BUILD_DIR)/pace-series.jsonl

.PHONY: pace-trace
pace-trace: import ## Round 23: one run of his case with PACE_TRACK lines -> build/pace-trace.log (PACE_ARM=on|off, PACE_SEED, PACE_ARENA, PACE_UNITS, PACE_METRES, PACE_LAYOUT, PACE_SHAPE)
	@mkdir -p $(BUILD_DIR)
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/pace_probe.gd -- \
		--arena=$(PACE_ARENA) --units=$(or $(PACE_UNITS),law_tank:law_tank:law_tank:law_tank:law_tank) --metres=$(or $(PACE_METRES),150) \
		--layout=$(or $(PACE_LAYOUT),along) --shape=$(or $(PACE_SHAPE),line) --seed=$(or $(PACE_SEED),1) --pace=$(or $(PACE_ARM),on) \
		--seconds=$(or $(PACE_SECONDS),90) --trace=on $(PACE_FLAGS) > $(BUILD_DIR)/pace-trace.log 2>&1 || true
	@grep -o 'PACE_PROBE {.*' $(BUILD_DIR)/pace-trace.log || (echo "pace-trace: no PACE_PROBE line" && exit 1)

.PHONY: duck-trace
duck-trace: import ## Round 23 (B3): one traced run of his recording's stage (DUCK_SIDE cpu|his, DUCK_LANCERS, DUCK_SEED, DUCK_ARM_FLAG=duck|duck-urgent, DUCK_TRACE_ARM on|off) -> build/duck-trace.log
	@mkdir -p $(BUILD_DIR)
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/duck_probe.gd -- \
		--side=$(or $(DUCK_SIDE),cpu) --lancers=$(or $(DUCK_LANCERS),3) --seed=$(or $(DUCK_SEED),1) --$(DUCK_ARM_FLAG)=$(or $(DUCK_TRACE_ARM),on) \
		--seconds=$(or $(DUCK_SECONDS),30) --trace=on > $(BUILD_DIR)/duck-trace.log 2>&1 || true
	@grep -o 'DUCK_PROBE {.*' $(BUILD_DIR)/duck-trace.log || (echo "duck-trace: no DUCK_PROBE line" && exit 1)

# Round 24 (brains R0/R1): HIS BRIDGE CASE (tests/tactics/bridge_probe.gd / bridge_stage.gd: a squad on one bank of the
# Locks attack-moved to the far quay, guns on the far bank) over BRIDGE_CASES (arena,side,guns) x BRIDGE_SEEDS ->
# build/bridge-series.jsonl + one line per run: crews pressed at the water (rim_crews, rim_total_s), straight-line hops
# whose leg crosses water (wet_hops), crews that crossed. BRIDGE_FLAGS adds probe flags (e.g. --brains-off=native).
BRIDGE_SEEDS ?= 1 2 3
BRIDGE_CASES ?= locks,green,3 locks,rust,3 locks,green,0 locks_dry,green,3
BRIDGE_UNITS ?= law_tank:law_tank:law_tank:law_tank
BRIDGE_ARMS ?= on off
.PHONY: bridge-series
bridge-series: import ## Round 24 (R0/R1): his bridge case, BRIDGE_CASES (arena,side,guns) x BRIDGE_SEEDS -> build/bridge-series.jsonl (rim_crews, wet_hops, crossed)
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/bridge-series.jsonl
	@echo ">> bridge-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for case in $(BRIDGE_CASES); do IFS=, read -r arena side guns <<< "$$case"; for seed in $(BRIDGE_SEEDS); do for arm in $(BRIDGE_ARMS); do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/bridge_probe.gd -- \
			--arena=$$arena --side=$$side --guns=$$guns --seed=$$seed --units=$(BRIDGE_UNITS) --seconds=$(or $(BRIDGE_SECONDS),90) --wet-ground=$$arm $(BRIDGE_FLAGS) 2>/dev/null \
			| grep -o 'BRIDGE_PROBE {.*' | sed 's/^BRIDGE_PROBE //' >> $(BUILD_DIR)/bridge-series.jsonl \
			|| echo "{\"arena\":\"$$arena\",\"side\":\"$$side\",\"guns\":$$guns,\"seed\":$$seed,\"wet_ground\":\"$$arm\",\"missing\":true}" >> $(BUILD_DIR)/bridge-series.jsonl; \
	done; done; done
	@$(PYTHON) -c "import json,sys; rows=[json.loads(l) for l in open('$(BUILD_DIR)/bridge-series.jsonl') if l.strip()]; \
		[print('BRIDGE %-10s %-5s guns=%s seed=%s wet=%-3s ' % (r.get('arena'), r.get('side'), r.get('guns'), r.get('seed'), r.get('wet_ground')) + ('MISSING' if r.get('missing') else 'rim_crews=%d rim_total_s=%.1f deck_jam_s=%.1f wet_hops=%d crossed=%d/%d alive=%d arrived_s=%.1f' % (r['rim_crews'], r['rim_total_s'], r.get('deck_jam_s', -1), r['wet_hops'], r['crossed'], r['crews'], r['alive'], r['arrived_s']))) for r in rows]; \
		sys.exit(1 if any(r.get('missing') for r in rows) else 0)"

.PHONY: bridge-trace
bridge-trace: import ## Round 24: one traced run of his bridge case (BRIDGE_ARENA=locks BRIDGE_SIDE=green BRIDGE_GUNS=3 BRIDGE_SEED=1) -> build/bridge-trace.log (BRIDGE_TRACK lines)
	@mkdir -p $(BUILD_DIR)
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/bridge_probe.gd -- \
		--arena=$(or $(BRIDGE_ARENA),locks) --side=$(or $(BRIDGE_SIDE),green) --guns=$(or $(BRIDGE_GUNS),3) --seed=$(or $(BRIDGE_SEED),1) \
		--units=$(BRIDGE_UNITS) --seconds=$(or $(BRIDGE_SECONDS),90) --trace=on --wet-ground=$(or $(BRIDGE_ARM),on) $(BRIDGE_FLAGS) > $(BUILD_DIR)/bridge-trace.log 2>&1 || true
	@grep -o 'BRIDGE_PROBE {.*' $(BUILD_DIR)/bridge-trace.log || (echo "bridge-trace: no BRIDGE_PROBE line" && tail -30 $(BUILD_DIR)/bridge-trace.log && exit 1)

.PHONY: tactics-script
tactics-script: import ## Run one tests/tactics script headless (TSCRIPT=name without .gd, TARGS=user args) -> stdout
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/$(TSCRIPT).gd -- $(TARGS) 2>&1 | grep -v "^\s*$$" | tail -200

# Round 24 (brains R1): his bridge case in frames, top-down with trails (--pose=his: his camera following the squad),
# both arms (--wet-ground=on|off) at his window and the phone aspect -> build/tactics-shots/<size>/bridge_<arm>_*.png
BRIDGE_SHOT_SIZES ?= 1600x900 1080x2340
.PHONY: bridge-shots
bridge-shots: import ## Round 24 (R1): his bridge case, top-down with trails, --wet-ground=on|off at his window and phone aspect -> build/tactics-shots/<size>/bridge_*.png (needs a display; BRIDGE_SHOT_FLAGS=--pose=his or --side=rust)
	@for size in $(BRIDGE_SHOT_SIZES); do for arm in on off; do \
		mkdir -p $(BUILD_DIR)/tactics-shots/$$size; \
		s=0; timeout 400 $(GODOT) --path . --fixed-fps $(SIM_HZ) --resolution $$size --script res://tests/tactics/tactics_shots.gd -- \
			--stage=bridge --wet-ground=$$arm $(BRIDGE_SHOT_FLAGS) > $(BUILD_DIR)/tactics-shots/$$size/bridge_$$arm.log 2>&1 || s=$$?; \
		[ $$s -eq 0 ] || { echo "bridge-shots $$size $$arm: exited $$s"; tail -5 $(BUILD_DIR)/tactics-shots/$$size/bridge_$$arm.log; exit 1; }; \
		grep -q TACTICS_SHOTS_DONE $(BUILD_DIR)/tactics-shots/$$size/bridge_$$arm.log; \
		! grep -E "SCRIPT ERROR|^ERROR" $(BUILD_DIR)/tactics-shots/$$size/bridge_$$arm.log; \
		for f in $(BUILD_DIR)/tactics-shots/bridge_$${arm}*.png; do mv $$f $(BUILD_DIR)/tactics-shots/$$size/; done; \
		grep TACTICS_SHOT $(BUILD_DIR)/tactics-shots/$$size/bridge_$$arm.log | grep -v png || true; \
	done; done

# Round 24 (brains R2): HIS three-squad move (tests/tactics/body_probe.gd / body_stage.gd) x BODY_SEEDS x --body=on|off
# x BODY_SIDES -> build/body-series.jsonl + one line per run (CoherenceProbe's alone_s and widest gap, each squad's route
# choice, the last arrival).
BODY_SEEDS ?= 1 2 3 4 5 6
BODY_SIDES ?= green rust cpu-green cpu-rust
BODY_EXTRA ?=
.PHONY: body-series
body-series: import ## Round 24 (R2): his three squads moved together on the Locks, --body=on|off x BODY_SEEDS x BODY_SIDES -> build/body-series.jsonl
	@mkdir -p $(BUILD_DIR); : > $(BUILD_DIR)/body-series.jsonl
	@echo ">> body-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for side in $(BODY_SIDES); do for seed in $(BODY_SEEDS); do for arm in on off; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/body_probe.gd -- \
			--seed=$$seed --body=$$arm --side=$$side --seconds=$(or $(BODY_SECONDS),90) $(BODY_EXTRA) 2>/dev/null \
			| grep -o 'BODY_PROBE {.*' | sed 's/^BODY_PROBE //' >> $(BUILD_DIR)/body-series.jsonl \
			|| echo "{\"seed\":$$seed,\"side\":\"$$side\",\"body\":\"$$arm\",\"missing\":true}" >> $(BUILD_DIR)/body-series.jsonl; \
	done; done; done
	@$(PYTHON) -c "import json,sys; rows=[json.loads(l) for l in open('$(BUILD_DIR)/body-series.jsonl') if l.strip()]; \
		[print('BODY %-5s seed=%s body=%-3s ' % (r.get('side'), r.get('seed'), r.get('body')) + ('MISSING' if r.get('missing') else 'alone_s=%.1f widest_gap_m=%.1f arrived_s=%.1f | %s' % (r['alone_s'], r['widest_gap_m'], r['arrived_s'], ' '.join('%s:%s/%s' % (k, (r[k]['choice'] or {}).get('chosen', '-'), r[k]['arrived_s']) for k in ('Sirens', 'Hunters', 'Hunters2'))))) for r in rows]; \
		sys.exit(1 if any(r.get('missing') for r in rows) else 0)"
