# ---- S6: the arena light show (_agents/lighting.md) ---------------------------------------
# Every Godot process of this stream runs on builder0: `make remote T=show-report`.

show-report: import ## S6: print the patch every arena's `show` key resolves to, and fail on one the validator refuses (ARENA=terminus for one)
	$(GODOT) --headless --path . --script res://game/theme/show/tools/show_report.gd -- $(if $(ARENA),--arena=$(ARENA))

# The lead's pose, and it is not negotiable in a frame we show him: 21 deg pitch, FOV 35, 49 m. NOT 12 deg, which is
# the camera he played and rejected (workstreams.md S4, corrected by control 2026-09-20).
SHOW_ARENAS ?= terminus yard
SHOW_RES ?= 1920x1080
# The fight the lead plays, not the skirmish default. Without this the run fields 950 pts -- FIVE units a side --
# and every frame is a venue with almost nothing in it. perf-scene has always passed this; the frame tools did not.
SHOW_BUDGET ?= 6500
# Three moments of the idle breathe, spread across the slowest channel's period so the strip shows it moving.
SHOW_TIMES ?= 0,8.1,16.3
# One frame per cue, so the lead sees the SHOW and not only the ambience.
SHOW_CUES ?= fight,battle,last_stand,victory
# --block-cutaway=off draws the city whole. control cuts a city block's VisualSlot (visibility, never a uniform --
# it reserves nothing on the block material) when one stands between the camera and what the camera is aimed at,
# and at the lead's pose in a Terminus street that is often the nearest block. A frame shot to judge how the block
# EDGES read must therefore have it off, or the block may simply not be there (control, 2026-09-20).
SHOW_FLAGS ?= --block-cutaway=off
# Every capture process now WAITS FOR THE ARMIES TO MEET before it shoots anything, and on builder0's vsync'd
# window that measured 116 s of wall clock (59.6 m closest pair). Add the captures on top -- 180 of them for a
# 30 fps strobe clip -- and the old `timeout 420` killed the run mid-clip with "strobe/on did not finish". These
# are caps against a hang, not budgets: a run that finishes early costs nothing.
SHOW_TIMEOUT ?= 900

show-frames: import ## S6: the light show at the lead's pose (21 deg, FOV 35, 49 m). Each frame is shot TWICE at the same frozen moment -- show off then on -- plus the outline variant; idle + one per cue + the kill ripple at three ages -> build/show/ (needs a display: make remote T=show-frames)
	rm -rf $(BUILD_DIR)/show && mkdir -p $(BUILD_DIR)/show
	@# Two runs are not the same run, and these frames ride a LIVE skirmish -- so the BEFORE half is shot by the
	@# frame tool itself, in the same process, on the same paused scene, by toggling Show.driving. The pair then
	@# differs in the light show and in nothing else. The only separate process is the `outline` VARIANT, which is
	@# a look to compare rather than a control to measure against.
	for arm in default outline; do \
		for arena in $(SHOW_ARENAS); do \
			case $$arm in \
				outline) extra="--show-style=outline"; sub="outline";; \
				*)       extra=""; sub=".";; \
			esac; \
			mkdir -p $(BUILD_DIR)/show/$$sub; \
			timeout $(SHOW_TIMEOUT) $(GODOT) --path . --resolution $(SHOW_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
				--budget=$(SHOW_BUDGET) --no-pick-faction --cinematic --mute --arena=$$arena $$extra \
				--show-look=$(CURDIR)/$(BUILD_DIR)/show/$$sub --show-look-times=$(SHOW_TIMES) \
				--show-look-cues=$(SHOW_CUES) $(SHOW_FLAGS) \
				2>&1 | tee $(BUILD_DIR)/show/$$sub/$$arena.log | grep -E '^SHOW_LOOK |SCRIPT ERROR' || true; \
			grep -q SHOW_LOOK_DONE $(BUILD_DIR)/show/$$sub/$$arena.log || { echo "show-frames: $$arm/$$arena did not finish"; exit 1; }; \
			echo "show-frames $$arm/$$arena: shader errors $$(grep -ci 'shader.*error\|error.*shader' $(BUILD_DIR)/show/$$sub/$$arena.log || true)"; \
		done; \
	done
	@echo "show-frames: $$(find $(BUILD_DIR)/show -name '*.png' | wc -l) frames in $(BUILD_DIR)/show"
	@# THE BRIGHTNESS HIERARCHY IS A GATE (feel, 2026-09-20; art_direction.md :72), and a RELATIVE one: the branch
	@# point already loses the absolute comparison at the lead's pose, so the bar is that the show must not make it
	@# worse than the same frozen frame with the show off.
	@python3 tools/show_frame_gate.py $(BUILD_DIR)/show
	@python3 tools/show_luma_gate.py $(BUILD_DIR)/show

# A cue is MOTION. A still of a chase is a still of a bank of lights, and a still of a strobe at its trough reads
# as "dimmer", which is the opposite of the impression it gives. 720p because motion is the subject.
CLIP_RES ?= 1280x720
CLIP_CUES ?= lull battle last_stand victory kill
CLIP_FRAMES ?= 60
CLIP_STEP ?= 0.1
# THE STROBE CLIPS RUN AT 30 fps, NOT 10, AND THE REASON IS ALIASING RATHER THAN POLISH. `last_stand` strobes at
# sharpness 40 over a 1.6 s period, so the stab is above half brightness for 8.4% of the cycle -- 0.134 s. At the
# 10 fps the other clips use, ~1.3 frames land inside a stab and almost never at its peak, so the clip samples
# mostly the gaps: the strobe-on and strobe-off arms came back with the same swing (1.9% vs 1.6% over the whole
# frame) because the clip could not see the thing being compared. At 30 fps ~4 frames land in each stab, which is
# also what the player sees, since the game targets 30.
STROBE_CLIP_STEP ?= 0.0333
STROBE_CLIP_FRAMES ?= 180
CLIP_ARENA ?= terminus

# The lead has exactly two open look questions, and each needs the kind of evidence that can actually answer it:
#   * roofline vs full outline is a STATIC difference -> a frame pair
#   * the last_stand strobe is MOTION -> a clip pair. A still of a strobe caught between flashes reads as "dimmer",
#     which is the opposite of the impression it gives, so a frame pair here would misinform him (lighting.md 8b).
show-decisions: import ## S6: the two calls that are the lead's -- roofline vs outline (frame pair) and the last_stand strobe on vs off (clip pair) -> build/show/decisions/
	rm -rf $(BUILD_DIR)/show/decisions && mkdir -p $(BUILD_DIR)/show/decisions
	@# 1. THE EDGES: one frame each, same arena, seed, pose and moment.
	for style in parapet outline; do \
		timeout $(SHOW_TIMEOUT) $(GODOT) --path . --resolution $(SHOW_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
			--budget=$(SHOW_BUDGET) --no-pick-faction --cinematic --mute --arena=$(CLIP_ARENA) $(SHOW_FLAGS) --show-style=$$style \
			--show-look=$(CURDIR)/$(BUILD_DIR)/show/decisions --show-look-times=8.1 --show-look-cues=battle \
			2>&1 | tee $(BUILD_DIR)/show/decisions/edges_$$style.log | grep -E '^SHOW_LOOK |SCRIPT ERROR' || true; \
		grep -q SHOW_LOOK_DONE $(BUILD_DIR)/show/decisions/edges_$$style.log || { echo "show-decisions: edges/$$style did not finish"; exit 1; }; \
	done
	@# 2. THE STROBE: a clip each, because a still cannot show one.
	for arm in on off; do \
		[ $$arm = off ] && extra=--no-strobe || extra=; \
		timeout $(SHOW_TIMEOUT) $(GODOT) --path . --resolution $(CLIP_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
			--budget=$(SHOW_BUDGET) --no-pick-faction --cinematic --mute --arena=$(CLIP_ARENA) $(SHOW_FLAGS) $$extra \
			--show-look=$(CURDIR)/$(BUILD_DIR)/show/decisions --show-look-clip=last_stand \
			--show-look-clip-frames=$(STROBE_CLIP_FRAMES) --show-look-clip-step=$(STROBE_CLIP_STEP) \
			2>&1 | tee $(BUILD_DIR)/show/decisions/strobe_$$arm.log | grep -E '^SHOW_LOOK_CLIP|SCRIPT ERROR' || true; \
		grep -q SHOW_LOOK_DONE $(BUILD_DIR)/show/decisions/strobe_$$arm.log || { echo "show-decisions: strobe/$$arm did not finish"; exit 1; }; \
		ffmpeg -y -loglevel error -framerate $$(python3 -c "print(1.0/$(STROBE_CLIP_STEP))") \
			-i $(BUILD_DIR)/show/decisions/clips/$(CLIP_ARENA)_last_stand_%03d.png \
			-c:v libx264 -pix_fmt yuv420p $(BUILD_DIR)/show/decisions/strobe_$$arm.mp4; \
		rm -f $(BUILD_DIR)/show/decisions/clips/$(CLIP_ARENA)_last_stand_*.png; \
	done
	@# A decision frame with no vehicles in it cannot answer either question we shoot frames for. This is the
	@# check that would have caught an empty control ring the first time it was sent.
	@python3 tools/show_frame_gate.py $(BUILD_DIR)/show/decisions
	@echo "show-decisions: $$(ls $(BUILD_DIR)/show/decisions/*.png 2>/dev/null | wc -l) frames, $$(ls $(BUILD_DIR)/show/decisions/*.mp4 2>/dev/null | wc -l) clips in $(BUILD_DIR)/show/decisions"

show-clips: import ## S6: each cue as a 6 s clip at 10 fps from the lead's pose -> build/show/clips/*.mp4 (needs a display and ffmpeg: make remote T=show-clips)
	rm -rf $(BUILD_DIR)/show/clips && mkdir -p $(BUILD_DIR)/show/clips
	for cue in $(CLIP_CUES); do \
		timeout $(SHOW_TIMEOUT) $(GODOT) --path . --resolution $(CLIP_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
			--budget=$(SHOW_BUDGET) --no-pick-faction --cinematic --mute --arena=$(CLIP_ARENA) $(SHOW_FLAGS) \
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

show-perf-layer: import ## S6: the show's cost measured WITHIN one perf-scene run (--perf-layers=no_show), so both halves see the same machine -- the only instrument that survives a contended builder0
	$(MAKE) perf-scene PERF_NAME=show-layer PERF_RES=$(SHOW_RES) PERF_LAYERS=no_show \
		PERF_FLAGS="--arena=$(firstword $(SHOW_ARENAS))"
	@grep PERF_SCENE_LAYERS $(BUILD_DIR)/show-layer.log | python3 -c "import sys,json;d=json.loads(sys.stdin.read().split(' ',1)[1]);print('SHOW_LAYER_COST gpu_ms=%s  cpu_ms=%s  draw_calls=%s  (against all_gpu %s, all_avg %s)' % (d['layer_cost_gpu_ms'].get('no_show'), d['layer_cost_ms'].get('no_show'), d['layer_draw_calls'].get('no_show'), d['all_gpu_ms'], d['all_avg_ms']))" || true
	@echo "   A negative or tiny CPU figure is the method's own noise, not a speed-up: layer_costs() is the mean of"
	@echo "   the 'all' phases either side minus the layer's phase, over PERF_CYCLES cycles. Raise PERF_CYCLES to tighten it."

show-perf-pair: import ## S6: perf-scene with the show off then on, back to back in one slot -> build/show-off.json, build/show-on.json
	$(MAKE) perf-scene PERF_NAME=show-off PERF_RES=$(SHOW_RES) PERF_FLAGS="--arena=$(firstword $(SHOW_ARENAS)) --no-show"
	$(MAKE) perf-scene PERF_NAME=show-on  PERF_RES=$(SHOW_RES) PERF_FLAGS="--arena=$(firstword $(SHOW_ARENAS))"
