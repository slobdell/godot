# Round 19 (board): the score bug, the zone rings and the celebration. Owned by the board stream.

BOARD_SHOTS_DIR ?= $(BUILD_DIR)/board-shots

board-shots: import ## The score bug in every state (fresh, one zone, both, contested, kill, lead change, final seconds, centre map, no control) at his window and the phone -> build/board-shots/*.png (needs a display)
	rm -rf $(BOARD_SHOTS_DIR) && mkdir -p $(BOARD_SHOTS_DIR)
	$(GODOT) --path . --resolution 1854x1011 -s res://game/ui/scoreboard_shots.gd -- --out=$(CURDIR)/$(BOARD_SHOTS_DIR) --suffix=desktop
	$(GODOT) --path . --resolution 1200x540 -s res://game/ui/scoreboard_shots.gd -- --out=$(CURDIR)/$(BOARD_SHOTS_DIR) --suffix=phone
	@ls $(BOARD_SHOTS_DIR)/*.png | wc -l | xargs -I{} echo "board-shots: {} frames in $(BOARD_SHOTS_DIR)"
