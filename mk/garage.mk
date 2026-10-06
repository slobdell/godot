# Garage: pre-match army building (GA0-GA4)
# Owner: garage (see _agents/workstreams.md). Included by the root Makefile.

.PHONY: garage garage-smoke garage-shots garage-e2e garage-preset-army

GARAGE_SHOTS := $(BUILD_DIR)/screenshots

garage: import ## Build an army of fixed unit types on a budget (tap/drag), then FIGHT a skirmish with it (ENEMY=cpu|cpu:<archetype from Army.ARCHETYPES>)
	$(GODOT) --path . -- --garage $(if $(filter command line,$(origin ENEMY)),--enemy=$(ENEMY))

garage-smoke: import ## Headless: open the garage, tap FIGHT; the skirmish must start with the saved army and log no errors
	mkdir -p $(BUILD_DIR)
	@# The game's exit code is read (round 18, ship; lent): a run that prints every marker and then aborts is red.
	s=0; timeout 600 $(GODOT) --headless --path . --quit-after 180 -- --garage --garage-scratch --garage-autofight --enemy=cpu:siege --seed=4 \
		> $(BUILD_DIR)/garage-smoke.log 2>&1 || s=$$?; \
	grep -E 'TANK_SQUAD_READY|GARAGE_FIGHT' $(BUILD_DIR)/garage-smoke.log || true; \
	tools/exit_gate.sh garage-smoke $$s $(BUILD_DIR)/garage-smoke.log
	grep -q 'TANK_SQUAD_READY role=GARAGE' $(BUILD_DIR)/garage-smoke.log
	@# Round 19 (G1): 1000 credits = 5,000 points both sides; the CPU's army is bought by the garage (a file) at its faction.
	grep -Eq 'GARAGE_FIGHT player=user://garage_scratch/[a-z_]+\.json enemy=cpu:siege enemy_path=user://army_fight/garage_enemy\.json seed=4 budget=5000 green=[1-9][0-9]* rust=[1-9][0-9]* faction=condemned enemy_faction=(gangs|law|syndicate)' $(BUILD_DIR)/garage-smoke.log
	grep -q 'HUD_MESSAGE \[info\] Your squads hold' $(BUILD_DIR)/garage-smoke.log
	! grep -E 'ERROR' $(BUILD_DIR)/garage-smoke.log
	@echo "garage-smoke passed"

# Windows are clamped to the monitor, so the phone shot uses a 20:9 size that fits; tests/test_garage_screen.gd
# checks tap-target sizes at a true 2400x1080.
garage-shots: import ## Garage screenshots at desktop 1920x1080 and a 20:9 phone aspect, each faction and the fight (needs a display) -> build/screenshots/garage-*.png
	mkdir -p $(GARAGE_SHOTS)
	$(GODOT) --path . --resolution 1920x1080 -- --garage --garage-scratch --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-desktop.png --screenshot-delay=2
	$(GODOT) --path . --resolution 1800x810 -- --garage --garage-scratch --ui-touch --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-phone.png --screenshot-delay=2
	for f in gangs law syndicate; do \
		$(GODOT) --path . --resolution 1920x1080 -- --garage --garage-scratch --faction=$$f --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-$$f.png --screenshot-delay=2; \
	done
	$(GODOT) --path . --resolution 1920x1080 -- --garage --garage-scratch --garage-autofight --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/garage-fight.png --screenshot-delay=3
	@echo "Now LOOK at $(GARAGE_SHOTS)/garage-*.png"

garage-e2e: import ## Build a mixed army with the ArmyDraft API, save it to user://, and fight a full headless match with it
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . --script res://tests/garage/build_army.gd 2>&1 | tee $(BUILD_DIR)/garage-e2e-build.log | grep GARAGE_ARMY
	! grep -E 'ERROR' $(BUILD_DIR)/garage-e2e-build.log
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --time-limit=300 --seed=5 \
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
garage-web-smoke: export-web $(WEB_SMOKE_DEPS) ## Browser: ?garage renders, FIGHT hands over to the skirmish, and the match loop (results → REMATCH → ARMY) runs -> build/screenshots/web-garage*.png, web-army-loop.png
	mkdir -p $(BUILD_DIR)/screenshots
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 >/dev/null 2>&1 & server=$$!; \
	trap 'kill $$server || true' EXIT; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs "http://127.0.0.1:$(SMOKE_PORT)/?garage&garage-scratch" \
		$(BUILD_DIR)/screenshots/web-garage.png 3 "TANK_SQUAD_READY role=GARAGE" && \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs \
		"http://127.0.0.1:$(SMOKE_PORT)/?garage&garage-scratch&garage-autofight&enemy=cpu:armor&seed=3" \
		$(BUILD_DIR)/screenshots/web-garage-fight.png 3 GARAGE_FIGHT && \
	SMOKE_TIMEOUT_MS=240000 CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs \
		"http://127.0.0.1:$(SMOKE_PORT)/?garage&garage-scratch&garage-autofight&enemy=cpu:swarm&seed=4&army-loop-time=6&army-loop-delay=1&army-loop-auto=rematch,army" \
		$(BUILD_DIR)/screenshots/web-army-loop.png 3 "ARMY_LOOP action=army"

.PHONY: army-loop-smoke army-loop-shots
army-loop-smoke: import ## Headless match loop: army → FIGHT → results → REMATCH → results → ARMY; checks the markers and that nothing errors
	mkdir -p $(BUILD_DIR)
	s=0; timeout 600 $(GODOT) --headless --path . -- --garage --garage-scratch --garage-autofight --enemy=cpu:swarm --seed=4 \
		--army-loop-time=6 --army-loop-delay=0.5 --army-loop-auto=rematch,army,quit \
		> $(BUILD_DIR)/army-loop-smoke.log 2>&1 || s=$$?; \
	grep -E 'GARAGE_FIGHT|ARMY_RESULTS|ARMY_LOOP' $(BUILD_DIR)/army-loop-smoke.log || true; \
	tools/exit_gate.sh army-loop-smoke $$s $(BUILD_DIR)/army-loop-smoke.log
	test $$(grep -c 'GARAGE_FIGHT .*enemy=cpu:swarm .*seed=4 ' $(BUILD_DIR)/army-loop-smoke.log) -eq 2
	test $$(grep -c 'ARMY_RESULTS outcome=' $(BUILD_DIR)/army-loop-smoke.log) -eq 2
	grep -q 'ARMY_LOOP action=rematch' $(BUILD_DIR)/army-loop-smoke.log
	grep -q 'ARMY_LOOP action=army' $(BUILD_DIR)/army-loop-smoke.log
	test $$(grep -c 'TANK_SQUAD_READY role=GARAGE' $(BUILD_DIR)/army-loop-smoke.log) -eq 3
	$(PYTHON) -c "import re; log=open('$(BUILD_DIR)/army-loop-smoke.log').read(); \
		budget=int(re.search(r'GARAGE_FIGHT .* budget=(\d+)', log).group(1)); \
		costs=[int(c) for c in re.findall(r'SKIRMISH_ARMY Rust .*\((\d+) pts\)', log)]; \
		assert costs and all(c <= budget for c in costs), ('the CPU army must fit the player tier budget', budget, costs); \
		print('CPU armies fit the tier budget:', costs, '<=', budget)"
	! grep -E 'ERROR' $(BUILD_DIR)/army-loop-smoke.log
	s=0; timeout 600 $(GODOT) --headless --path . -- --garage --garage-scratch --challenge=scout_hunt --army-loop-time=6 --army-loop-delay=0.5 \
		--army-loop-auto=quit > $(BUILD_DIR)/army-challenge-smoke.log 2>&1 || s=$$?; \
	grep -E 'ARMY_CHALLENGE|ARMY_RESULTS' $(BUILD_DIR)/army-challenge-smoke.log || true; \
	tools/exit_gate.sh army-loop-smoke/challenge $$s $(BUILD_DIR)/army-challenge-smoke.log
	grep -Eq 'ARMY_CHALLENGE id=scout_hunt green=3 rust=5' $(BUILD_DIR)/army-challenge-smoke.log
	grep -q 'ARMY_RESULTS outcome=' $(BUILD_DIR)/army-challenge-smoke.log
	! grep -E 'ERROR' $(BUILD_DIR)/army-challenge-smoke.log
	@echo "army-loop-smoke passed"

army-loop-shots: import ## Results screen screenshots after a real 70 s skirmish, desktop and 20:9 phone (needs a display) -> build/screenshots/army-results-*.png
	mkdir -p $(GARAGE_SHOTS)
	$(GODOT) --path . --resolution 1920x1080 -- --garage --garage-scratch --garage-autofight --enemy=cpu:armor --seed=7 --mute \
		--army-loop-time=70 --army-loop-delay=0.5 --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/army-results-desktop.png --screenshot-delay=76
	$(GODOT) --path . --resolution 1800x810 -- --garage --garage-scratch --garage-autofight --enemy=cpu:armor --seed=7 --mute \
		--army-loop-time=70 --army-loop-delay=0.5 --screenshot=$(CURDIR)/$(GARAGE_SHOTS)/army-results-phone.png --screenshot-delay=76
	@echo "Now LOOK at $(GARAGE_SHOTS)/army-results-*.png"

.PHONY: garage-tour
TOUR_DIR := $(BUILD_DIR)/screenshots/garage-tour
TOUR_MATCH ?= 25

# Round 13 (G1): the garage as a player meets it, from the title, by taps (tests/garage/garage_tour.gd). The phone run
# uses the touch UI and a 20:9 window that fits builder0's monitor (the same size as garage-shots).
garage-tour: import ## A player's garage loop with a display: title → GARAGE → build → FIGHT → results → REMATCH → ARMY, a frame per step at 1920x1080 and 20:9 -> build/screenshots/garage-tour/{desktop,phone}/
	rm -rf $(TOUR_DIR) && mkdir -p $(TOUR_DIR)/desktop $(TOUR_DIR)/phone
	status=0; \
	timeout 600 $(GODOT) --path . --resolution 1920x1080 --script res://tests/garage/garage_tour.gd -- --tour-fresh \
		--tour-out=$(CURDIR)/$(TOUR_DIR)/desktop --tour-match=$(TOUR_MATCH) > $(TOUR_DIR)/desktop.log 2>&1 || status=1; \
	timeout 600 $(GODOT) --path . --resolution 1800x810 --script res://tests/garage/garage_tour.gd -- --tour-fresh --ui-touch \
		--tour-out=$(CURDIR)/$(TOUR_DIR)/phone --tour-match=$(TOUR_MATCH) > $(TOUR_DIR)/phone.log 2>&1 || status=1; \
	grep -hE '^(TOUR_|MUSIC_TRACK|GARAGE_FIGHT|ARMY_RESULTS|ANNOUNCER_BOOTH|MUSIC on)|ERROR' $(TOUR_DIR)/desktop.log $(TOUR_DIR)/phone.log; \
	echo "Now LOOK at $(TOUR_DIR)/*/*.png"; exit $$status

.PHONY: ui-kit-shots
KIT_SHOTS := $(BUILD_DIR)/screenshots/ui-kit
KIT_ELEMENTS := palette type frame button card chip tag meter crest heading

# Round 19 (G2): the UI kit (_agents/ui_kit.md) photographed, one frame per element plus the whole sheet at desktop
# and phone aspect. The doc's pictures come from here; a kit change is looked at here before any screen uses it.
ui-kit-shots: import ## The UI kit's gallery: one frame per element + the sheet at 1920x1080 and 20:9 (needs a display) -> build/screenshots/ui-kit/*.png
	rm -rf $(KIT_SHOTS) && mkdir -p $(KIT_SHOTS)
	status=0; \
	timeout 120 $(GODOT) --path . --resolution 1920x1080 res://game/ui/widgets/kit/ui_kit_gallery.tscn -- \
		--screenshot=$(CURDIR)/$(KIT_SHOTS)/sheet-desktop.png > $(KIT_SHOTS)/sheet-desktop.log 2>&1 || status=1; \
	timeout 120 $(GODOT) --path . --resolution 1800x810 res://game/ui/widgets/kit/ui_kit_gallery.tscn -- --ui-touch \
		--screenshot=$(CURDIR)/$(KIT_SHOTS)/sheet-phone.png > $(KIT_SHOTS)/sheet-phone.log 2>&1 || status=1; \
	for e in $(KIT_ELEMENTS); do \
		timeout 120 $(GODOT) --path . --resolution 1280x720 res://game/ui/widgets/kit/ui_kit_gallery.tscn -- --kit-element=$$e \
			--screenshot=$(CURDIR)/$(KIT_SHOTS)/$$e.png > $(KIT_SHOTS)/$$e.log 2>&1 || status=1; \
	done; \
	! grep -lE 'ERROR|SCRIPT ERROR' $(KIT_SHOTS)/*.log || status=1; \
	ls $(KIT_SHOTS)/*.png; echo "Now LOOK at $(KIT_SHOTS)/*.png"; exit $$status
