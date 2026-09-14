# Commanding: tactical map, camera, readability
# Owner: command (see _agents/workstreams.md). Included by the root Makefile.

COMMAND_PLAYTEST_DIR := $(BUILD_DIR)/command-playtest

command-playtest: import ## Headless: tap each squad, order it off screen via the radar, check the camera frames it (log: build/command-playtest/camera.jsonl)
	rm -rf $(COMMAND_PLAYTEST_DIR) && mkdir -p $(COMMAND_PLAYTEST_DIR)
	$(GODOT) --headless --path . -- --skirmish --enemy=cpu --seed=3 --command-playtest=$(CURDIR)/$(COMMAND_PLAYTEST_DIR) 2>&1 \
		| tee $(COMMAND_PLAYTEST_DIR)/run.log | grep -E 'COMMAND_PLAYTEST|SCRIPT ERROR|ERROR' || true
	grep -q 'COMMAND_PLAYTEST_DONE ok=true' $(COMMAND_PLAYTEST_DIR)/run.log
	! grep -E 'SCRIPT ERROR|^ERROR' $(COMMAND_PLAYTEST_DIR)/run.log

command-playtest-shots: import ## The same playtest in a phone-sized window, saving camera frames to build/command-playtest/*.png (needs a display)
	rm -rf $(COMMAND_PLAYTEST_DIR) && mkdir -p $(COMMAND_PLAYTEST_DIR)
	$(GODOT) --path . --resolution 1200x540 -- --skirmish --enemy=cpu --seed=3 --command-playtest=$(CURDIR)/$(COMMAND_PLAYTEST_DIR) 2>&1 \
		| tee $(COMMAND_PLAYTEST_DIR)/run.log | grep -E 'COMMAND_PLAYTEST|SCRIPT ERROR' || true
	grep -q 'COMMAND_PLAYTEST_DONE ok=true' $(COMMAND_PLAYTEST_DIR)/run.log
