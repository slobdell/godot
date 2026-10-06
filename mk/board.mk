# Round 19 (board): the score bug, the zone rings and the celebration. Owned by the board stream.

BOARD_SHOTS_DIR ?= $(BUILD_DIR)/board-shots

board-shots: import ## The score bug in every state (fresh, one zone, both, contested, kill, lead change, final seconds, centre map, no control) at his window and the phone -> build/board-shots/*.png (needs a display)
	rm -rf $(BOARD_SHOTS_DIR) && mkdir -p $(BOARD_SHOTS_DIR)
	$(GODOT) --path . --resolution 1854x1011 -s res://game/ui/scoreboard_shots.gd -- --out=$(CURDIR)/$(BOARD_SHOTS_DIR) --suffix=desktop
	$(GODOT) --path . --resolution 1200x540 -s res://game/ui/scoreboard_shots.gd -- --out=$(CURDIR)/$(BOARD_SHOTS_DIR) --suffix=phone
	@ls $(BOARD_SHOTS_DIR)/*.png | wc -l | xargs -I{} echo "board-shots: {} frames in $(BOARD_SHOTS_DIR)"

## S5: the board in a real match, CPU against CPU, at his window and the phone, on the maps he named. One run per
## frame (the screenshot quits the game): BOARD_ARENAS x BOARD_DELAYS x the two sizes. Frames in build/board-play/.
BOARD_ARENAS ?= terminus parade
BOARD_DELAYS ?= 25 60 110
BOARD_PLAY_DIR ?= $(BUILD_DIR)/board-play

board-play-shots: import ## The score bug and the zone rings in a CPU-vs-CPU skirmish (BOARD_ARENAS x BOARD_DELAYS, his window and the phone) -> build/board-play/*.png (needs a display)
	rm -rf $(BOARD_PLAY_DIR) && mkdir -p $(BOARD_PLAY_DIR)
	for arena in $(BOARD_ARENAS); do for delay in $(BOARD_DELAYS); do for size in 1854x1011 1200x540; do \
		timeout 300 $(GODOT) --path . --resolution $$size -- --skirmish --player=cpu --enemy=cpu --seed=3 --arena=$$arena \
			--no-pick-faction --announcer=text --announcer-history=off --music-history=off --render-preset=desktop \
			--screenshot-delay=$$delay --screenshot=$(CURDIR)/$(BOARD_PLAY_DIR)/$${arena}_$${delay}s_$$size.png \
			> $(BOARD_PLAY_DIR)/$${arena}_$${delay}s_$$size.log 2>&1 || echo "board-play-shots: $$arena $$delay $$size exited $$?"; \
	done; done; done
	@ls $(BOARD_PLAY_DIR)/*.png 2>/dev/null | wc -l | xargs -I{} echo "board-play-shots: {} frames in $(BOARD_PLAY_DIR)"
