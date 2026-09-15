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
