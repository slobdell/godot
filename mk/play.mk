# Playing and watching the game locally
# Owner: gameplay (see _agents/workstreams.md). Included by the root Makefile.

# ---- Day-to-day ---------------------------------------------------------------

editor: $(GODOT) ## Open the Godot editor on this project
	$(GODOT) --path . --editor

run: import ## Play offline vs BOTS server bots (default 1): WASD/arrows drive, mouse aims, click fires
	$(GODOT) --path . -- --bots=$(or $(filter-out 0,$(BOTS)),1)

# The booth and the soundtrack are on by default here: they only attach when asked, and a playtest without them is
# not the game (the lead ran `make skirmish` and wondered where the announcer had gone). ANNOUNCER=text|off, MUSIC=off.
skirmish: import ## Command your squads vs a budgeted CPU army (ENEMY=cpu|cpu:siege|individuals..., SEED=n, ARENA=random|yard|boulevard|pit|boneyard|foundry..., CONTROL=1, COMMANDER=1, ANNOUNCER=voice|text|off, MUSIC=on|off)
	$(GODOT) --path . -- --skirmish --enemy=$(ENEMY) $(if $(filter command line,$(origin SEED)),--seed=$(SEED)) --arena=$(or $(ARENA),random) \
		--announcer=$(or $(ANNOUNCER),voice) --music=$(or $(MUSIC),on) \
		$(if $(CONTROL),--control) $(if $(COMMANDER),--commander)

demo: import ## Play with a scripted driver instead of the keyboard
	$(GODOT) --path . -- --demo

screenshot: import ## Render the demo and save build/screenshots/demo.png (needs a display)
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --path . -- --demo --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/demo.png

skirmish-shots: import ## Scripted skirmish screenshots at desktop and phone aspect (1200x540 = a 2400x1080 phone at 2x scale): build/screenshots/skirmish_{desktop,phone}.png (needs a display; DELAY=seconds)
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --path . --resolution 1920x1080 -- --skirmish --scripted --enemy=$(ENEMY) --screenshot-delay=$(or $(DELAY),20) \
		--screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/skirmish_desktop.png
	$(GODOT) --path . --resolution 1200x540 -- --skirmish --scripted --enemy=$(ENEMY) --screenshot-delay=$(or $(DELAY),20) \
		--screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/skirmish_phone.png
