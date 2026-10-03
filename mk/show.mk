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
SHOW_CUES ?= fight,skirmish,battle,last_stand,victory
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
# NOT under $(BUILD_DIR)/show: `show-frames` starts with `rm -rf $(BUILD_DIR)/show`, so running the two targets in
# one make invocation DELETED this target's output before the copy-back, and the files left on the laptop were the
# previous run's -- current-looking, forty minutes old, and superseded. Siblings cannot do that to each other.
DECISIONS_DIR ?= $(BUILD_DIR)/show-decisions

show-decisions: import ## S6: the two calls that are the lead's -- roofline vs outline (frame pair) and the last_stand strobe on vs off (clip pair) -> build/show/decisions/
	rm -rf $(DECISIONS_DIR) && mkdir -p $(DECISIONS_DIR)
	@# 1. THE EDGES: one frame each, same arena, seed, pose and moment.
	for style in parapet outline; do \
		timeout $(SHOW_TIMEOUT) $(GODOT) --path . --resolution $(SHOW_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
			--budget=$(SHOW_BUDGET) --no-pick-faction --cinematic --mute --arena=$(CLIP_ARENA) $(SHOW_FLAGS) --show-style=$$style --show-look-fixed-heading \
			--show-look=$(CURDIR)/$(DECISIONS_DIR) --show-look-times=8.1 --show-look-cues=battle \
			2>&1 | tee $(DECISIONS_DIR)/edges_$$style.log | grep -E '^SHOW_LOOK |SCRIPT ERROR' || true; \
		grep -q SHOW_LOOK_DONE $(DECISIONS_DIR)/edges_$$style.log || { echo "show-decisions: edges/$$style did not finish"; exit 1; }; \
	done
	@# 2. THE STROBE: a clip each, because a still cannot show one.
	for arm in on off; do \
		[ $$arm = off ] && extra=--no-strobe || extra=; \
		timeout $(SHOW_TIMEOUT) $(GODOT) --path . --resolution $(CLIP_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
			--budget=$(SHOW_BUDGET) --no-pick-faction --cinematic --mute --arena=$(CLIP_ARENA) $(SHOW_FLAGS) $$extra \
			--show-look=$(CURDIR)/$(DECISIONS_DIR) --show-look-clip=last_stand \
			--show-look-clip-frames=$(STROBE_CLIP_FRAMES) --show-look-clip-step=$(STROBE_CLIP_STEP) \
			2>&1 | tee $(DECISIONS_DIR)/strobe_$$arm.log | grep -E '^SHOW_LOOK_CLIP|SCRIPT ERROR' || true; \
		grep -q SHOW_LOOK_DONE $(DECISIONS_DIR)/strobe_$$arm.log || { echo "show-decisions: strobe/$$arm did not finish"; exit 1; }; \
		ffmpeg -y -loglevel error -framerate $$(python3 -c "print(1.0/$(STROBE_CLIP_STEP))") \
			-i $(DECISIONS_DIR)/clips/$(CLIP_ARENA)_last_stand_%03d.png \
			-c:v libx264 -pix_fmt yuv420p $(DECISIONS_DIR)/strobe_$$arm.mp4; \
		rm -f $(DECISIONS_DIR)/clips/$(CLIP_ARENA)_last_stand_*.png; \
	done
	@# A decision frame with no vehicles in it cannot answer either question we shoot frames for. This is the
	@# check that would have caught an empty control ring the first time it was sent.
	@python3 tools/show_frame_gate.py $(DECISIONS_DIR)
	@echo "show-decisions: $$(ls $(DECISIONS_DIR)/*.png 2>/dev/null | wc -l) frames, $$(ls $(DECISIONS_DIR)/*.mp4 2>/dev/null | wc -l) clips in $(DECISIONS_DIR)"

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

# DIAL 1 AS A STRIP (round 10, item 1): the SAME frozen moment at each band width -- the idle and the battle cue,
# at the lead's pose -- with the show-off frame shot beside every one. One process, so the three arms differ in the
# band and in nothing else. The dial is `floor`/`ceiling` of the `windows` and `shopfronts` channels in
# `arenas/terminus.json` (`--show-band=K` scales both spans around their means without editing the file).
BANDS_DIR ?= $(BUILD_DIR)/show-bands
SHOW_BANDS ?= 1,2,3

show-bands: import ## S6: dial 1 -- the window/shopfront band at 1x, 2x, 3x, same frozen frame, show-off beside each -> build/show-bands/ (make remote T=show-bands)
	rm -rf $(BANDS_DIR) && mkdir -p $(BANDS_DIR)
	timeout $(SHOW_TIMEOUT) $(GODOT) --path . --resolution $(SHOW_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
		--budget=$(SHOW_BUDGET) --no-pick-faction --cinematic --mute --arena=$(CLIP_ARENA) $(SHOW_FLAGS) \
		--show-look=$(CURDIR)/$(BANDS_DIR) --show-look-times=8.1 --show-look-cues=battle --show-look-bands=$(SHOW_BANDS) \
		2>&1 | tee $(BANDS_DIR)/$(CLIP_ARENA).log | grep -E '^SHOW_LOOK |SCRIPT ERROR' || true
	grep -q SHOW_LOOK_DONE $(BANDS_DIR)/$(CLIP_ARENA).log || { echo "show-bands: did not finish"; exit 1; }
	@python3 tools/show_frame_gate.py $(BANDS_DIR)
	@python3 tools/show_luma_gate.py $(BANDS_DIR)

# ROUND 10: the effects in motion, at 30 fps so a strobe is sampled rather than missed (the round-9 rule for the
# strobe clip, now for all of them: the chase climbs ~2.6 storeys a second and the fill one storey per 0.18 s).
# -> build/show-clips/terminus_<cue>.mp4. NOT under build/show (show-frames deletes that folder).
EFFECT_CLIPS ?= lull battle last_stand capture kill skirmish
EFFECT_CLIPS_DIR ?= $(BUILD_DIR)/show-clips

show-effect-clips: import ## S6: each round-10 window effect as a 6 s clip at 30 fps from the lead's pose -> build/show-clips/*.mp4 (make remote T=show-effect-clips)
	rm -rf $(EFFECT_CLIPS_DIR) && mkdir -p $(EFFECT_CLIPS_DIR)
	for cue in $(EFFECT_CLIPS); do \
		timeout $(SHOW_TIMEOUT) $(GODOT) --path . --resolution $(CLIP_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
			--budget=$(SHOW_BUDGET) --no-pick-faction --cinematic --mute --arena=$(CLIP_ARENA) $(SHOW_FLAGS) \
			--show-look=$(CURDIR)/$(EFFECT_CLIPS_DIR) --show-look-clip=$$cue \
			--show-look-clip-frames=$(STROBE_CLIP_FRAMES) --show-look-clip-step=$(STROBE_CLIP_STEP) \
			2>&1 | tee $(EFFECT_CLIPS_DIR)/$$cue.log | grep -E '^SHOW_LOOK_CLIP|SCRIPT ERROR' || true; \
		grep -q SHOW_LOOK_DONE $(EFFECT_CLIPS_DIR)/$$cue.log || { echo "show-effect-clips: $$cue never finished"; exit 1; }; \
		ffmpeg -y -loglevel error -framerate 30 -i $(EFFECT_CLIPS_DIR)/clips/$(CLIP_ARENA)_$${cue}_%03d.png \
			-c:v libx264 -pix_fmt yuv420p $(EFFECT_CLIPS_DIR)/$(CLIP_ARENA)_$$cue.mp4; \
		rm -f $(EFFECT_CLIPS_DIR)/clips/$(CLIP_ARENA)_$${cue}_*.png; \
	done
	@echo "show-effect-clips: $$(ls $(EFFECT_CLIPS_DIR)/*.mp4 2>/dev/null | wc -l) clips in $(EFFECT_CLIPS_DIR)"

show-page: ## S6: the lead's verdict page from whatever show-frames / show-bands / show-effect-clips left in build/ -> build/show-page/index.html (pure Python; run after the remote targets)
	python3 tools/show_page.py $(BUILD_DIR)

# ---- Round 16, R1: the picture, proven unchanged (contract C16.6) ---------------------------------------------
# A performance change ships with a parity line: the same frozen moments shot before and after, diffed pixel-wise.
# `--fixed-fps 30` is what makes two runs comparable at all: every frame is exactly one 30 Hz tick and 1/30 s of FX
# and shader clock, so the battle, the camera's smoothing and every animation land on the same values whatever the
# machine's frame time was (game/theme/fx/look_parity_shot.gd says what else is pinned). His window is 1854x1011
# (the laptop maximised); the phone is 1200x540 (a 2400x1080 phone at 2x, skirmish-shots' phone).
#   make remote T="look-parity-shots LP_LABEL=before"   # on the commit before the change
#   make remote T="look-parity-shots LP_LABEL=after"    # on the change
#   make look-parity                                    # local, Pillow only -> build/look-parity/diff/
# The two sets must come from the same machine (builder0's GPU and the laptop's round differently).
LP_LABEL ?= after
LP_RES ?= 1854x1011 1200x540
LP_ARENAS ?= sumps terminus
LP_TICKS ?= 150,450,900
LP_BUDGET ?= 6500
LP_FLAGS ?=
LP_DIR := $(BUILD_DIR)/look-parity
LP_BEFORE ?= before
LP_AFTER ?= after
LP_THRESHOLD ?= 8
LP_MAX_SHARE ?= 0.005

look-parity-shots: import ## R1 (round 16): the same frozen frames at his window and a phone, per arena: live camera + four fixed poses at LP_TICKS -> build/look-parity/$(LP_LABEL)/<arena>-<res>/ (needs a display: make remote T="look-parity-shots LP_LABEL=before"; LP_ARENAS=, LP_RES=, LP_FLAGS=)
	rm -rf $(LP_DIR)/$(LP_LABEL) && mkdir -p $(LP_DIR)/$(LP_LABEL)
	@echo "commit $${TANK_SQUAD_COMMIT:-$$(git rev-parse --short HEAD 2>/dev/null)}$$(git diff --quiet HEAD 2>/dev/null || echo ' (+ uncommitted)') host $$(hostname) flags '$(LP_FLAGS)'" \
		> $(LP_DIR)/$(LP_LABEL)/SOURCE.txt
	for arena in $(LP_ARENAS); do \
		for res in $(LP_RES); do \
			out=$(LP_DIR)/$(LP_LABEL)/$$arena-$$res; mkdir -p $$out; \
			timeout 1500 $(GODOT) --fixed-fps $(SIM_HZ) --path . --resolution $$res -- --skirmish --scripted --seed=3 \
				--budget=$(LP_BUDGET) --no-pick-faction --mute --arena=$$arena \
				--look-parity=$(CURDIR)/$$out --look-parity-ticks=$(LP_TICKS) $(LP_FLAGS) \
				2>&1 | tee $$out/log.txt | grep -E '^LOOK_PARITY_(DONE|FAILED|START|PROGRESS)|SCRIPT ERROR' || true; \
			grep -q LOOK_PARITY_DONE $$out/log.txt || { echo "look-parity-shots: $$arena $$res did not finish"; exit 1; }; \
		done; \
	done
	@cat $(LP_DIR)/$(LP_LABEL)/SOURCE.txt
	@echo "look-parity-shots: $$(find $(LP_DIR)/$(LP_LABEL) -name '*.png' | wc -l) frames in $(LP_DIR)/$(LP_LABEL)"

look-parity: ## R1 (round 16): diff two look-parity-shots sets (LP_BEFORE=before LP_AFTER=after); a pixel changes above LP_THRESHOLD/255, a pair passes at <= LP_MAX_SHARE of its pixels -> build/look-parity/diff/*_diff.png + report.json (pure Python, Pillow)
	@for s in $(LP_BEFORE) $(LP_AFTER); do echo "$$s: $$(cat $(LP_DIR)/$$s/SOURCE.txt 2>/dev/null || echo 'no SOURCE.txt')"; done
	rm -rf $(LP_DIR)/diff
	$(PYTHON) tools/look_parity.py $(LP_DIR)/$(LP_BEFORE) $(LP_DIR)/$(LP_AFTER) --out $(LP_DIR)/diff \
		--threshold $(LP_THRESHOLD) --max-share $(LP_MAX_SHARE)

# ---- Round 16, R2: what each piece of the picture costs, by removal within one run ----------------------------
# RenderSplit alternates `all` with each RenderLayers layer (game/theme/fx/render_layers.gd) seconds apart. GPU ms are
# the LAPTOP's (his Intel UHD 620): run it there, at his window, and say so in Status (it opens a window on his
# desktop). builder0 (Iris Xe, ~2.3x faster GPU) is for draw calls, primitives and objects: make remote T=render-split.
# The player's side (--scripted: a human army driven by a fixed order sequence), so the fog-of-war sheet is drawn, as
# in his game; perf-scene's spectator run has no fog sheet.
RS_RES ?= 1854x1011
RS_ARENA ?= sumps
RS_LAYERS ?=
RS_SECONDS ?= 2.5
RS_CYCLES ?= 2
RS_WARMUP ?= 10
RS_FLAGS ?=
RS_NAME ?= render-split

render-split: import ## R2 (round 16): GPU ms, draws, primitives per render layer by removal within one run, at his window -> build/$(RS_NAME).json + RENDER_SPLIT lines (needs a display; RS_LAYERS=no_venue,no_water RS_ARENA= RS_RES= RS_FLAGS=)
	timeout 900 $(GODOT) --path . --resolution $(RS_RES) -- --skirmish --scripted --seed=3 --budget=$(LP_BUDGET) \
		--no-pick-faction --mute --arena=$(RS_ARENA) --render-split=$(CURDIR)/$(BUILD_DIR)/$(RS_NAME).json \
		--render-split-warmup=$(RS_WARMUP) --render-split-seconds=$(RS_SECONDS) --render-split-cycles=$(RS_CYCLES) \
		$(if $(RS_LAYERS),--render-split-layers=$(RS_LAYERS)) $(RS_FLAGS) \
		2>&1 | tee $(BUILD_DIR)/$(RS_NAME).log | grep -E '^RENDER_SPLIT|SCRIPT ERROR' || true
	@grep -q RENDER_SPLIT_DONE $(BUILD_DIR)/$(RS_NAME).log
