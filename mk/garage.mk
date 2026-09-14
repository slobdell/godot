# Garage: pre-match army building (GA0-GA4)
# Owner: garage (see _agents/workstreams.md). Included by the root Makefile.

.PHONY: garage garage-smoke garage-shots garage-e2e garage-preset-army

GARAGE_SHOTS := $(BUILD_DIR)/screenshots

garage: import ## Build an army of fixed unit types on a budget (tap/drag), then FIGHT a skirmish with it (ENEMY=cpu|cpu:<archetype from Army.ARCHETYPES>)
	$(GODOT) --path . -- --garage $(if $(filter command line,$(origin ENEMY)),--enemy=$(ENEMY))

garage-smoke: import ## Headless: open the garage, tap FIGHT; the skirmish must start with the saved army and log no errors
	mkdir -p $(BUILD_DIR)
	timeout 60 $(GODOT) --headless --path . --quit-after 180 -- --garage --garage-scratch --garage-autofight --enemy=cpu:siege --seed=4 \
		2>&1 | tee $(BUILD_DIR)/garage-smoke.log | grep -E 'TANK_SQUAD_READY|GARAGE_FIGHT' || true
	grep -q 'TANK_SQUAD_READY role=GARAGE' $(BUILD_DIR)/garage-smoke.log
	grep -Eq 'GARAGE_FIGHT player=user://garage_scratch/my_army\.json enemy=cpu:siege enemy_path=cpu:siege seed=4 budget=[0-9]+ green=[1-9] rust=[1-9]' $(BUILD_DIR)/garage-smoke.log
	grep -q 'HUD_MESSAGE \[info\] Your squads hold' $(BUILD_DIR)/garage-smoke.log
	! grep -E 'ERROR' $(BUILD_DIR)/garage-smoke.log
	@echo "garage-smoke passed"

# Windows are clamped to the monitor, so the phone shot uses a 20:9 size that fits; tests/test_garage_screen.gd
# checks tap-target sizes at a true 2400x1080.
garage-shots: import ## Garage screenshots at desktop 1920x1080 and a 20:9 phone aspect (needs a display) -> build/screenshots/garage-*.png
	mkdir -p $(GARAGE_SHOTS)
	$(GODOT) --path . --resolution 1920x1080 -- --garage --garage-scratch --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-desktop.png --screenshot-delay=2
	$(GODOT) --path . --resolution 1800x810 -- --garage --garage-scratch --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-phone.png --screenshot-delay=2
	$(GODOT) --path . --resolution 1920x1080 -- --garage --garage-scratch --garage-panel=compare --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-compare.png --screenshot-delay=2
	$(GODOT) --path . --resolution 1920x1080 -- --garage --garage-scratch --garage-autofight --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-fight.png --screenshot-delay=3
	@echo "Now LOOK at $(GARAGE_SHOTS)/garage-*.png"

garage-e2e: import ## Build a mixed army with the ArmyDraft API, save it to user://, and fight a full headless match with it
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . --script res://tests/garage/build_army.gd 2>&1 | tee $(BUILD_DIR)/garage-e2e-build.log | grep GARAGE_ARMY
	! grep -E 'ERROR' $(BUILD_DIR)/garage-e2e-build.log
	$(GODOT) --headless --fixed-fps 60 --path . -- --match --elimination --time-limit=300 --seed=5 \
		--green-doctrine=$$(grep GARAGE_GAME $(BUILD_DIR)/garage-e2e-build.log | grep -o 'user://[^ ]*') --rust-doctrine=res://doctrines/individuals.json \
		2>&1 | tee $(BUILD_DIR)/garage-e2e.log | grep MATCH_RESULT
	! grep -E 'ERROR' $(BUILD_DIR)/garage-e2e.log
	$(PYTHON) -c "import json; r=json.loads(open('$(BUILD_DIR)/garage-e2e.log').read().split('MATCH_RESULT ')[1].splitlines()[0]); \
		assert r['tanks']['green'] == 6, ('the army must field its 6 units', r['tanks']); \
		assert r['reason'] in ('elimination', 'time_limit'), r['reason']; assert r['stats']['shots'][0] > 0, 'the garage army never fired'; \
		print('garage-e2e passed:', r['reason'], 'winner', r['winner'], 'sim', r['sim_seconds'], 's, green shots', r['stats']['shots'][0])"

PRESET ?= anvil_hammer

garage-preset-army: import ## Write a preset army (PRESET=<ArmyPresets id>) to user://doctrines/ and print its army code
	$(GODOT) --headless --path . --script res://tests/garage/build_army.gd -- --preset=$(PRESET) 2>&1 | grep -E 'GARAGE_ARMY|GARAGE_CODE|ERROR'

.PHONY: garage-web-smoke
garage-web-smoke: export-web $(WEB_SMOKE_DEPS) ## Browser: ?garage renders, and FIGHT hands over to the skirmish (user:// saves work in the browser) -> build/screenshots/web-garage*.png
	mkdir -p $(BUILD_DIR)/screenshots
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 >/dev/null 2>&1 & server=$$!; \
	trap 'kill $$server' EXIT; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs "http://127.0.0.1:$(SMOKE_PORT)/?garage&garage-scratch" \
		$(BUILD_DIR)/screenshots/web-garage.png 3 "TANK_SQUAD_READY role=GARAGE" && \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs \
		"http://127.0.0.1:$(SMOKE_PORT)/?garage&garage-scratch&garage-autofight&enemy=cpu:armor&seed=3" \
		$(BUILD_DIR)/screenshots/web-garage-fight.png 3 GARAGE_FIGHT
