# Playing and watching the game locally
# Owner: gameplay (see _agents/workstreams.md). Included by the root Makefile.

# ---- Day-to-day ---------------------------------------------------------------

editor: $(GODOT) ## Open the Godot editor on this project
	$(GODOT) --path . --editor

run: import ## Play offline vs BOTS server bots (default 1): WASD/arrows drive, mouse aims, click fires
	$(GODOT) --path . -- --bots=$(or $(filter-out 0,$(BOTS)),1)

skirmish: import ## Command your squads on the tactical map vs a CPU doctrine (ENEMY=individuals|anvil_hammer|flame_rush)
	$(GODOT) --path . -- --skirmish --enemy=$(ENEMY)

demo: import ## Play with a scripted driver instead of the keyboard
	$(GODOT) --path . -- --demo

screenshot: import ## Render the demo and save build/screenshots/demo.png (needs a display)
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --path . -- --demo --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/demo.png
