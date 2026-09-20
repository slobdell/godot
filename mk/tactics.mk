# Elements, doctrine tables and battle drills (doctrine stream; _agents/doctrine.md).
# Owner: doctrine (see _agents/workstreams.md). Included by the root Makefile.

tactics-test: import ## The doctrine stream's tests (formations, tables, drills, elements, scenarios)
	$(MAKE) --no-print-directory test FILTER=tactics

tactics-drills: import ## Seeded battle-drill scenarios, faster than real time: every drill fires on its trigger
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/run_tactics.gd -- --drills $(if $(FILTER),--filter=$(FILTER)) \
		2>&1 | tee $(BUILD_DIR)/tactics-drills.log | grep -E "TACTICS|ERROR" || true
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
