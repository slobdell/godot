# FX lab: effect performance measurements and generated FX textures
# Owner: look-and-feel (see _agents/workstreams.md). Included by the root Makefile.

FX_CONFIGS ?=
FX_SECONDS ?= 6
FX_QUALITY ?=

fx-bench: import ## FX lab: worst-case firefight per trick config; prints FX_BENCH lines, writes build/fx-bench.json (needs a display)
	mkdir -p $(BUILD_DIR)/screenshots/fx
	$(GODOT) --path . -- --fx-bench=$(FX_CONFIGS) --fx-bench-seconds=$(FX_SECONDS) \
		$(if $(FX_QUALITY),--fx-quality=$(FX_QUALITY)) \
		--fx-bench-out=$(CURDIR)/$(BUILD_DIR)/fx-bench.json --fx-bench-shot=$(CURDIR)/$(BUILD_DIR)/screenshots/fx \
		2>&1 | tee $(BUILD_DIR)/fx-bench.log | grep -E 'FX_BENCH|ERROR|FX LAB|^ ' || true
	@grep -q FX_BENCH_DONE $(BUILD_DIR)/fx-bench.log

SHOWCASE ?=

fx-shots: import ## Weapon FX close-ups (fire, flight, impact per weapon, real Match + Tanks) → build/screenshots/fx-shots/*.png (needs a display; SHOWCASE=tank_hit,tank_kill,...)
	rm -rf $(BUILD_DIR)/screenshots/fx-shots && mkdir -p $(BUILD_DIR)/screenshots/fx-shots
	timeout 300 $(GODOT) --path . --resolution 1280x720 res://game/theme/fx/bench/weapon_showcase.tscn -- \
		--shots=$(CURDIR)/$(BUILD_DIR)/screenshots/fx-shots $(if $(SHOWCASE),--showcase=$(SHOWCASE)) \
		2>&1 | tee $(BUILD_DIR)/fx-shots.log | grep -E 'FX_SHOT|ERROR|SCRIPT' || true
	@grep -q FX_SHOTS_DONE $(BUILD_DIR)/fx-shots.log
	@! grep -E 'SCRIPT ERROR|ERROR:' $(BUILD_DIR)/fx-shots.log | grep -v 'X11 Display'

LISTEN ?= tank_boom shell_whine shell_hit_armor dirt_impact autocannon_shot mg_loop ricochet bullet_hit_metal weak_spot_hit mortar_launch ui_ack_move ui_ack_attack ui_select

sfx-listen: ## Play the round-3 sounds one after another with their names (LISTEN="tank_boom mg_loop" to pick; needs ffplay or aplay)
	@for s in $(LISTEN); do echo ">> $$s"; ffplay -nodisp -autoexit -loglevel quiet assets/audio/$$s.wav 2>/dev/null || aplay -q assets/audio/$$s.wav; sleep 0.4; done

fx-textures: import ## Regenerate procedural FX textures (explosion flipbook atlas)
	$(GODOT) --headless --path . --script res://game/theme/fx/tools/make_flipbook.gd
	$(GODOT) --headless --path . --import

hud-gallery: import ## HUD widget gallery (frames, banners, conductors); screenshots build/screenshots/hud-gallery{,-phone}.png
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --path . res://game/ui/widgets/gallery/widget_gallery.tscn -- --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/hud-gallery.png --screenshot-delay=4
	$(GODOT) --path . --resolution 1920x864 res://game/ui/widgets/gallery/widget_gallery.tscn -- --ui-touch --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/hud-gallery-phone.png --screenshot-delay=4

vehicle-gallery: import ## Vehicle/weapon FX gallery (team colors, paint, heat, flames, lasers, shields; --gallery-focus=N close-ups) → build/screenshots/vehicle-gallery.png
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --path . res://game/theme/gallery/vehicle_gallery.tscn -- $(if $(FACTION),--gallery-faction=$(FACTION)) --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/vehicle-gallery$(if $(FACTION),-$(FACTION)).png --screenshot-delay=4

sfx: import ## Regenerate the procedural sound effects in assets/audio (CC0, see its README)
	$(GODOT) --headless --path . --script res://game/theme/audio/make_sfx.gd
	$(GODOT) --headless --path . --import

title: import ## Animated title screen (glitch title, live arena backdrop, menu); browser: ?title
	$(GODOT) --path . -- --title

title-shot: import ## Screenshot the title screen → build/screenshots/title.png and title-phone.png
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --path . res://game/ui/widgets/title/title_screen.tscn -- --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/title.png --screenshot-delay=5
	$(GODOT) --path . --resolution 1600x720 res://game/ui/widgets/title/title_screen.tscn -- --ui-touch --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/title-phone.png --screenshot-delay=5

PERF_BUDGET ?= 6500
PERF_RES ?= 1280x720
PERF_WARMUP ?= 8
PERF_SECONDS ?= 2.5
PERF_CYCLES ?= 2
PERF_FLAGS ?=
PERF_NAME ?= perf-scene

perf-scene: import ## M1: frame cost of a live 30-a-side CPU skirmish, by layer → build/$(PERF_NAME).json, PERF_SCENE lines, build/screenshots/$(PERF_NAME).png (needs a display; PERF_RES, PERF_FLAGS="--fx-quality=low", PERF_LAYERS=, PERF_SOUND=1 unmuted)
	mkdir -p $(BUILD_DIR)/screenshots
	timeout 600 $(GODOT) --path . --resolution $(PERF_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
		--budget=$(PERF_BUDGET) --no-pick-faction --cinematic $(if $(PERF_SOUND),,--mute) \
		--perf-scene=$(CURDIR)/$(BUILD_DIR)/$(PERF_NAME).json --perf-shot=$(CURDIR)/$(BUILD_DIR)/screenshots/$(PERF_NAME).png \
		--perf-warmup=$(PERF_WARMUP) --perf-seconds=$(PERF_SECONDS) --perf-cycles=$(PERF_CYCLES) \
		$(if $(PERF_LAYERS),--perf-layers=$(PERF_LAYERS)) $(PERF_FLAGS) \
		2>&1 | tee $(BUILD_DIR)/$(PERF_NAME).log | grep -E '^PERF_SCENE|SCRIPT ERROR' || true
	@echo "instance-uniform errors: $$(grep -c 'Too many instances using shader instance variables' $(BUILD_DIR)/$(PERF_NAME).log || true)"
	@echo "other engine errors:     $$(grep -E '^ERROR|SCRIPT ERROR' $(BUILD_DIR)/$(PERF_NAME).log | grep -vc 'Too many instances using shader instance variables' || true)"
	@grep -q PERF_SCENE_DONE $(BUILD_DIR)/$(PERF_NAME).log

CROWD_RES ?= 1920x1080
crowd-look: import ## Feel X1: can a player see the crowd? A real skirmish shot at every camera zoom, with/without the crowd and fog → build/crowd-look/*.png, CROWD_LOOK lines (needs a display; CROWD_FLAGS="--fx-quality=low", ARENA=)
	rm -rf $(BUILD_DIR)/crowd-look && mkdir -p $(BUILD_DIR)/crowd-look
	timeout 600 $(GODOT) --path . --resolution $(CROWD_RES) -- --skirmish --scripted --seed=3 --no-pick-faction --mute \
		$(if $(ARENA),--arena=$(ARENA)) --crowd-look=$(CURDIR)/$(BUILD_DIR)/crowd-look $(CROWD_FLAGS) \
		2>&1 | tee $(BUILD_DIR)/crowd-look/log.txt | grep -E '^CROWD_LOOK|SCRIPT ERROR|^SKIRMISH_CAMERA' || true
	@grep -q CROWD_LOOK_DONE $(BUILD_DIR)/crowd-look/log.txt
