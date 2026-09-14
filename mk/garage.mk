# Garage: pre-match army building (GA0-GA4)
# Owner: garage (see _agents/workstreams.md). Included by the root Makefile.

.PHONY: garage garage-smoke garage-shots garage-e2e garage-cpu-army

GARAGE_SHOTS := $(BUILD_DIR)/screenshots

garage: import ## Build an army on a budget (tap/drag), then FIGHT a skirmish with it (ENEMY=cpu:balanced|cpu:rush|cpu:turtle|cpu:flamers|<doctrine>)
	$(GODOT) --path . -- --garage $(if $(filter command line,$(origin ENEMY)),--enemy=$(ENEMY))

garage-smoke: import ## Headless: open the garage, tap FIGHT; the skirmish must start with the saved army and log no errors
	mkdir -p $(BUILD_DIR)
	timeout 60 $(GODOT) --headless --path . --quit-after 180 -- --garage --garage-settings=none --garage-autofight --enemy=cpu:flamers --seed=4 \
		2>&1 | tee $(BUILD_DIR)/garage-smoke.log | grep -E 'TANK_SQUAD_READY|GARAGE_FIGHT' || true
	grep -q 'TANK_SQUAD_READY role=GARAGE' $(BUILD_DIR)/garage-smoke.log
	grep -Eq 'GARAGE_FIGHT player=user://doctrines/[a-z0-9_]+\.json enemy=cpu:flamers enemy_path=user://doctrines/cpu/flamers.json seed=4 green=[1-9] rust=5' $(BUILD_DIR)/garage-smoke.log
	grep -q 'HUD_MESSAGE \[info\] Your squads hold' $(BUILD_DIR)/garage-smoke.log
	! grep -E 'ERROR' $(BUILD_DIR)/garage-smoke.log
	@echo "garage-smoke passed"

# Windows are clamped to the monitor, so the phone shot uses a 20:9 size that fits; tests/test_garage_screen.gd
# checks tap-target sizes at a true 2400x1080.
garage-shots: import ## Garage screenshots at desktop 1920x1080 and a 20:9 phone aspect (needs a display) -> build/screenshots/garage-*.png
	mkdir -p $(GARAGE_SHOTS)
	$(GODOT) --path . --resolution 1920x1080 -- --garage --garage-settings=none --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-desktop.png --screenshot-delay=2
	$(GODOT) --path . --resolution 1800x810 -- --garage --garage-settings=none --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-phone.png --screenshot-delay=2
	$(GODOT) --path . --resolution 1920x1080 -- --garage --garage-settings=none --garage-panel=compare --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-compare.png --screenshot-delay=2
	$(GODOT) --path . --resolution 1920x1080 -- --garage --garage-settings=none --garage-autofight --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-fight.png --screenshot-delay=3
	@echo "Now LOOK at $(GARAGE_SHOTS)/garage-*.png"

garage-e2e: import ## GA3: build an army with the garage's Loadout API, save it to user://, and fight a full headless match with it
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . --script res://tests/garage/build_army.gd 2>&1 | tee $(BUILD_DIR)/garage-e2e-build.log | grep GARAGE_ARMY
	! grep -E 'ERROR' $(BUILD_DIR)/garage-e2e-build.log
	$(GODOT) --headless --fixed-fps 60 --path . -- --match --elimination --time-limit=300 --seed=5 \
		--green-doctrine=$$(grep -o 'user://[^ ]*' $(BUILD_DIR)/garage-e2e-build.log) --rust-doctrine=res://doctrines/individuals.json \
		2>&1 | tee $(BUILD_DIR)/garage-e2e.log | grep MATCH_RESULT
	! grep -E 'ERROR' $(BUILD_DIR)/garage-e2e.log
	$(PYTHON) -c "import json; r=json.loads(open('$(BUILD_DIR)/garage-e2e.log').read().split('MATCH_RESULT ')[1].splitlines()[0]); \
		assert r['tanks']['green'] == 5, ('the garage army must field 5 tanks', r['tanks']); \
		assert r['reason'] in ('elimination', 'time_limit'), r['reason']; assert r['stats']['shots'][0] > 0, 'the garage army never fired'; \
		print('garage-e2e passed:', r['reason'], 'winner', r['winner'], 'sim', r['sim_seconds'], 's, green shots', r['stats']['shots'][0])"

PRESET ?= balanced

garage-cpu-army: import ## Write a seeded CPU army (PRESET=balanced|rush|turtle|flamers SEED=1) to user://doctrines/cpu/, e.g. for make skirmish ENEMY=<printed path>
	$(GODOT) --headless --path . --script res://tests/garage/build_army.gd -- --preset=$(PRESET) --seed=$(SEED) 2>&1 | grep -E 'GARAGE_ARMY|GARAGE_CODE|ERROR'

.PHONY: garage-web-smoke
garage-web-smoke: export-web $(WEB_SMOKE_DEPS) ## Browser: ?garage renders, and FIGHT hands over to the skirmish (user:// saves work in the browser) -> build/screenshots/web-garage*.png
	mkdir -p $(BUILD_DIR)/screenshots
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 >/dev/null 2>&1 & server=$$!; \
	trap 'kill $$server' EXIT; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs "http://127.0.0.1:$(SMOKE_PORT)/?garage&garage-settings=none" \
		$(BUILD_DIR)/screenshots/web-garage.png 3 "TANK_SQUAD_READY role=GARAGE" && \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs \
		"http://127.0.0.1:$(SMOKE_PORT)/?garage&garage-settings=none&garage-autofight&enemy=cpu:rush&seed=3" \
		$(BUILD_DIR)/screenshots/web-garage-fight.png 3 GARAGE_FIGHT
