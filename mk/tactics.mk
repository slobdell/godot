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
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/run_parity.gd -- $(if $(SECONDS),--seconds=$(SECONDS)) \
		2>&1 | tee $(BUILD_DIR)/tactics-parity.log | grep -E "PARITY|ERROR" || true
	grep -q PARITY_DONE $(BUILD_DIR)/tactics-parity.log

doctrine-page: ## The lead's read-only doctrine view: every table, its rules and its drill numbers -> build/doctrine/index.html
	$(PYTHON) tools/tactics/doctrine_page.py --out $(BUILD_DIR)/doctrine
