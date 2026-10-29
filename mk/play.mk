# Playing and watching the game locally
# Owner: gameplay (see _agents/workstreams.md). Included by the root Makefile.

# ---- Day-to-day ---------------------------------------------------------------

# The lead's play targets rebuild a STALE native library first (2026-10-16: his laptop's .so was from 10-13, so round 31's
# GDScript called avoidance_gather with an argument the old library lacked, every tank every tick, and the game went
# choppy; builder0's checks always rebuild, so no check could see it). Only when native is ON (the .gdextension is there)
# and a toolchain exists; a fresh library costs one `find`.
# Round 45 (native, engage's report): a folder that has NEVER built the library (no .so and no .gdextension: a fresh builder
# folder) builds it too. Before, it stayed on the GDScript path in silence, and engage's replay-match of his native match ran
# GDScript (REPLAY_NATIVE_MISMATCH) on a fresh builder0 folder. Switched off on purpose (native-off: the .gdextension removed, the
# .so kept) or NATIVE=off stays off; no toolchain says so in one line. Never under `make -n` (a recipe line naming $(MAKE) runs
# even in a dry run, and tools read targets' command lines with -n: round 40's faction-matrix lesson).
native-fresh:
	@if [ -z "$(findstring n,$(firstword -$(MAKEFLAGS)))" ] && [ "$(NATIVE)" != off ] && [ ! -e $(NATIVE_GDEXT) ] && [ ! -e $(NATIVE_SO) ]; then \
		if [ "$(NATIVE_TOOLCHAIN)" = yes ]; then echo ">> native: no library in this folder yet; building it (NATIVE=off runs the GDScript)"; \
			$(MAKE) --no-print-directory native; \
		else echo ">> native: OFF: no library here and no cmake + c++ on $$(hostname): this run is the GDScript path"; fi; \
	elif [ -e $(NATIVE_GDEXT) ] && [ "$(NATIVE_TOOLCHAIN)" = yes ] && \
		[ -n "$$(find $(NATIVE_DIR)/src $(NATIVE_DIR)/CMakeLists.txt $(NATIVE_DIR)/build.sh -newer $(NATIVE_SO) -print -quit 2>/dev/null)" -o ! -e $(NATIVE_SO) ]; then \
		echo ">> native: the library is older than native/src; rebuilding it before play"; $(MAKE) --no-print-directory native; fi


editor: $(GODOT) ## Open the Godot editor on this project
	$(GODOT) --path . --editor

run: native-fresh import ## Play offline vs BOTS server bots (default 1): WASD/arrows drive, mouse aims, click fires
	$(GODOT) --path . -- --bots=$(or $(filter-out 0,$(BOTS)),1)

# Harness targets pass --announcer-history=off --music-history=off: in the MAIN checkout user:// is the lead's own, and a
# bench must not write fake matches into his booth's and soundtrack's memory (worktrees have their own, override.cfg).
# The booth and the soundtrack are on by default here: they only attach when asked, and a playtest without them is
# not the game (the lead ran `make skirmish` and wondered where the announcer had gone). ANNOUNCER=text|off, MUSIC=off.
# Round 16 (P3): the faction menu opens with the enemy on RANDOM (rolled from SEED at FIGHT); ENEMY_FACTION=law pins it
# with the menu still up for his own pick.
# Round 39 (C39.6): SKIRMISH_FLAGS="..." goes word for word to the end of the game's flags, so any OFF switch can be
# playtested with `make skirmish`; LaunchFlags keeps the last value of a repeated flag, so it also overrides the ones above.
# Round 44 (native): SEED keeps its digits only. His round-43 playtests ran `SEED=56416.` (a sentence's full stop copied from
# HANDOFF): --seed did not parse, the CPU army rolled from the game's own clock and the recording says seed -1, so no replay
# could repeat his match. A SEED with no digits takes the clock's, which make passes and the recording keeps.
skirmish: native-fresh import ## Command your squads vs a budgeted CPU army (ENEMY=cpu|cpu:siege|individuals..., ENEMY_FACTION=condemned|gangs|law|syndicate (default: random), SEED=n, ARENA=random|yard|boulevard|pit|boneyard|foundry..., CONTROL=1, COMMANDER=1, ANNOUNCER=voice|text|off, MUSIC=on|off, CAMERA_READOUT=on|off, CPU_LEADERS=1 for the computer's squad leaders: it defends and ambushes, round 19, costs frame time; SKIRMISH_FLAGS="--rules-off=sight --parked-hold=on" passes any game flags, last so they win)
	$(GODOT) --path . -- --skirmish --enemy=$(ENEMY) --seed=$$(s=$$(printf '%s' '$(if $(filter command line,$(origin SEED)),$(SEED))' | tr -cd 0-9); echo $${s:-$$(( $$(date +%s) % 100000 ))}) --arena=$(or $(ARENA),random) \
		--announcer=$(or $(ANNOUNCER),voice) --music=$(or $(MUSIC),on) --camera-readout=$(or $(CAMERA_READOUT),on) \
		$(if $(CONTROL),--control) $(if $(COMMANDER),--commander) $(if $(ENEMY_FACTION),--pick-faction --enemy-faction=$(ENEMY_FACTION)) \
		$(if $(CPU_LEADERS),--element-cpu) $(SKIRMISH_FLAGS)

demo: native-fresh import ## Play with a scripted driver instead of the keyboard
	$(GODOT) --path . -- --demo

screenshot: import ## Render the demo and save build/screenshots/demo.png (needs a display)
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --path . -- --demo --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/demo.png

skirmish-shots: import ## Scripted skirmish screenshots at desktop and phone aspect (1200x540 = a 2400x1080 phone at 2x scale): build/screenshots/skirmish_{desktop,phone}.png (needs a display; DELAY=seconds)
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --path . --resolution 1920x1080 -- --skirmish --scripted --enemy=$(ENEMY) --announcer-history=off --music-history=off --render-preset=desktop --screenshot-delay=$(or $(DELAY),20) \
		--screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/skirmish_desktop.png
	$(GODOT) --path . --resolution 1200x540 -- --skirmish --scripted --enemy=$(ENEMY) --announcer-history=off --music-history=off --render-preset=desktop --screenshot-delay=$(or $(DELAY),20) \
		--screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/skirmish_phone.png
