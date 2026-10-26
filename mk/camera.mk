# Round 41 (camera): what moves the play camera, measured as the lead sees it (game/camera/camera_trace.gd).
#
# camera-trace: CameraPlaytest plays his case headless at his pose (1920x1080, the default camera): select the army or a
# group, aim at an enemy on screen, hold AIM_S, right-click it; repeat for CAMERA_SECONDS. Per seed it writes
# build/camera-trace/camera_trace_<seed>.json (every jerk event by source, every click's target slip) and prints
# CAMERA_TRACE / CAMERA_SLIP lines; tests/camera/camera_report.py adds the seeds up into one table.
# CAMERA_FLAGS passes game flags (a K2 switch, e.g. CAMERA_FLAGS="--camera-glide=off"). Seeds: 9501-9512 (C41.1).
.PHONY: camera-trace camera-trace-windowed camera-clip

CAMERA_TRACE_DIR := $(BUILD_DIR)/camera-trace
CAMERA_SEEDS ?= 9501
CAMERA_ARENA ?= terminus
CAMERA_SECONDS ?= 150
CAMERA_JOBS ?= 4
CAMERA_GAME_FLAGS = --skirmish --enemy=cpu --arena=$(CAMERA_ARENA) --no-pick-faction --hints=off --announcer=off --music=off \
	--announcer-history=off --music-history=off --camera-readout=off --camera-autoplay --camera-seconds=$(CAMERA_SECONDS)

camera-trace: native-fresh import ## Round 41 (camera K1): his attack-click case played headless; jerk events by source + target slip (CAMERA_SEEDS="9501 9502" CAMERA_ARENA=terminus CAMERA_SECONDS=150 CAMERA_FLAGS=...)
	rm -rf $(CAMERA_TRACE_DIR) && mkdir -p $(CAMERA_TRACE_DIR)
	printf '%s\n' $(CAMERA_SEEDS) | xargs -P $(CAMERA_JOBS) -I{} sh -c '$(GODOT) --headless --fixed-fps 60 --path . -- $(CAMERA_GAME_FLAGS) \
		--seed={} --camera-trace=$(CURDIR)/$(CAMERA_TRACE_DIR) $(CAMERA_FLAGS) > $(CAMERA_TRACE_DIR)/run_{}.log 2>&1 || true'
	grep -h -E 'CAMERA_TRACE|CAMERA_SLIP|SCRIPT ERROR' $(CAMERA_TRACE_DIR)/run_*.log || true
	python3 tests/camera/camera_report.py $(CAMERA_TRACE_DIR) | tee $(CAMERA_TRACE_DIR)/report.md
	test $$(grep -l 'CAMERA_TRACE_DONE ok=true' $(CAMERA_TRACE_DIR)/run_*.log | wc -l) -eq $(words $(CAMERA_SEEDS))
	! grep -l 'SCRIPT ERROR' $(CAMERA_TRACE_DIR)/run_*.log

# The same session in a 1920x1080 window (needs a display: builder0's desktop, or the laptop under its lock): real frame
# pacing and the FX, so CameraShake's view offset is in the trace (headless has no FxWorld, so no shake).
camera-trace-windowed: native-fresh import ## Round 41 (camera K1): camera-trace in a window, with FX and shake (needs a display)
	rm -rf $(CAMERA_TRACE_DIR) && mkdir -p $(CAMERA_TRACE_DIR)
	for seed in $(CAMERA_SEEDS); do $(GODOT) --path . --resolution 1920x1080 -- $(CAMERA_GAME_FLAGS) --render-preset=desktop \
		--seed=$$seed --camera-trace=$(CURDIR)/$(CAMERA_TRACE_DIR) $(CAMERA_FLAGS) > $(CAMERA_TRACE_DIR)/run_$$seed.log 2>&1 || true; done
	grep -h -E 'CAMERA_TRACE|CAMERA_SLIP|SCRIPT ERROR' $(CAMERA_TRACE_DIR)/run_*.log || true
	python3 tests/camera/camera_report.py $(CAMERA_TRACE_DIR) | tee $(CAMERA_TRACE_DIR)/report.md
	test $$(grep -l 'CAMERA_TRACE_DONE ok=true' $(CAMERA_TRACE_DIR)/run_*.log | wc -l) -eq $(words $(CAMERA_SEEDS))

# K3's clip for the lead: the same autoplay filmed twice on one seed, glide OFF (round 40) left and ON right, side by side
# -> CAMERA_CLIP_MOVIE (needs a display; on the laptop take /tmp/tank-squad-laptop-godot.lock). Movie mode renders every
# frame at DEMO_FPS whatever the machine's speed, so the clip plays at game speed. The overlay draws the autoplay's cursor
# (a movie has no OS cursor) and a ring where it right-clicks.
# The default CAMERA_CLIP_MOVIE is under build/, which the next `make remote` / `make gcp-remote` copy-back wipes (--delete):
# copy the mp4 out, or pass CAMERA_CLIP_MOVIE=<a path outside build/>.
CAMERA_CLIP_SEED ?= 9501
CAMERA_CLIP_SECONDS ?= 75
CAMERA_CLIP_FROM ?= 4
CAMERA_CLIP_RES ?= 1280x720
CAMERA_CLIP_MOVIE ?= $(CURDIR)/$(BUILD_DIR)/camera-clip/camera_glide_clip.mp4
camera-clip: native-fresh import ## Round 41 (camera K3): his attack-click case filmed glide OFF v ON side by side -> CAMERA_CLIP_MOVIE (needs a display; CAMERA_CLIP_SEED, CAMERA_CLIP_SECONDS)
	@out=$(BUILD_DIR)/camera-clip; rm -rf $$out && mkdir -p $$out; commit=$$(git rev-parse --short HEAD); \
	echo ">> camera-clip on $$(hostname) commit $$commit | seed $(CAMERA_CLIP_SEED) | $(CAMERA_CLIP_SECONDS) s"; \
	for arm in off on; do \
		if [ $$arm = off ]; then cap="BEFORE: round 40 camera ($$commit, --camera-glide=off)"; else cap="AFTER: glide ON ($$commit)"; fi; \
		timeout 1800 $(GODOT) --path . --fixed-fps $(DEMO_FPS) --resolution $(CAMERA_CLIP_RES) --write-movie $(CURDIR)/$$out/$$arm.avi -- \
			$(CAMERA_GAME_FLAGS) --camera-seconds=$(CAMERA_CLIP_SECONDS) --seed=$(CAMERA_CLIP_SEED) \
			--camera-trace=$(CURDIR)/$$out/$$arm --camera-glide=$$arm "--camera-clip=$$cap" > $$out/$$arm.log 2>&1 || true; \
		grep -E "CAMERA_SLIP|CAMERA_TRACE_DONE|SCRIPT ERROR" $$out/$$arm.log | cut -c1-300 || true; \
	done; \
	ffmpeg -loglevel error -y -ss $(CAMERA_CLIP_FROM) -i $$out/off.avi -ss $(CAMERA_CLIP_FROM) -i $$out/on.avi \
		-filter_complex "[0:v][1:v]hstack=inputs=2,scale=1920:-2[v]" -map "[v]" -c:v libx264 -preset slow -crf 22 \
		-pix_fmt yuv420p -movflags +faststart "$(CAMERA_CLIP_MOVIE)" && echo "CAMERA_CLIP_MOVIE $(CAMERA_CLIP_MOVIE)"
