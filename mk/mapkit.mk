# Map kit (round 47, mapkit stream): the cheap pieces (_agents/arenas.md *The cheap-piece map kit backlog*) and the
# blast doors. Owner: mapkit (_agents/streams/mapkit.md).

.PHONY: mapkit-looks mapkit-gpu

LOOKS_SCREEN ?= 1920x1080
LOOKS_DIR ?= $(BUILD_DIR)/mapkit-looks

# Needs a display. builder3 runs Xorg on :1 (not Xwayland, so remote.sh exports no DISPLAY there): pass it inside the
# quotes, make remote T="mapkit-looks DISPLAY=:1 XAUTHORITY=/run/user/1000/gdm/Xauthority".
mapkit-looks: import ## Mapkit P1: every candidate look (doors shut/open, sight screens, overpass, tank traps, pipes, crane) at his camera beside a dozer -> build/mapkit-looks/looks-*.png [ONLY=door_a_shut,traps_b YAW=30 LOOKS_SCREEN=1920x1080 KIT_LOOK=plain|trim]
	@mkdir -p $(LOOKS_DIR)
	timeout 180 $(GODOT) --path . --resolution $(LOOKS_SCREEN) res://tests/mapkit/looks_gallery.tscn -- \
		--shots-dir=$(abspath $(LOOKS_DIR)) $(if $(ONLY),--only=$(ONLY)) $(if $(YAW),--yaw=$(YAW)) \
		$(if $(KIT_LOOK),--kit-look=$(KIT_LOOK) --suffix=-$(KIT_LOOK))

# C47.10: the laptop's GPU cost of each built piece at his camera and his laptop preset, beside an empty floor. The ONE local
# Godot run this stream makes (C47.1), under the laptop lock; the screen twice (steam forced, strips forced).
GPU_IDS ?= built_traps,built_monorail,built_door_shut,built_screen
mapkit-gpu: import ## Mapkit C47.10: each built piece's GPU ms at his pose on THIS machine (laptop: under the laptop lock) -> MAPKIT_GPU lines [GPU_IDS=]
	@for look in steam strips; do \
		flock /tmp/tank-squad-laptop-godot.lock timeout 300 $(GODOT) --path . --resolution 1920x1080 res://tests/mapkit/looks_gallery.tscn -- \
			--gpu-ms --only=$(GPU_IDS) --screen-look=$$look --render-preset=laptop 2>&1 | grep MAPKIT_GPU; \
	done
	@flock /tmp/tank-squad-laptop-godot.lock timeout 300 $(GODOT) --path . --resolution 1920x1080 res://tests/mapkit/looks_gallery.tscn -- \
		--gpu-ms --only=$(GPU_IDS) --kit-look=trim --render-preset=laptop 2>&1 | grep MAPKIT_GPU

# P1b (R47.28, his ask): Material Maker (MIT, pinned at MM_COMMIT in MM_DIR, OUTSIDE the repo) renders ONE trim sheet for the
# kit pieces from assets/props/trim/trim_sheet.ptex. It renders on the GPU: builder3's Xorg (pass DISPLAY in the quotes, as
# mapkit-looks) or the laptop under its lock. Output -> build/mapkit-trim/; `make mapkit-trim-adopt` copies the PNGs into
# assets/props/trim/ (committed). No paid generation; nothing downloaded at export time (a local .ptex only).
MM_DIR ?= $(HOME)/tools/material-maker
MM_COMMIT := 7d6daae3c74c09720afe4138ce09699ab3591ce1
TRIM_SIZE ?= 1024
.PHONY: mapkit-trim mapkit-trim-adopt
mapkit-trim: ## P1b: render the kit's trim sheet with Material Maker (needs MM_DIR at MM_COMMIT and a display) -> build/mapkit-trim/
	@test "$$(git -C $(MM_DIR) rev-parse HEAD 2>/dev/null)" = "$(MM_COMMIT)" || { echo "mapkit-trim: $(MM_DIR) is not Material Maker at $(MM_COMMIT)"; exit 2; }
	@mkdir -p $(BUILD_DIR)/mapkit-trim
	cd $(MM_DIR) && timeout 300 $(abspath $(GODOT)) --headless --path . --import > /dev/null 2>&1 || true
	cd $(MM_DIR) && timeout 300 $(abspath $(GODOT)) --path . --export-material -t "Godot/Godot 4 Standard" -o $(abspath $(BUILD_DIR)/mapkit-trim) \
		--size $(TRIM_SIZE) $(abspath assets/props/trim/trim_sheet.ptex)
	ls -la $(BUILD_DIR)/mapkit-trim
mapkit-trim-adopt: ## P1b: copy the rendered trim sheet PNGs from build/mapkit-trim/ into assets/props/trim/
	cp $(BUILD_DIR)/mapkit-trim/*.png assets/props/trim/

# Bar P (round 47, workstreams.md): the map-kit twins v their maps, native ON, seeds 12901-12932 -> build/bar-p*.json.
# A JUDGED series: builder3, the orchestrator's slot only (C47.1). make remote T="mapkit-bar-p native" (native built first).
.PHONY: mapkit-bar-p
mapkit-bar-p: import ## Mapkit Bar P: parade v parade_traps / parade_rail, crossing v crossing_screens (gangs v syndicate both orders) -> build/bar-p.json [BAR_P_JOBS=10]
	$(PYTHON) tests/mapkit/bar_p_series.py --godot $(GODOT) --jobs $(or $(BAR_P_JOBS),10) --raw $(BUILD_DIR)/bar-p-raw.json --json $(BUILD_DIR)/bar-p.json

# Blast doors on a real arena (round 47): 12 CPU fights on terminus_doors watched by the probe's door report (not a bar).
.PHONY: mapkit-doors-watch
mapkit-doors-watch: import ## Mapkit: CPU fights on terminus_doors, each one's door events, booth calls, crossings by side and state, holds -> build/doors-watch.json
	$(PYTHON) tests/mapkit/doors_watch.py --godot $(GODOT) --json $(BUILD_DIR)/doors-watch.json
