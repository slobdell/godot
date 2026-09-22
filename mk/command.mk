# Commanding: desktop controls, tactical map, camera, readability
# Owner: control (round 3; see _agents/workstreams.md). Included by the root Makefile.

CONTROL_PLAYTEST_DIR := $(BUILD_DIR)/control-playtest
## Extra skirmish flags for the playtests, e.g. CONTROL_FLAGS=--no-vision-camera to compare against a free camera.
CONTROL_FLAGS ?=

control-playtest: import ## Headless: box select, attack-move, a queued route, a group swap, a unit rejoining; every order's response tick in build/control-playtest/headless/orders.jsonl
	rm -rf $(CONTROL_PLAYTEST_DIR)/headless && mkdir -p $(CONTROL_PLAYTEST_DIR)/headless
	timeout 120 $(GODOT) --headless --path . -- --skirmish --enemy=cpu --seed=3 --control-playtest=$(CURDIR)/$(CONTROL_PLAYTEST_DIR)/headless $(CONTROL_FLAGS) 2>&1 \
		| tee $(CONTROL_PLAYTEST_DIR)/headless/run.log | grep -E 'CONTROL_PLAYTEST|SCRIPT ERROR|^ERROR' || true
	grep -q 'CONTROL_PLAYTEST_DONE ok=true' $(CONTROL_PLAYTEST_DIR)/headless/run.log
	! grep -E 'SCRIPT ERROR|^ERROR' $(CONTROL_PLAYTEST_DIR)/headless/run.log

CONTROL_SIZES ?= 1920x1080 1280x720

control-playtest-shots: import ## The same session in windows (CONTROL_SIZES, default 1920x1080 1280x720), screenshots in build/control-playtest/<size>/*.png (needs a display)
	for size in $(CONTROL_SIZES); do \
		rm -rf $(CONTROL_PLAYTEST_DIR)/$$size; \
		mkdir -p $(CONTROL_PLAYTEST_DIR)/$$size; \
		timeout 420 $(GODOT) --path . --resolution $$size -- --skirmish --enemy=cpu --seed=3 --control-playtest=$(CURDIR)/$(CONTROL_PLAYTEST_DIR)/$$size $(CONTROL_FLAGS) 2>&1 \
			| tee $(CONTROL_PLAYTEST_DIR)/$$size/run.log | grep -E 'CONTROL_PLAYTEST|SCRIPT ERROR|^ERROR' || true; \
		grep -q 'CONTROL_PLAYTEST_DONE ok=true' $(CONTROL_PLAYTEST_DIR)/$$size/run.log || exit 1; \
	done
	@echo "Now LOOK at $(CONTROL_PLAYTEST_DIR)/*/*.png"

## Control X4: the same session with a faction-sized army, to judge the panel, the groups and the HUD at scale.
CONTROL_SCALE_BUDGET ?= 6500

control-scale-shots: import ## The control playtest with ~30 units a side, frames in build/control-playtest/scale/ (needs a display)
	rm -rf $(CONTROL_PLAYTEST_DIR)/scale && mkdir -p $(CONTROL_PLAYTEST_DIR)/scale
	timeout 600 $(GODOT) --path . --resolution 1920x1080 -- --skirmish --player=cpu --enemy=cpu --seed=3 \
		--budget=$(CONTROL_SCALE_BUDGET) --control-playtest=$(CURDIR)/$(CONTROL_PLAYTEST_DIR)/scale $(CONTROL_FLAGS) 2>&1 \
		| tee $(CONTROL_PLAYTEST_DIR)/scale/run.log | grep -E 'CONTROL_PLAYTEST|SCRIPT ERROR|^ERROR' || true
	# This is a look-at-it target, not a pass/fail one: with a faction-sized army nobody is commanding, the
	# player's force loses, and steps that depend on a live group 1 legitimately report false. What must not
	# happen is a crash or a session that never finishes.
	grep -q 'CONTROL_PLAYTEST_DONE' $(CONTROL_PLAYTEST_DIR)/scale/run.log
	# Round 4 counted the renderer's instance-uniform errors here; render removed the uniforms in round 5 (0 errors).
	# The count stays, so a regression shows up in this session's output.
	@noise=$$(grep -cE 'shader instance variables|instance_buffer_pos' $(CONTROL_PLAYTEST_DIR)/scale/run.log || true); \
	test "$$noise" -eq 0 || echo ">> $$noise renderer errors: per-instance shader uniforms exhausted at this army size (render's)"; \
	real=$$(grep -E 'SCRIPT ERROR|^ERROR' $(CONTROL_PLAYTEST_DIR)/scale/run.log | grep -vE 'shader instance variables|instance_buffer_pos' || true); \
	test -z "$$real" || { echo "$$real"; exit 1; }
	@echo "Now LOOK at $(CONTROL_PLAYTEST_DIR)/scale/*.png"

## Control X5: the faction menu, and a faction skirmish you can actually play.
FACTION ?= gangs
ENEMY_FACTION ?= syndicate

faction-menu-shot: import ## Screenshot the faction picker in build/screenshots/faction-menu.png (needs a display)
	mkdir -p $(BUILD_DIR)/screenshots && touch $(BUILD_DIR)/.gdignore
	timeout 120 $(GODOT) --path . --resolution 1920x1080 -- --skirmish --seed=3 --pick-faction \
		--screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/faction-menu.png --screenshot-delay=4
	@echo "Now LOOK at $(BUILD_DIR)/screenshots/faction-menu.png"

## Control stretch: the self-directing camera. CINEMATIC_SHOTS frames, CINEMATIC_EVERY seconds apart.
CINEMATIC_SHOTS ?= 6
CINEMATIC_EVERY ?= 7

cinematic-shots: import ## Frames from the self-directing camera in build/screenshots/cinematic-*.png (needs a display)
	mkdir -p $(BUILD_DIR)/screenshots && touch $(BUILD_DIR)/.gdignore
	for i in $$(seq 1 $(CINEMATIC_SHOTS)); do \
		delay=$$(( i * $(CINEMATIC_EVERY) )); \
		timeout 180 $(GODOT) --path . --resolution 1920x1080 -- --skirmish --cinematic --player=cpu --enemy=cpu \
			--seed=3 --budget=$(CONTROL_SCALE_BUDGET) --no-pick-faction \
			--screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/cinematic-$$i.png --screenshot-delay=$$delay || exit 1; \
	done
	@echo "Now LOOK at $(BUILD_DIR)/screenshots/cinematic-*.png"

cinematic: import ## Watch a CPU-vs-CPU match with the self-directing camera (ANNOUNCER=, MUSIC= to change)
	$(GODOT) --path . -- --skirmish --cinematic --player=cpu --enemy=cpu --budget=$(CONTROL_SCALE_BUDGET) \
		--announcer=$(or $(ANNOUNCER),voice) --music=$(or $(MUSIC),on) $(CONTROL_FLAGS)

skirmish-factions: import ## Play a faction match (FACTION=gangs ENEMY_FACTION=syndicate [ARENA=pit]): size follows the roster
	$(GODOT) --path . -- --skirmish --player-faction=$(FACTION) --enemy-faction=$(ENEMY_FACTION) $(if $(ARENA),--arena=$(ARENA)) \
		--announcer=$(or $(ANNOUNCER),voice) --music=$(or $(MUSIC),on) $(CONTROL_FLAGS)

COMMAND_PLAYTEST_DIR := $(BUILD_DIR)/command-playtest

command-playtest: import ## Headless: tap each squad, order it off screen via the radar, check the camera frames it (log: build/command-playtest/camera.jsonl)
	rm -rf $(COMMAND_PLAYTEST_DIR) && mkdir -p $(COMMAND_PLAYTEST_DIR)
	$(GODOT) --headless --path . -- --skirmish --enemy=cpu --seed=3 --command-playtest=$(CURDIR)/$(COMMAND_PLAYTEST_DIR) 2>&1 \
		| tee $(COMMAND_PLAYTEST_DIR)/run.log | grep -E 'COMMAND_PLAYTEST|SCRIPT ERROR|ERROR' || true
	grep -q 'COMMAND_PLAYTEST_DONE ok=true' $(COMMAND_PLAYTEST_DIR)/run.log
	! grep -E 'SCRIPT ERROR|^ERROR' $(COMMAND_PLAYTEST_DIR)/run.log

command-playtest-shots: import ## The same playtest in a phone-sized window, saving camera frames to build/command-playtest/*.png (needs a display)
	rm -rf $(COMMAND_PLAYTEST_DIR) && mkdir -p $(COMMAND_PLAYTEST_DIR)
	$(GODOT) --path . --resolution 1200x540 -- --skirmish --enemy=cpu --seed=3 --command-playtest=$(CURDIR)/$(COMMAND_PLAYTEST_DIR) 2>&1 \
		| tee $(COMMAND_PLAYTEST_DIR)/run.log | grep -E 'COMMAND_PLAYTEST|SCRIPT ERROR' || true
	grep -q 'COMMAND_PLAYTEST_DONE ok=true' $(COMMAND_PLAYTEST_DIR)/run.log

## Control round 5 X1/X6: the first minutes as a player meets them, through real input events (needs a display).
SHELL_PLAYTEST_DIR := $(BUILD_DIR)/shell-playtest
SHELL_SIZE ?= 1920x1080

shell-playtest: import ## Title → SKIRMISH → faction menu → planning → a minute of battle, through real clicks; readings and frames in build/shell-playtest/ (needs a display)
	rm -rf $(SHELL_PLAYTEST_DIR) && mkdir -p $(SHELL_PLAYTEST_DIR)
	timeout 360 $(GODOT) --path . --resolution $(SHELL_SIZE) -- --title --announcer=text --hints=fresh --shell-playtest=$(CURDIR)/$(SHELL_PLAYTEST_DIR) 2>&1 \
		| tee $(SHELL_PLAYTEST_DIR)/run.log | grep -E 'SHELL_PLAYTEST|TITLE_START|SCRIPT ERROR|^ERROR' || true
	grep -q 'SHELL_PLAYTEST_DONE ok=true' $(SHELL_PLAYTEST_DIR)/run.log
	@# The lead launched the game and saw "a bunch of red error messages": a player's session must log none at all.
	@# Known engine noise, not a player-facing fault: Godot warns when a MultiMesh that the renderer interpolates is
	@# written from _process. Every FX MultiMesh is placed per rendered frame by design (render's paths); the fix is one
	@# line per mesh, RenderingServer.multimesh_set_physics_interpolated(rid, false), re-asserted after any resize.
	@# Control fixed its selection rings and render's underglow; the rest are render's to do. Counted, not swallowed.
	@glow=$$(grep -c 'MultiMesh interpolation is being triggered' $(SHELL_PLAYTEST_DIR)/run.log || true); \
	test "$$glow" -eq 0 || echo ">> $$glow MultiMesh interpolation warnings (render's FX; see mk/command.mk)"
	@errors=$$(grep -E 'SCRIPT ERROR|^ERROR|^WARNING' $(SHELL_PLAYTEST_DIR)/run.log | grep -v 'ObjectDB instances were leaked at exit' \
			| grep -v 'MultiMesh interpolation is being triggered' || true); \
	test -z "$$errors" || { echo ">> the console is not clean:"; echo "$$errors" | sort | uniq -c | sort -rn | head -20; exit 1; }
	@echo "clean console: $(SHELL_PLAYTEST_DIR)/run.log"

## Round 9 (control item 5): the console state of a real player session, as a COMMITTED BASELINE that fails on CHANGE.
## Lesson 42 - do not add a red suite to the gate - is why `shell-playtest` was never in `check`, and `main` went green
## at 2fa58c01 carrying two "Texture with GL ID ... leaked 5460 bytes" lines it would have caught. The honest first step
## is to record what the console does today and fail when it MOVES, in either direction: a fault that stopped happening
## is news too (something was fixed, or a step of the playtest silently stopped running).
SHELL_CONSOLE_BASELINE := tests/baselines/shell_console.txt

## The compare lives in `check-display`, NOT in `shell-playtest`. `shell-playtest` is the instrument every stream
## reaches for by hand, and a missing or stale baseline must never be the reason someone's playtest goes red; the
## GATE is the thing that owns the baseline. It also means the baseline can be regenerated from a plain
## `make remote T=shell-playtest` without the gate refusing the run that is producing it.

shell-console-baseline: ## Rewrite tests/baselines/shell_console.txt from the last shell-playtest run (deliberate: say in the commit why each line moved)
	$(PYTHON) tools/shell_console.py write $(SHELL_PLAYTEST_DIR)/run.log $(SHELL_CONSOLE_BASELINE)

## This one needs no display and belongs in `check` proper, beside `match-pytest`. `mk/core.mk`'s `check` line is
## shared and metrics is rewriting it for T1, so it is REQUESTED rather than taken: until it lands there, it runs as a
## prerequisite of check-display. Merge note.
shell-console-pytest: ## The console baseline tool's own tests (a guard nobody has run end to end is not a guard)
	cd tools && $(PYTHON) -m unittest test_shell_console

## Round 9: the checks that NEED A DISPLAY, as their own bundle. Deliberately NOT in `check`'s target list (metrics'
## T1 owns that): a display-only target inside `check` either fails every local run or no-ops without a display, and a
## target that passes for the wrong reason is exactly what lesson 42 is about. `make remote T=check-display` runs it on
## builder0, where tools/remote.sh provides Xwayland (trip-up 65).
check-display: shell-console-pytest shell-playtest ## Everything that needs a display: the shell playtest and its console baseline (run it with make remote T=check-display)
	$(PYTHON) tools/shell_console.py compare $(SHELL_PLAYTEST_DIR)/run.log $(SHELL_CONSOLE_BASELINE)
	@echo "check-display passed. Now LOOK at $(SHELL_PLAYTEST_DIR)/*.png"

## Control X4 (CP1: the HUD ≤ 130 draw calls and ≤ 1 ms of _process at 60 vehicles), measured per widget.
HUD_COST_RES ?= 1920x1080
HUD_COST_FLAGS ?=

hud-cost: import ## What each HUD widget costs (canvas draw calls, _process) in a ~30-a-side skirmish → build/hud-cost.json (needs a display; HUD_COST_RES, HUD_COST_FLAGS)
	timeout 900 $(GODOT) --path . --resolution $(HUD_COST_RES) -- --skirmish --player=cpu --enemy=cpu --seed=3 \
		--budget=$(CONTROL_SCALE_BUDGET) --no-pick-faction --mute --hud-cost=$(CURDIR)/$(BUILD_DIR)/hud-cost.json $(HUD_COST_FLAGS) 2>&1 \
		| tee $(BUILD_DIR)/hud-cost.log | grep -E '^HUD_COST|SCRIPT ERROR' || true
	grep -q HUD_COST_DONE $(BUILD_DIR)/hud-cost.log

## Round 5 reopened (the lead: "the units aren't very responsive to my input"): the whole path from the click to the
## vehicle moving, split by stage, at a real army size and at a small one for comparison.
RESPONSE_DIR := $(BUILD_DIR)/response-test
RESPONSE_BUDGET ?= 6500
RESPONSE_SMALL_BUDGET ?= 1200

## Run it where frames are actually drawn: builder0's remote desktop draws ~1 fps and makes every number meaningless.
## Standing target: median "vehicle visibly starts" under ~150 ms at 30 a side.
response-test: import ## Click → order → acknowledgement → first visible movement in ms, at ~30 a side and at a small army → build/response-test/ (a real display, NOT builder0)
	rm -rf $(RESPONSE_DIR) && mkdir -p $(RESPONSE_DIR)/big $(RESPONSE_DIR)/small
	for size in big:$(RESPONSE_BUDGET) small:$(RESPONSE_SMALL_BUDGET); do \
		name=$${size%%:*}; budget=$${size##*:}; \
		timeout 300 $(GODOT) --path . --resolution 1920x1080 -- --skirmish --player=cpu --enemy=cpu --seed=3 --budget=$$budget \
			--no-pick-faction --mute --response-test=$(CURDIR)/$(RESPONSE_DIR)/$$name 2>&1 \
			| tee $(RESPONSE_DIR)/$$name/run.log | grep -E '^RESPONSE_TEST|SCRIPT ERROR' || true; \
		grep -q RESPONSE_TEST_DONE $(RESPONSE_DIR)/$$name/run.log || exit 1; \
	done

## Round 5 reopened (the lead: "I select squad 1, move them, select squad 2, move them ... the units do not re-arrange
## as intended"). His exact sequence through real input, then where every unit actually is, twice.
SQUAD_ORDERS_DIR := $(BUILD_DIR)/squad-orders
SQUAD_ORDERS_FLAGS ?= --player-faction=condemned --enemy-faction=law

squad-orders-test: import ## Order every squad in turn, then table where each unit was sent vs where it is (needs a real display, NOT builder0)
	rm -rf $(SQUAD_ORDERS_DIR) && mkdir -p $(SQUAD_ORDERS_DIR)
	timeout 300 $(GODOT) --path . --resolution 1920x1080 -- --skirmish --seed=3 --no-pick-faction --mute \
		$(SQUAD_ORDERS_FLAGS) --squad-orders-test=$(CURDIR)/$(SQUAD_ORDERS_DIR) 2>&1 \
		| tee $(SQUAD_ORDERS_DIR)/run.log | grep -E '^SQUAD_ORDERS|SCRIPT ERROR' || true
	grep -q SQUAD_ORDERS_DONE $(SQUAD_ORDERS_DIR)/run.log

## Control X3 (round 6's lead gate): one frozen moment of a 30-a-side fight from a grid of camera poses, as a page, plus
## an arena tour (three frames per arena) so the page also asks which arena is fun. CAMERA_LOOKS_ARENAS= skips the tour.
CAMERA_LOOKS_DIR := $(BUILD_DIR)/camera-looks
CAMERA_LOOKS_ARENA ?= yard
CAMERA_LOOKS_SEED ?= 3
CAMERA_LOOKS_ARENAS ?= $(basename $(notdir $(wildcard arenas/*.json)))
CAMERA_LOOKS_FLAGS = --skirmish --player-faction=condemned --enemy-faction=syndicate --seed=$(CAMERA_LOOKS_SEED) --mute

camera-looks: import ## Photograph one frozen fight from a grid of pitch x distance x FOV, and every arena: build/camera-looks/index.html (needs a display)
	rm -rf $(CAMERA_LOOKS_DIR) && mkdir -p $(CAMERA_LOOKS_DIR)/arenas && touch $(BUILD_DIR)/.gdignore
	for arena in $(CAMERA_LOOKS_ARENAS); do \
		timeout 240 $(GODOT) --path . --resolution 1920x1080 -- $(CAMERA_LOOKS_FLAGS) --arena=$$arena --camera-looks-grid=arena \
			--camera-looks=$(CURDIR)/$(CAMERA_LOOKS_DIR)/arenas/$$arena > $(CAMERA_LOOKS_DIR)/arena-$$arena.log 2>&1; \
		grep -E 'CAMERA_LOOKS_DONE|SCRIPT ERROR|^ERROR' $(CAMERA_LOOKS_DIR)/arena-$$arena.log || echo ">> $$arena: no frames"; \
	done
	timeout 420 $(GODOT) --path . --resolution 1920x1080 -- $(CAMERA_LOOKS_FLAGS) --arena=$(CAMERA_LOOKS_ARENA) \
		--camera-looks=$(CURDIR)/$(CAMERA_LOOKS_DIR) 2>&1 \
		| tee $(CAMERA_LOOKS_DIR)/run.log | grep -E 'CAMERA_LOOKS|SCRIPT ERROR|^ERROR' || true
	grep -q 'CAMERA_LOOKS_DONE ok=true' $(CAMERA_LOOKS_DIR)/run.log
	@echo "Now LOOK at $(CAMERA_LOOKS_DIR)/index.html"

## Round 9, the lead on the Terminus: "the camera often ends up inside a building and we can't see what's going on
## inside the alleyways." Every pose shot TWICE from the same spot - as asked for, and as RtsCamera.clear_pose leaves
## it - at HIS pose (21 deg, FOV 35, 49 m). Never at 12 deg: that is the camera he played and rejected.
ALLEYS_DIR := $(BUILD_DIR)/terminus-alleys
ALLEYS_ARENA ?= terminus

terminus-alleys: import ## Round 9: the camera forced outside a city block, before and after, in the Terminus alleys at the lead's pose -> build/terminus-alleys/index.html (needs a display: make remote T=terminus-alleys)
	rm -rf $(ALLEYS_DIR) && mkdir -p $(ALLEYS_DIR)/arenas && touch $(BUILD_DIR)/.gdignore
	timeout 420 $(GODOT) --path . --resolution 1920x1080 -- $(CAMERA_LOOKS_FLAGS) --arena=$(ALLEYS_ARENA) \
		--camera-looks-grid=alleys --camera-looks=$(CURDIR)/$(ALLEYS_DIR) 2>&1 \
		| tee $(ALLEYS_DIR)/run.log | grep -E 'CAMERA_LOOKS|SCRIPT ERROR|^ERROR' || true
	grep -q 'CAMERA_LOOKS_DONE ok=true' $(ALLEYS_DIR)/run.log
	@echo "Now LOOK at $(ALLEYS_DIR)/index.html"

## Control X4: what spawning a 30-a-side army costs per vehicle (FIGHT's stall). SPAWN_THEME=default compares the box art.
spawn-cost: import ## Headless: ms per spawned vehicle, first of each type vs the rest, per faction army
	$(GODOT) --headless --path . --script res://game/ui/spawn_cost_bench.gd -- $(if $(SPAWN_THEME),--theme=$(SPAWN_THEME)) 2>&1 | grep -E 'SPAWN_COST|SCRIPT ERROR|^ERROR'

## Round 8 policy (_agents/verification.md "Timing in tests"): make check only MEASURES control's timing budgets; this
## JUDGES them. Run it on purpose on an uncontended machine (`make remote T=control-timing` when builder0 is idle):
## under full oversubscription the order path measured 14x slower against a 2x reference, so no ratio survives that.
control-timing: import ## Judge control's timing budgets (frame, order, click, health bars) - run on an idle machine
	TANK_SQUAD_JUDGE_TIMING=1 $(GODOT) --headless --path . --script res://tests/run_tests.gd -- --filter=test_control_scale
	TANK_SQUAD_JUDGE_TIMING=1 $(GODOT) --headless --path . --script res://tests/run_tests.gd -- --filter=test_control_readability

## Round 10 (control item 1, contract R2; the lead: "I was trying to right click to move them in a different direction
## and they didnt respond"). Squad 1 en route on Terminus, a right-click 40 m off its line, per tick per crew what Orders
## says it CARRIES OUT, in seven in-flight states. Fails when any crew's order is unchanged 2 ticks after the click.
REPATH_DIR := $(BUILD_DIR)/repath
REPATH_ARENA ?= terminus
REPATH_FLAGS ?= --player-faction=condemned --enemy-faction=law

repath-test: import ## R2: a right-click on a squad already moving, seven ways, on Terminus; per-tick crew orders in build/repath/repath.json (headless)
	rm -rf $(REPATH_DIR) && mkdir -p $(REPATH_DIR)
	timeout 300 $(GODOT) --headless --path . -- --skirmish --seed=3 --no-pick-faction --mute --arena=$(REPATH_ARENA) \
		$(REPATH_FLAGS) --repath-test=$(CURDIR)/$(REPATH_DIR) $(if $(ONLY),--repath-only=$(ONLY)) 2>&1 \
		| tee $(REPATH_DIR)/run.log | grep -E '^REPATH|SCRIPT ERROR|^ERROR' || true
	grep -q 'REPATH_DONE ok=true' $(REPATH_DIR)/run.log
