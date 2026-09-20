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
# --block-cutaway=off draws the city whole. control cuts a city block's VisualSlot (visibility, never a uniform --
# it reserves nothing on the block material) when one stands between the camera and what the camera is aimed at,
# and at the lead's pose in a Terminus street that is often the nearest block. A frame shot to judge how the block
# EDGES read must therefore have it off, or the block may simply not be there (control, 2026-09-20).
SHOW_FLAGS ?= --block-cutaway=off

show-frames: import ## S6: the light show at the lead's pose (21 deg, FOV 35, 49 m) -- BEFORE (no show), the default parapet look, and the outline variant; idle + one frame per cue + the kill ripple at three ages -> build/show/ (needs a display: make remote T=show-frames)
	rm -rf $(BUILD_DIR)/show && mkdir -p $(BUILD_DIR)/show
	@# Three arms of the SAME arena, seed and pose, so his comparison is frames rather than a frame and a memory:
	@#   before/  -- --no-show: no patch loaded, every fixture at its identity = the branch-point look
	@#   (root)   -- the default: the roof parapet, venue palette, under the window grid
	@#   outline/ -- the variant feel argued against and the lead may still want; exempt from the luminance gate
	for arm in before default outline; do \
		for arena in $(SHOW_ARENAS); do \
			case $$arm in \
				before)  extra="--no-show"; sub="before";; \
				outline) extra="--show-style=outline"; sub="outline";; \
				*)       extra=""; sub=".";; \
			esac; \
			mkdir -p $(BUILD_DIR)/show/$$sub; \
			timeout 420 $(GODOT) --path . --resolution $(SHOW_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
				--no-pick-faction --cinematic --mute --arena=$$arena $$extra \
				--show-look=$(CURDIR)/$(BUILD_DIR)/show/$$sub --show-look-times=$(SHOW_TIMES) \
				--show-look-cues=$(SHOW_CUES) $(SHOW_FLAGS) \
				2>&1 | tee $(BUILD_DIR)/show/$$sub/$$arena.log | grep -E '^SHOW_LOOK |SCRIPT ERROR' || true; \
			grep -q SHOW_LOOK_DONE $(BUILD_DIR)/show/$$sub/$$arena.log || { echo "show-frames: $$arm/$$arena never finished"; exit 1; }; \
			echo "show-frames $$arm/$$arena: shader errors $$(grep -ci 'shader.*error\|error.*shader' $(BUILD_DIR)/show/$$sub/$$arena.log || true)"; \
		done; \
	done
	@echo "show-frames: $$(find $(BUILD_DIR)/show -name '*.png' | wc -l) frames in $(BUILD_DIR)/show"
	@# THE BRIGHTNESS HIERARCHY IS A GATE, not a note (feel, 2026-09-20; art_direction.md :72). If the block band
	@# out-reads the fight ring in any DEFAULT-style frame, the venue is competing with the game and this fails.
	@python3 tools/show_luma_gate.py $(BUILD_DIR)/show

# A cue is MOTION. A still of a chase is a still of a bank of lights, and a still of a strobe at its trough reads
# as "dimmer", which is the opposite of the impression it gives. 720p because motion is the subject.
CLIP_RES ?= 1280x720
CLIP_CUES ?= lull battle last_stand victory kill
CLIP_FRAMES ?= 60
CLIP_STEP ?= 0.1
CLIP_ARENA ?= terminus

show-clips: import ## S6: each cue as a 6 s clip at 10 fps from the lead's pose -> build/show/clips/*.mp4 (needs a display and ffmpeg: make remote T=show-clips)
	rm -rf $(BUILD_DIR)/show/clips && mkdir -p $(BUILD_DIR)/show/clips
	for cue in $(CLIP_CUES); do \
		timeout 420 $(GODOT) --path . --resolution $(CLIP_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
			--no-pick-faction --cinematic --mute --arena=$(CLIP_ARENA) $(SHOW_FLAGS) \
			--show-look=$(CURDIR)/$(BUILD_DIR)/show --show-look-clip=$$cue \
			--show-look-clip-frames=$(CLIP_FRAMES) --show-look-clip-step=$(CLIP_STEP) \
			2>&1 | tee $(BUILD_DIR)/show/clips/$$cue.log | grep -E '^SHOW_LOOK_CLIP|SCRIPT ERROR' || true; \
		grep -q SHOW_LOOK_DONE $(BUILD_DIR)/show/clips/$$cue.log || { echo "show-clips: $$cue never finished"; exit 1; }; \
		ffmpeg -y -loglevel error -framerate $$(python3 -c "print(1.0/$(CLIP_STEP))") \
			-i $(BUILD_DIR)/show/clips/$(CLIP_ARENA)_$${cue}_%03d.png \
			-c:v libx264 -pix_fmt yuv420p $(BUILD_DIR)/show/clips/$(CLIP_ARENA)_$$cue.mp4; \
		rm -f $(BUILD_DIR)/show/clips/$(CLIP_ARENA)_$${cue}_*.png; \
	done
	@echo "show-clips: $$(ls $(BUILD_DIR)/show/clips/*.mp4 2>/dev/null | wc -l) clips in $(BUILD_DIR)/show/clips"

show-perf-pair: import ## S6: perf-scene with the show off then on, back to back in one slot -> build/show-off.json, build/show-on.json
	$(MAKE) perf-scene PERF_NAME=show-off PERF_RES=$(SHOW_RES) PERF_FLAGS="--arena=$(firstword $(SHOW_ARENAS)) --no-show"
	$(MAKE) perf-scene PERF_NAME=show-on  PERF_RES=$(SHOW_RES) PERF_FLAGS="--arena=$(firstword $(SHOW_ARENAS))"
