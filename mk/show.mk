# ---- S6: the arena light show (_agents/lighting.md) ---------------------------------------
# Every Godot process of this stream runs on builder0: `make remote T=show-report`.

show-report: import ## S6: print the patch every arena's `show` key resolves to, and fail on one the validator refuses (ARENA=terminus for one)
	$(GODOT) --headless --path . --script res://game/theme/show/tools/show_report.gd -- $(if $(ARENA),--arena=$(ARENA))

# The lead's pose, and it is not negotiable in a frame we show him: 21 deg pitch, FOV 35, 49 m. NOT 12 deg, which is
# the camera he played and rejected (workstreams.md S4, corrected by control 2026-09-20).
SHOW_ARENAS ?= terminus yard
SHOW_RES ?= 1920x1080
# Three moments of the idle breathe, spread across the slowest channel's period so the strip shows it moving.
SHOW_TIMES ?= 0,8.1,16.3
# One frame per cue, so the lead sees the SHOW and not only the ambience.
SHOW_CUES ?= fight,battle,last_stand,victory
SHOW_FLAGS ?=

show-frames: import ## S6: the light show at the lead's pose (21 deg, FOV 35, 49 m), idle + one frame per cue + a kill mid-ripple, per arena -> build/show/ (needs a display: make remote T=show-frames)
	rm -rf $(BUILD_DIR)/show && mkdir -p $(BUILD_DIR)/show
	for arena in $(SHOW_ARENAS); do \
		timeout 300 $(GODOT) --path . --resolution $(SHOW_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
			--no-pick-faction --cinematic --mute --arena=$$arena \
			--show-look=$(CURDIR)/$(BUILD_DIR)/show --show-look-times=$(SHOW_TIMES) --show-look-cues=$(SHOW_CUES) \
			$(SHOW_FLAGS) \
			2>&1 | tee $(BUILD_DIR)/show/$$arena.log | grep -E '^SHOW_LOOK|SCRIPT ERROR|shader' || true; \
		grep -q SHOW_LOOK_DONE $(BUILD_DIR)/show/$$arena.log || { echo "show-frames: $$arena never finished"; exit 1; }; \
		echo "show-frames $$arena: shader errors $$(grep -ci 'shader.*error\|error.*shader' $(BUILD_DIR)/show/$$arena.log || true)"; \
	done
	@echo "show-frames: $$(ls $(BUILD_DIR)/show/*.png 2>/dev/null | wc -l) frames in $(BUILD_DIR)/show"
