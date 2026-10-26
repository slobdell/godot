# Round 41 (camera): what moves the play camera, measured as the lead sees it (game/camera/camera_trace.gd).
#
# camera-trace: CameraPlaytest plays his case headless at his pose (1920x1080, the default camera): select the army or a
# group, aim at an enemy on screen, hold AIM_S, right-click it; repeat for CAMERA_SECONDS. Per seed it writes
# build/camera-trace/camera_trace_<seed>.json (every jerk event by source, every click's target slip) and prints
# CAMERA_TRACE / CAMERA_SLIP lines; tests/camera/camera_report.py adds the seeds up into one table.
# CAMERA_FLAGS passes game flags (a K2 switch, e.g. CAMERA_FLAGS="--camera-glide=off"). Seeds: 9501-9512 (C41.1).
.PHONY: camera-trace camera-trace-windowed

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
