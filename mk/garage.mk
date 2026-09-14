# Garage: pre-match army building (GA0-GA4)
# Owner: garage (see _agents/workstreams.md). Included by the root Makefile.

.PHONY: garage garage-smoke garage-shots garage-e2e

GARAGE_SHOTS := $(BUILD_DIR)/screenshots

garage: import ## Build an army on a budget (tap/drag), then FIGHT a skirmish with it (ENEMY=individuals|anvil_hammer|flame_rush)
	$(GODOT) --path . -- --garage --enemy=$(ENEMY)

garage-smoke: import ## Headless: open the garage, tap FIGHT; the skirmish must start with the saved army and log no errors
	mkdir -p $(BUILD_DIR)
	timeout 60 $(GODOT) --headless --path . --quit-after 180 -- --garage --garage-autofight --enemy=flame_rush \
		2>&1 | tee $(BUILD_DIR)/garage-smoke.log | grep -E 'TANK_SQUAD_READY|GARAGE_FIGHT' || true
	grep -q 'TANK_SQUAD_READY role=GARAGE' $(BUILD_DIR)/garage-smoke.log
	grep -Eq 'GARAGE_FIGHT player=user://doctrines/[a-z0-9_]+\.json enemy=flame_rush green=[1-9] rust=5' $(BUILD_DIR)/garage-smoke.log
	! grep -E 'ERROR' $(BUILD_DIR)/garage-smoke.log
	@echo "garage-smoke passed"

# Windows are clamped to the monitor, so the phone shot uses a 20:9 size that fits; tests/test_garage_screen.gd
# checks tap-target sizes at a true 2400x1080.
garage-shots: import ## Garage screenshots at desktop 1920x1080 and a 20:9 phone aspect (needs a display) -> build/screenshots/garage-*.png
	mkdir -p $(GARAGE_SHOTS)
	$(GODOT) --path . --resolution 1920x1080 -- --garage --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-desktop.png --screenshot-delay=2
	$(GODOT) --path . --resolution 1800x810 -- --garage --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-phone.png --screenshot-delay=2
	$(GODOT) --path . --resolution 1920x1080 -- --garage --garage-autofight --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-fight.png --screenshot-delay=3
	@echo "Now LOOK at $(GARAGE_SHOTS)/garage-*.png"
