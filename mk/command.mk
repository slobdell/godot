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
		timeout 720 $(GODOT) --path . --resolution $$size -- --skirmish --enemy=cpu --seed=3 --control-playtest=$(CURDIR)/$(CONTROL_PLAYTEST_DIR)/$$size $(CONTROL_FLAGS) 2>&1 \
			| tee $(CONTROL_PLAYTEST_DIR)/$$size/run.log | grep -E 'CONTROL_PLAYTEST|SCRIPT ERROR|^ERROR' || true; \
		grep -q 'CONTROL_PLAYTEST_DONE ok=true' $(CONTROL_PLAYTEST_DIR)/$$size/run.log || exit 1; \
	done
	@echo "Now LOOK at $(CONTROL_PLAYTEST_DIR)/*/*.png"

## Control X4: the same session with a faction-sized army, to judge the panel, the groups and the HUD at scale.
CONTROL_SCALE_BUDGET ?= 6500

## Round 18 (picker): the Formation panel played through real input in a skirmish, at his window and a phone's aspect.
PICKER_SIZES ?= 1854x1011 1200x540
PICKER_DIR := build/picker-shots
## PICKER_FLAGS: extra skirmish flags. PICKER_ARENA / PICKER_SPOTS (stretch b; no spaces, so they survive
## `make remote T=...`): e.g. PICKER_ARENA=parade PICKER_SPOTS=centre:0,0,0+ladder:-80,18,90 frames a squad of four at each.
PICKER_FLAGS ?=
PICKER_ARENA ?=
PICKER_SPOTS ?=
_PICKER_EXTRA = $(if $(PICKER_ARENA),--arena=$(PICKER_ARENA)) $(if $(PICKER_SPOTS),--picker-spots=$(PICKER_SPOTS)) $(PICKER_FLAGS)
picker-playtest: import ## Headless: the Formation panel opened, previewed, picked, and picked mid-fight (checks only; frames need picker-shots)
	@mkdir -p $(PICKER_DIR)/headless
	@# The engine's own exit code is the verdict (an abort after DONE is a failure: round 18's heap abort), then DONE.
	s=0; timeout 180 $(GODOT) --headless --path . -- --skirmish --enemy=cpu --seed=3 --control-playtest=$(CURDIR)/$(PICKER_DIR)/headless --picker-only $(_PICKER_EXTRA) \
		> $(PICKER_DIR)/headless/run.log 2>&1 || s=$$?; \
	grep -E 'PICKER_PLAYTEST|SCRIPT ERROR|^ERROR|corrupted|terminate called' $(PICKER_DIR)/headless/run.log || true; \
	[ $$s -eq 0 ] || { echo "picker-playtest: exited $$s"; exit 1; }
	@grep -q 'PICKER_PLAYTEST_DONE ok=true' $(PICKER_DIR)/headless/run.log

picker-shots: import ## The Formation panel in windows (PICKER_SIZES, default his 1854x1011 and a 1200x540 phone): frames in build/picker-shots/<size>/*.png (needs a display)
	for size in $(PICKER_SIZES); do \
		rm -rf $(PICKER_DIR)/$$size; \
		mkdir -p $(PICKER_DIR)/$$size; \
		s=0; timeout 300 $(GODOT) --path . --resolution $$size -- --skirmish --enemy=cpu --seed=3 --control-playtest=$(CURDIR)/$(PICKER_DIR)/$$size --picker-only $(_PICKER_EXTRA) \
			> $(PICKER_DIR)/$$size/run.log 2>&1 || s=$$?; \
		grep -E 'PICKER_PLAYTEST|SCRIPT ERROR|^ERROR|corrupted|terminate called' $(PICKER_DIR)/$$size/run.log || true; \
		[ $$s -eq 0 ] || { echo "picker-shots $$size: exited $$s"; exit 1; }; \
		grep -q 'PICKER_PLAYTEST_DONE ok=true' $(PICKER_DIR)/$$size/run.log || exit 1; \
	done
	@echo "Now LOOK at $(PICKER_DIR)/*/*.png"

## Round 19 (orders, O1/O3/O5): his two-squad move. Squads 1 and 2 on opposite flanks, both ordered to one point, once
## selected together and once as one group: every vehicle's goal, slot, first 5 s and end in two_squads.json.
## TWO_ARENA picks the map (default: the skirmish's own); TWO_SIZES the windowed frames (his window and a phone).
TWO_DIR := build/two-squads
TWO_ARENA ?=
TWO_SIZES ?= 1854x1011 1200x540
## Two full squads of five (tank, tank, IFV, IFV, scout) against one scout holding at home, no centre ring: the move
## itself, not a fight (the default skirmish army is 3 + 2 and the CPU kills a crew mid-measurement).
TWO_ARMY := --player=res://tests/support/two_squads_army.json --enemy=res://tests/support/two_squads_enemy.json --budget=100000 --no-control
## O5: TWO_CLICK=x,z his click (default: 60 m ahead, 35 m toward squad 2); TWO_SHAPES=line,wedge squad 1's and 2's
## formations, picked with G before the order.
TWO_CLICK ?=
TWO_SHAPES ?=
## Round 21 (orders, stretch a): every case of the probe runs in REAL time (25 s settles, three cases, the five-squad
## case up to 90 s more), so one invocation needs minutes, and a loaded builder0 stretches them: 240 s cut runs short
## in round 19. TWO_TIMEOUT bounds each Godot run of two-squads-playtest, two-squads-shots, five-squads-series and
## five-squads-shots.
TWO_TIMEOUT ?= 720
## Round 23 (O1): TWO_FLAGS="--column-gap=14" = the before-arm of the columns' lane (two-squads-playtest, two-squads-shots);
## INTERLEAVED_FLAGS the same for interleaved-probe (both of its arms).
TWO_FLAGS ?=
INTERLEAVED_FLAGS ?=
_TWO_EXTRA = $(TWO_ARMY) $(if $(TWO_ARENA),--arena=$(TWO_ARENA)) $(if $(TWO_CLICK),--two-click=$(TWO_CLICK)) $(if $(TWO_SHAPES),--two-shapes=$(TWO_SHAPES)) $(TWO_FLAGS)
two-squads-playtest: import ## Headless: two squads ordered together (selected, and as one group): goals, slots, first 5 s (build/two-squads/headless)
	@mkdir -p $(TWO_DIR)/headless
	s=0; timeout $(TWO_TIMEOUT) $(GODOT) --headless --path . -- --skirmish --enemy=cpu --seed=3 --control-playtest=$(CURDIR)/$(TWO_DIR)/headless --two-squads $(_TWO_EXTRA) \
		> $(TWO_DIR)/headless/run.log 2>&1 || s=$$?; \
	grep -E 'TWO_SQUADS|SCRIPT ERROR|^ERROR|corrupted|terminate called' $(TWO_DIR)/headless/run.log || true; \
	[ $$s -eq 0 ] || { echo "two-squads-playtest: exited $$s"; exit 1; }
	@grep -q 'TWO_SQUADS_DONE ok=true' $(TWO_DIR)/headless/run.log
	@# Round 21 (orders, O2; C21.4): the five-squad case, his round-20 order (five-squads-series for maps x repeats).
	@mkdir -p $(TWO_DIR)/five
	s=0; timeout $(TWO_TIMEOUT) $(GODOT) --headless --path . -- --skirmish --enemy=cpu --seed=3 --control-playtest=$(CURDIR)/$(TWO_DIR)/five --two-squads --five-squads --five-shape=vee $(FIVE_ARMY) $(if $(TWO_ARENA),--arena=$(TWO_ARENA),--arena=foundry) \
		> $(TWO_DIR)/five/run.log 2>&1 || s=$$?; \
	grep -E 'FIVE_SQUADS|TWO_SQUADS_DONE|SCRIPT ERROR|^ERROR' $(TWO_DIR)/five/run.log || true; \
	[ $$s -eq 0 ] || { echo "two-squads-playtest (five): exited $$s"; exit 1; }

## Round 21 (orders, O2; C21.4): his five squads of five Rat Rods (vees), all selected, one attack-move 150 m ahead, on
## FIVE_MAPS x FIVE_REPS (real time, so each map runs FIVE_REPS times). Per run: each squad's worst sideways detour in
## the first 10 s, when the last squad arrived, the body's anchor span. Brains reads the numbers (C21.4).
## Round 22 (orders O3): SQUADS=10 plays the same order with ten squads (50 Rat Rods, `ten_gangs_army.json`); 5 or 10.
SQUADS ?= 5
## NEST=off: ranks a depth and a gap apart (the before-arm of round 22's nesting).
NEST ?=
## Round 23 (O4): AUTO_SHAPE=off lays AUTO squads shapeless (the before-arm of their nominal shape).
AUTO_SHAPE ?=
## FIVE_SETTLE=10: read the crews (blocked, pushed) 10 s after the last squad arrived, not at once.
FIVE_SETTLE ?=
FIVE_ARMY = --player=res://tests/support/$(if $(filter 10,$(SQUADS)),ten,five)_gangs_army.json --squads=$(SQUADS) $(if $(NEST),--nest=$(NEST)) $(if $(AUTO_SHAPE),--auto-shape=$(AUTO_SHAPE)) $(if $(FIVE_SETTLE),--five-settle=$(FIVE_SETTLE)) \
	--enemy=res://tests/support/two_squads_enemy.json --budget=100000 --no-control
FIVE_MAPS ?= foundry parade
FIVE_REPS ?= 3
## The formation picked for all five before the order (vee: his round-20 squads; auto: the leaders pick).
FIVE_SHAPES ?= vee auto
## FIVE_SEED: the skirmish seed (his round-20 foundry game was 29989); FIVE_CLICK=x,z his click instead of 150 m ahead.
FIVE_SEED ?= 3
FIVE_CLICK ?=
FIVE_DIR := build/five-squads
.PHONY: five-squads-series
five-squads-series: import ## Round 21 (O2): five gang squads, one attack-move, on FIVE_MAPS x FIVE_SHAPES x FIVE_REPS -> build/five-squads/<map>-<shape>-r<rep>/five_squads.json + summary lines
	@rm -rf $(FIVE_DIR); mkdir -p $(FIVE_DIR)
	@echo ">> five-squads-series SQUADS=$(SQUADS) NEST=$(or $(NEST),on) on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@fail=0; for rep in $$(seq 1 $(FIVE_REPS)); do for map in $(FIVE_MAPS); do for shape in $(FIVE_SHAPES); do \
		d=$(CURDIR)/$(FIVE_DIR)/$$map-$$shape-r$$rep; mkdir -p $$d; s=0; \
		timeout $(TWO_TIMEOUT) $(GODOT) --headless $(PIN_FPS) --path . -- --skirmish --enemy=cpu --seed=$(FIVE_SEED) --control-playtest=$$d --two-squads --five-squads \
			--five-shape=$$shape $(if $(FIVE_CLICK),--two-click=$(FIVE_CLICK)) $(FIVE_ARMY) --arena=$$map > $$d/run.log 2>&1 || s=$$?; \
		echo "$$map $$shape rep $$rep: exit $$s"; grep -E 'FIVE_SQUADS summary|SCRIPT ERROR' $$d/run.log || true; \
		[ $$s -eq 0 ] || fail=1; \
	done; done; done; exit $$fail

## Round 22 (orders O1b): his six on the Sumps, two squads of three interleaved, one line order; the before-arm
## (--untangle=off: the squads laid abreast as they were) and the after-arm, path crossings and hull contacts in the
## first 10 s -> build/interleaved/<arm>/interleaved.json + INTERLEAVED summary lines.
INTERLEAVED_DIR := build/interleaved
INTERLEAVED_REPS ?= 3
## REPLAY=1: his five clicks from tick 3600 at his times (AUTO, then the column he picked) instead of one line order.
REPLAY ?=
.PHONY: interleaved-probe
interleaved-probe: import ## Round 22 (O1b): his six interleaved APCs ordered into lines, before/after untangling, INTERLEAVED_REPS each -> build/interleaved/<arm>-r<rep>/interleaved.json
	@echo ">> interleaved-probe on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown})"
	@rm -rf $(INTERLEAVED_DIR); fail=0; for rep in $$(seq 1 $(INTERLEAVED_REPS)); do for arm in before after; do \
		d=$(CURDIR)/$(INTERLEAVED_DIR)/$$arm-r$$rep; mkdir -p $$d; s=0; \
		timeout $(TWO_TIMEOUT) $(GODOT) --headless $(PIN_FPS) --path . -- --skirmish --enemy=cpu --seed=5988 --arena=sumps \
			--control-playtest=$$d --two-squads --interleaved$(if $(REPLAY),-replay) $$( [ $$arm = before ] && echo --untangle=off ) \
			--player=res://tests/support/interleaved_army.json --enemy=res://tests/support/two_squads_enemy.json \
			--budget=100000 --no-control $(INTERLEAVED_FLAGS) > $$d/run.log 2>&1 || s=$$?; \
		echo "$$arm rep $$rep: exit $$s"; grep -E 'TWO_SQUADS_DONE|SCRIPT ERROR' $$d/run.log | cut -c1-300 || true; \
		[ $$s -eq 0 ] || fail=1; \
	done; done; exit $$fail

two-squads-shots: import ## The two-squad move in windows (TWO_SIZES): frames in build/two-squads/<size>/*.png (needs a display)
	for size in $(TWO_SIZES); do \
		rm -rf $(TWO_DIR)/$$size; \
		mkdir -p $(TWO_DIR)/$$size; \
		s=0; timeout $(TWO_TIMEOUT) $(GODOT) --path . --resolution $$size -- --skirmish --enemy=cpu --seed=3 --control-playtest=$(CURDIR)/$(TWO_DIR)/$$size --two-squads $(_TWO_EXTRA) \
			> $(TWO_DIR)/$$size/run.log 2>&1 || s=$$?; \
		grep -E 'TWO_SQUADS .*summary|TWO_SQUADS_DONE|SCRIPT ERROR|^ERROR' $(TWO_DIR)/$$size/run.log || true; \
		[ $$s -eq 0 ] || echo "two-squads-shots $$size: exited $$s"; \
	done
	@echo "Now LOOK at $(TWO_DIR)/*/*.png"

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
## Round 25 (the lead: "the opponent is always The Syndicate"): the gangs-v-Syndicate defaults live INSIDE
## skirmish-factions. As global `?=` lines they leaked into `make skirmish`, which pinned the enemy to the Syndicate
## and skipped Random (play.mk), and into `make vehicle-gallery`'s FACTION.

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

# `make demo` is play.mk's scripted driver, and the Makefile's SEED ?= 1 is global: a showmatch rolls its own seed
# unless SEED is given on the command line or in the environment.
DEMO_SEED_GIVEN = $(if $(filter command line environment environment override,$(origin SEED)),$(SEED))
DEMO_FPS ?= 30
DEMO_END_S ?= 5

# O5 (the lead: "pit 2 computer players against each other so I can easily record the game to share with people").
# Movie Maker ignores --resolution and records the project's window size: project.godot's `.movie` overrides make it
# 1920x1080 (the `movie` feature tag is only set while recording).
.PHONY: showmatch
showmatch: import ## Two computer players fight, filmed by the self-directing camera with no HUD (sound on). Random factions (never a mirror) and arena from SEED, printed as DEMO_SEED; SEED= FACTION= ENEMY_FACTION= ARENA= pin them, SIZE= squads a side, HUD=1 keeps the score. MOVIE=out.mp4 (or .avi) records it in 1080p at FPS=30: it renders slower than real time, but the file plays smoothly. RES=WxH sizes the window for watching
	@seed=$(or $(DEMO_SEED_GIVEN),$$(( $$(date +%s%N) / 1000 % 100000 ))); \
	echo "DEMO_SEED $$seed (replay: make showmatch SEED=$$seed)"; \
	movie="$(MOVIE)"; avi=""; record=""; finish=""; \
	if [ -n "$$movie" ]; then \
		case "$$movie" in /*) ;; *) movie="$(CURDIR)/$$movie" ;; esac; \
		avi="$${movie%.*}.avi"; mkdir -p "$$(dirname "$$movie")"; \
		record="--write-movie $$avi --fixed-fps $(or $(FPS),$(DEMO_FPS))"; \
		finish="--quit-after-end=$(DEMO_END_S)"; \
	elif [ -n "$(RES)" ]; then record="--resolution $(RES)"; fi; \
	started=$$(date +%s); \
	$(GODOT) --path . $$record -- --skirmish --demo-match --clean $(if $(HUD),--clean-score) --seed=$$seed \
		--arena=$(or $(ARENA),random) $(if $(FACTION),--player-faction=$(FACTION)) \
		$(if $(ENEMY_FACTION),--enemy-faction=$(ENEMY_FACTION)) $(if $(SIZE),--squad-cap=$(SIZE)) \
		--announcer=$(or $(ANNOUNCER),voice) --music=$(or $(MUSIC),on) $$finish $(CONTROL_FLAGS) || exit $$?; \
	[ -z "$$movie" ] || echo "DEMO_RENDER $$(( $$(date +%s) - started )) s"; \
	if [ -n "$$movie" ] && [ "$$movie" != "$$avi" ] && ! command -v ffmpeg >/dev/null; then \
		echo "DEMO_MOVIE $$avi (no ffmpeg on this machine, so the AVI is kept: sudo apt install ffmpeg makes the .mp4)"; \
	elif [ -n "$$movie" ] && [ "$$movie" != "$$avi" ]; then \
		ffmpeg -loglevel error -y -i "$$avi" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k \
			-movflags +faststart "$$movie" && rm -f "$$avi" && echo "DEMO_MOVIE $$movie"; \
	elif [ -n "$$movie" ]; then echo "DEMO_MOVIE $$avi"; fi

# Round 27 (O2): the showmatch's end shot, as the recording shows it, over seeds and two aspects. Each run plays a whole
# match in real time (~1-2 min) and saves three frames after the result; each frame prints CINEMATIC_END_SHOT with the
# share of its ground past the walls (off) and past the ground itself (void, the purple under the arena).
END_SHOT_SEEDS ?= 43496 3666 101 202
END_SHOT_SIZES ?= 1920x1080 1200x540
END_SHOT_DIR ?= $(BUILD_DIR)/showmatch-end
## END_SHOT_FLAGS=--cinematic-keep-angle: round 26's director (the A/B's before arm).
END_SHOT_FLAGS ?=
.PHONY: showmatch-end-shots
showmatch-end-shots: import ## The showmatch's end frames over END_SHOT_SEEDS at END_SHOT_SIZES (desktop, phone) in build/showmatch-end/ (needs a display)
	rm -rf $(END_SHOT_DIR) && mkdir -p $(END_SHOT_DIR) && touch $(BUILD_DIR)/.gdignore
	for seed in $(END_SHOT_SEEDS); do for res in $(END_SHOT_SIZES); do \
		timeout 400 $(GODOT) --path . --resolution $$res -- --skirmish --demo-match --clean --seed=$$seed \
			--arena=$(or $(ARENA),random) --announcer=off --music=off $(END_SHOT_FLAGS) \
			--end-shots=$(CURDIR)/$(END_SHOT_DIR)/$$seed 2>&1 | grep -E 'CINEMATIC_|DEMO_|SCRIPT ERROR|arena' \
			| sed "s/^/seed=$$seed /" | tee -a $(END_SHOT_DIR)/end.log; \
	done; done
	@echo "Now LOOK at $(END_SHOT_DIR)/*/end-*.png"

skirmish-factions: import ## Play a faction match (FACTION=gangs ENEMY_FACTION=syndicate [ARENA=pit]): size follows the roster
	$(GODOT) --path . -- --skirmish --player-faction=$(or $(FACTION),gangs) --enemy-faction=$(or $(ENEMY_FACTION),syndicate) $(if $(ARENA),--arena=$(ARENA)) \
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
	@# Round 18 (ship's audit): the engine's exit code is part of the verdict; a `| grep || true` could never show it.
	s=0; timeout 360 $(GODOT) --path . --resolution $(SHELL_SIZE) -- --title --announcer=text --hints=fresh --shell-playtest=$(CURDIR)/$(SHELL_PLAYTEST_DIR) \
		> $(SHELL_PLAYTEST_DIR)/run.log 2>&1 || s=$$?; \
	grep -E 'SHELL_PLAYTEST|TITLE_START|SCRIPT ERROR|^ERROR|corrupted|terminate called' $(SHELL_PLAYTEST_DIR)/run.log || true; \
	[ $$s -eq 0 ] || { echo "shell-playtest: exited $$s"; exit 1; }
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

## Round 16 (hud H1): each widget's `_process`/`_draw` calls and microseconds per frame over HUD_PROFILE_SECONDS of a
## running fight, by counter (HudClock), headless at his window (1854x1011), on the perf references' workload (seed 3,
## --budget=6500: ~30 a side, `streams/references/perf/README.md`).
## `--player=cpu` so both sides fight; the player's HUD (RtsControls and everything under it) is built as in his game.
## CPU microseconds: compare runs on one machine (builder0 for ratios), never across machines.
HUD_PROFILE_SECONDS ?= 60
HUD_PROFILE_FLAGS ?=

hud-profile: import ## Per-widget HUD _process/_draw cost and redraws per frame over a 60 s fight, headless → build/hud-profile.json (HUD_PROFILE_SECONDS, HUD_PROFILE_FLAGS)
	timeout 600 $(GODOT) --headless --path . -- --skirmish --player=cpu --enemy=cpu --seed=3 --budget=$(CONTROL_SCALE_BUDGET) \
		--no-pick-faction --mute --camera-readout=on --hud-cost=$(CURDIR)/$(BUILD_DIR)/hud-profile.json \
		--hud-profile-seconds=$(HUD_PROFILE_SECONDS) $(HUD_PROFILE_FLAGS) 2>&1 \
		| tee $(BUILD_DIR)/hud-profile.log | grep -E '^HUD_PROFILE|SCRIPT ERROR' || true
	grep -q HUD_COST_DONE $(BUILD_DIR)/hud-profile.log

## Round 18 (picker): the HUD's per-unit OUTPUT, hashed every frame of a fixed-fps fight (markers, awareness, vision)
## -> build/hud-digest.txt. Two arms of an equal-output change must print the same lines (HUD_DIGEST_SECONDS).
HUD_DIGEST_SECONDS ?= 20
hud-digest: import ## Per-frame hash of the HUD's per-unit output over a fixed-fps headless fight -> build/hud-digest.txt (an equal-output change's proof)
	rm -f $(BUILD_DIR)/hud-digest.txt  # a failed run must not leave the last arm's digest to be compared
	s=0; timeout 600 $(GODOT) --headless --fixed-fps 60 --path . -- --skirmish --player=cpu --enemy=cpu --seed=3 \
		--budget=$(CONTROL_SCALE_BUDGET) --no-pick-faction --mute --camera-readout=on --hud-cost=/dev/null \
		--hud-profile-seconds=$(HUD_DIGEST_SECONDS) --hud-digest=$(CURDIR)/$(BUILD_DIR)/hud-digest.txt \
		> $(BUILD_DIR)/hud-digest.log 2>&1 || s=$$?; \
	[ $$s -eq 0 ] || { echo "hud-digest: exited $$s"; exit 1; }
	@echo "hud-digest: $$(wc -l < $(BUILD_DIR)/hud-digest.txt) frames, $$(sort -u $(BUILD_DIR)/hud-digest.txt | wc -l) distinct, in $(BUILD_DIR)/hud-digest.txt"

## Round 16 (the bar fixes): the hull bars at his pose - his window, Law on the Sumps against the Road Gangs (their 14 m rig),
## the skirmish's camera on group 1 - with their rig and a scout set down in front and one selected friendly hurt.
## Frame + crops in build/hud-bar-shots/ (needs a display; HUD_BAR_SHOTS_DIR).
HUD_BAR_SHOTS_DIR ?= $(BUILD_DIR)/hud-bar-shots

hud-bar-shots: import ## The hull bars at his pose (a rig, a scout, a hurt selected friendly) → build/hud-bar-shots/*.png (needs a display)
	rm -rf $(HUD_BAR_SHOTS_DIR) && mkdir -p $(HUD_BAR_SHOTS_DIR)
	timeout 300 $(GODOT) --path . --resolution 1854x1011 -- --skirmish --enemy=cpu --seed=92721 --arena=sumps \
		--player-faction=law --enemy-faction=gangs --no-pick-faction --mute --hints=off --render-preset=desktop \
		--hud-cost=/dev/null --hud-bar-shots=$(CURDIR)/$(HUD_BAR_SHOTS_DIR) 2>&1 \
		| tee $(HUD_BAR_SHOTS_DIR)/run.log | grep -E '^HUD_BAR_SHOTS|SCRIPT ERROR' || true
	grep -q HUD_COST_DONE $(HUD_BAR_SHOTS_DIR)/run.log

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

## Round 12 (camera stream): the camera asks the DRAWING, not the collider. Pairs at the lead's pose on one arena: the
## camera by a floodlight at 18 deg (posed from colliders / drawing), an ad screen between the camera and the fight
## (cutaway reading colliders / drawing), and the floodlight and sign left uncut.
DRAWN_DIR := $(BUILD_DIR)/camera-drawn
DRAWN_ARENA ?= terminus

camera-drawn: import ## Round 12: the camera and the cutaway asking what is DRAWN, before/after pairs at the lead's pose -> build/camera-drawn/<arena>/index.html (DRAWN_ARENA=terminus; needs a display: make remote T=camera-drawn)
	rm -rf $(DRAWN_DIR)/$(DRAWN_ARENA) && mkdir -p $(DRAWN_DIR)/$(DRAWN_ARENA) && touch $(BUILD_DIR)/.gdignore
	timeout 420 $(GODOT) --path . --resolution 1920x1080 -- $(CAMERA_LOOKS_FLAGS) --arena=$(DRAWN_ARENA) \
		--camera-looks-grid=drawn --camera-looks=$(CURDIR)/$(DRAWN_DIR)/$(DRAWN_ARENA) 2>&1 \
		| tee $(DRAWN_DIR)/$(DRAWN_ARENA)/run.log | grep -E 'CAMERA_LOOKS|SCRIPT ERROR|^ERROR' || true
	grep -q 'CAMERA_LOOKS_DONE ok=true' $(DRAWN_DIR)/$(DRAWN_ARENA)/run.log
	@echo "Now LOOK at $(DRAWN_DIR)/$(DRAWN_ARENA)/index.html"

## Control X4: what spawning a 30-a-side army costs per vehicle (FIGHT's stall). SPAWN_THEME=default compares the box art.
spawn-cost: import ## Headless: ms per spawned vehicle, first of each type vs the rest, per faction army
	$(GODOT) --headless --path . --script res://game/ui/spawn_cost_bench.gd -- $(if $(SPAWN_THEME),--theme=$(SPAWN_THEME)) 2>&1 | grep -E 'SPAWN_COST|SCRIPT ERROR|^ERROR'

## Round 8 policy (_agents/verification.md "Timing in tests"): make check only MEASURES control's timing budgets; this
## JUDGES them. Run it on purpose on an uncontended machine (`make remote T=control-timing` when builder0 is idle):
## under full oversubscription the order path measured 14x slower against a 2x reference, so no ratio survives that.
control-timing: import ## Judge control's timing budgets (frame, order, click, health bars) - run on an idle machine
	TANK_SQUAD_JUDGE_TIMING=1 $(GODOT) --headless $(PIN_FPS) --path . --script res://tests/run_tests.gd -- --filter=test_control_scale
	TANK_SQUAD_JUDGE_TIMING=1 $(GODOT) --headless $(PIN_FPS) --path . --script res://tests/run_tests.gd -- --filter=test_control_readability

## Round 10 (control item 1, contract R2; the lead: "I was trying to right click to move them in a different direction
## and they didnt respond"). Squad 1 en route on Terminus, a right-click 40 m off its line, per tick per crew what Orders
## says it CARRIES OUT, in seven in-flight states. Fails when any crew's order is unchanged 2 ticks after the click.
REPATH_DIR := $(BUILD_DIR)/repath
REPATH_ARENA ?= terminus
## No damage: a repath test measures commanding, not fighting, and the late states ("arrived") need living crews
## (squad's run on main: six of eight crews dead by the arrived click, every STALE a corpse).
REPATH_FLAGS ?= --player-faction=condemned --enemy-faction=law --tune=match.no_damage=1

repath-test: import ## R2: a right-click on a squad already moving, seven ways, on Terminus; per-tick crew orders in build/repath/repath.json (headless)
	rm -rf $(REPATH_DIR) && mkdir -p $(REPATH_DIR)
	timeout 300 $(GODOT) --headless --path . -- --skirmish --seed=3 --no-pick-faction --mute --arena=$(REPATH_ARENA) \
		$(REPATH_FLAGS) --repath-test=$(CURDIR)/$(REPATH_DIR) $(if $(ONLY),--repath-only=$(ONLY)) 2>&1 \
		| tee $(REPATH_DIR)/run.log | grep -E '^REPATH|SCRIPT ERROR|^ERROR' || true
	grep -q 'REPATH_DONE ok=true' $(REPATH_DIR)/run.log

SCREEN_DIR ?= build/screen
SCREEN_ARENA ?= terminus
SCREEN_FLAGS ?= --player-faction=gangs --enemy-faction=law --tune=match.no_damage=1

.PHONY: screen-probe
screen-probe: import ## The lead's "screen did nothing": a Screen task grouped / ungrouped / near, and a move control, through real input on Terminus (ONLY=grouped,near) -> build/screen/screen.json
	rm -rf $(SCREEN_DIR) && mkdir -p $(SCREEN_DIR)
	timeout 300 $(GODOT) --headless --path . -- --skirmish --seed=3 --no-pick-faction --mute --arena=$(SCREEN_ARENA) \
		$(SCREEN_FLAGS) --screen-test=$(CURDIR)/$(SCREEN_DIR) $(if $(ONLY),--screen-only=$(ONLY)) 2>&1 \
		| tee $(SCREEN_DIR)/run.log | grep -E '^SCREEN|SCRIPT ERROR|^ERROR' || true
	@grep -q 'SCREEN_DONE' $(SCREEN_DIR)/run.log || { echo "screen-probe FAILED: no SCREEN_DONE line"; exit 1; }

## Round 26 (orders O2): his case for every armed task - squads 1 and 2 selected, the task's key, the real press-drag-
## release 60 deg off a sideways travel in our own half - judged when every hull has been still 3 s (75 s at most): each squad's hulls and line within 15 deg of the drawn facing.
## Prints SCREEN lines and `SCREEN_DONE ... ignored_facing=<tasks>`; FACING_ONLY=faced_screen,faced_ambush for some.
## Report only (exit 0 when it ran): which tasks honour the facing is brains' (C26.3), read from ignored_facing.
FACING_DIR ?= build/facing
FACING_ONLY ?= faced
FACING_ALL := faced_screen,faced_support_by_fire,faced_ambush,faced_attack_move,faced_move,faced_right
_FACING_COMMA := ,
_FACING_TASKS = $(subst $(_FACING_COMMA), ,$(if $(filter faced,$(FACING_ONLY)),$(FACING_ALL),$(FACING_ONLY)))
FACING_ARENA ?= foundry
## Seeds, one fresh match per task per seed (the orchestrator: n >= 3).
FACING_SEEDS ?= 3 5 8
## Two arms (the orchestrator, 2026-10-11): `quiet` = the enemy is an army that forms up and holds at its base
## (FACING_QUIET_ENEMY, a doctrine whose squads hold, with --no-element-cpu: under the element CPU it advanced from 167 m
## to 4-20 m), so nobody is in sight and the 15 deg line is judged; `contact` =
## the seeded CPU, where a crew facing a visible enemy instead of the drawn facing is by design: reported, not judged.
FACING_ARMS ?= quiet contact
FACING_QUIET_ENEMY ?= player_default
## The frames are of the gesture and its marker: the quiet arm's enemy, and a camera that holds the drag frame's pose
## (the vision camera reframes the selection every frame, so the settled frame drifted off the drawn spot).
FACING_SHOTS_FLAGS ?= --enemy=$(FACING_QUIET_ENEMY) --no-element-cpu --no-vision-camera
FACING_SIZES ?= 1854x1011 1200x540
.PHONY: facing-probe facing-shots
facing-probe: import ## O2: every armed task given a drawn facing by the real gesture (two squads), one fresh match per task; headless -> build/facing/headless/<arm>/<task>-<seed>/screen.json + a table per arm
	rm -rf $(FACING_DIR)/headless && mkdir -p $(FACING_DIR)/headless
	for arm in $(FACING_ARMS); do for seed in $(FACING_SEEDS); do for task in $(_FACING_TASKS); do \
		d=$(FACING_DIR)/headless/$$arm/$$task-$$seed; mkdir -p $$d; \
		enemy=""; if [ $$arm = quiet ]; then enemy="--enemy=$(FACING_QUIET_ENEMY) --no-element-cpu"; fi; \
		timeout 300 $(GODOT) --headless $(PIN_FPS) --path . -- --skirmish --seed=$$seed --no-pick-faction --mute --arena=$(FACING_ARENA) \
			$(SCREEN_FLAGS) $$enemy --screen-test=$(CURDIR)/$$d --screen-only=$$task > $$d/run.log 2>&1 || true; \
		grep -E '^SCREEN |SCRIPT ERROR' $$d/run.log || true; \
		grep -q 'SCREEN_DONE' $$d/run.log || { echo "facing-probe FAILED: $$task has no SCREEN_DONE line"; exit 1; }; \
		! grep -q 'SCRIPT ERROR' $$d/run.log || exit 1; \
	done; done; done
	for arm in $(FACING_ARMS); do python3 tools/facing_probe_table.py $(FACING_DIR)/headless/$$arm $$arm; done

# Round 27 (O3): hull facing at rest, per hull class, same-seed A/B. Arm `drawn` = the real press-drag-release (as
# facing-probe's quiet arm); arm `clicked` = the same order clicked at the same spot (automatic facing), judged against
# the same heading. Every faction in HULL_FACTIONS (their hull classes differ), HULL_SEEDS each; JOBS in parallel.
# Report only -> build/hull-rest/<arm>/<faction>/<task>-<seed>/screen.json + the table (tools/hull_rest_table.py).
HULL_FACTIONS ?= gangs law syndicate condemned
HULL_SEEDS ?= 3 5 8 11 13 21
HULL_DIR ?= build/hull-rest
HULL_JOBS ?= 6
.PHONY: hull-rest-probe
hull-rest-probe: import ## O3: hull facing at rest per hull class, drawn v clicked on the same seeds (quiet arm), every faction -> build/hull-rest/ + a table
	rm -rf $(HULL_DIR) && mkdir -p $(HULL_DIR)
	for arm in drawn clicked; do for faction in $(HULL_FACTIONS); do for seed in $(HULL_SEEDS); do for task in $(_FACING_TASKS); do \
		echo "$$arm $$faction $$seed $$task"; done; done; done; done | xargs -P $(HULL_JOBS) -L 1 sh -c '\
		d=$(HULL_DIR)/$$0/$$1/$$3-$$2; mkdir -p $$d; enemy=law; [ $$1 = law ] && enemy=gangs; \
		click=""; [ $$0 = clicked ] && click=--faced-click; \
		timeout 300 $(GODOT) --headless $(PIN_FPS) --path . -- --skirmish --seed=$$2 --no-pick-faction --mute --arena=$(FACING_ARENA) \
			--player-faction=$$1 --enemy-faction=$$enemy --tune=match.no_damage=1 --enemy=$(FACING_QUIET_ENEMY) \
			--no-element-cpu $$click --screen-test=$(CURDIR)/$$d --screen-only=$$3 > $$d/run.log 2>&1; \
		grep -q SCREEN_DONE $$d/run.log || echo "hull-rest-probe: $$d has no SCREEN_DONE"; \
		! grep -m1 "SCRIPT ERROR" $$d/run.log'
	python3 tools/hull_rest_table.py $(HULL_DIR)

# Round 27 (O1 end to end, C27.3): squad 1 recalled with its key, the real right-drag off the nearest enemy to a side 90
# deg off the line of approach (left and right), drawn v clicked on the same seeds; the squad's bearing from its target
# every second against the side drawn. Quiet arm (the enemy holds at its base, no damage). Report only.
FLANK_SEEDS ?= 3 5 8 11 13 21
FLANK_DIR ?= build/flank
.PHONY: flank-probe
flank-probe: import ## O1: attack from a drawn side through the real input, drawn v clicked, left/right, FLANK_SEEDS -> build/flank/ + a table
	rm -rf $(FLANK_DIR) && mkdir -p $(FLANK_DIR)
	for arm in drawn clicked; do for side in left right; do for seed in $(FLANK_SEEDS); do echo "$$arm $$side $$seed"; \
		done; done; done | xargs -P $(HULL_JOBS) -L 1 sh -c '\
		d=$(FLANK_DIR)/$$0/$$1-$$2; mkdir -p $$d; click=""; [ $$0 = clicked ] && click=--faced-click; \
		timeout 300 $(GODOT) --headless $(PIN_FPS) --path . -- --skirmish --seed=$$2 --no-pick-faction --mute --arena=$(FACING_ARENA) \
			$(SCREEN_FLAGS) --enemy=$(FACING_QUIET_ENEMY) --no-element-cpu $$click --flank-side=$$1 \
			--screen-test=$(CURDIR)/$$d --screen-only=flank > $$d/run.log 2>&1; \
		grep -q SCREEN_DONE $$d/run.log || echo "flank-probe: $$d has no SCREEN_DONE"; \
		! grep -m1 "SCRIPT ERROR" $$d/run.log'
	python3 tools/flank_probe_table.py $(FLANK_DIR)

FLANK_SHOT_FLAGS ?= --enemy=$(FACING_QUIET_ENEMY) --no-element-cpu --no-vision-camera
flank-shots: import ## O1: the flank drag in windows (FACING_SIZES): the drag, closing at 30 s, the end -> build/flank/<size>/shots/*.png (needs a display)
	for size in $(FACING_SIZES); do d=$(FLANK_DIR)/$$size; rm -rf $$d && mkdir -p $$d; \
		timeout 300 $(GODOT) --path . --resolution $$size -- --skirmish --seed=3 --no-pick-faction --mute --arena=$(FACING_ARENA) \
			$(SCREEN_FLAGS) $(FLANK_SHOT_FLAGS) --screen-test=$(CURDIR)/$$d --screen-only=flank > $$d/run.log 2>&1 || true; \
		grep -E '^SCREEN |SCRIPT ERROR' $$d/run.log | cut -c1-400 || true; grep -q SCREEN_DONE $$d/run.log || exit 1; \
	done
	@echo "Now LOOK at $(FLANK_DIR)/*/shots/*.png"

# O4: his flank clip. The flank scenario recorded through Movie Maker (1080p at DEMO_FPS, sound), damage ON so it ends
# when the target dies, the camera following his squad (the vision camera). MOVIE= the .mp4 (default build/flank.mp4).
FLANK_CLIP_SEED ?= 21
flank-clip: import ## O4: a short clip of a flank attack through the real gesture -> MOVIE (default build/flank.mp4; renders slower than real time, needs a display)
	@movie="$(or $(MOVIE),$(CURDIR)/$(BUILD_DIR)/flank.mp4)"; case "$$movie" in /*) ;; *) movie="$(CURDIR)/$$movie" ;; esac; \
	avi="$${movie%.*}.avi"; d=$(FLANK_DIR)/clip; rm -rf $$d && mkdir -p $$d "$$(dirname "$$movie")"; \
	timeout 900 $(GODOT) --path . --write-movie "$$avi" --fixed-fps $(DEMO_FPS) -- --skirmish --seed=$(FLANK_CLIP_SEED) \
		--no-pick-faction --arena=$(FACING_ARENA) --player-faction=gangs --enemy-faction=law \
		--enemy=$(FACING_QUIET_ENEMY) --no-element-cpu --hints=off --flank-side=$(or $(SIDE),left) \
		--screen-test=$(CURDIR)/$$d --screen-only=flank > $$d/run.log 2>&1 || true; \
	grep -E '^SCREEN |SCRIPT ERROR' $$d/run.log | cut -c1-300; grep -q SCREEN_DONE $$d/run.log || exit 1; \
	if command -v ffmpeg >/dev/null; then ffmpeg -loglevel error -y -i "$$avi" -c:v libx264 -preset slow -crf 18 \
		-pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart "$$movie" && rm -f "$$avi" && echo "FLANK_MOVIE $$movie"; \
	else echo "FLANK_MOVIE $$avi"; fi

facing-shots: import ## O2: the same in windows (FACING_SIZES: his 1854x1011 and a 1200x540 phone): the drag, moving, settled -> build/facing/<size>/<task>/shots/*.png (needs a display)
	for size in $(FACING_SIZES); do for task in $(_FACING_TASKS); do \
		d=$(FACING_DIR)/$$size/$$task; rm -rf $$d && mkdir -p $$d; \
		timeout 300 $(GODOT) --path . --resolution $$size -- --skirmish --seed=3 --no-pick-faction --mute --arena=$(FACING_ARENA) \
			$(SCREEN_FLAGS) $(FACING_SHOTS_FLAGS) --screen-test=$(CURDIR)/$$d --screen-only=$$task > $$d/run.log 2>&1 || true; \
		grep -E '^SCREEN_DONE|SCRIPT ERROR' $$d/run.log || true; \
		grep -q 'SCREEN_DONE' $$d/run.log || exit 1; \
	done; done
	@echo "Now LOOK at $(FACING_DIR)/*/*/shots/*.png"

## Round 21 (orders, O1): the five-squad order in windows (TWO_SIZES), frames of the dots the moment after the click
## (6_five_ordered), at 5 s and settled: build/five-squads-shots/<size>/*.png (needs a display). FIVE_ARENA, FIVE_SEED,
## FIVE_CLICK as the series.
FIVE_ARENA ?= foundry
## FIVE_FLAGS: more game flags for the frames (--ui-touch: the phone's 1.5x HUD).
FIVE_FLAGS ?=
.PHONY: five-squads-shots
five-squads-shots: import ## Round 21 (O1): five gang squads, one attack-move, in windows: frames in build/five-squads-shots/<size>/*.png
	for size in $(TWO_SIZES); do \
		d=$(CURDIR)/build/five-squads-shots/$$size; rm -rf $$d; mkdir -p $$d; \
		s=0; timeout $(TWO_TIMEOUT) $(GODOT) --path . --resolution $$size -- --skirmish --enemy=cpu --seed=$(FIVE_SEED) --control-playtest=$$d --two-squads --five-squads \
			--five-shape=vee $(if $(FIVE_CLICK),--two-click=$(FIVE_CLICK)) $(FIVE_ARMY) --arena=$(FIVE_ARENA) $(FIVE_FLAGS) > $$d/run.log 2>&1 || s=$$?; \
		grep -E 'FIVE_SQUADS summary|TWO_SQUADS_DONE|SCRIPT ERROR|^ERROR' $$d/run.log | cut -c1-400 || true; \
		[ $$s -eq 0 ] || echo "five-squads-shots $$size: exited $$s"; \
	done
	@echo "Now LOOK at build/five-squads-shots/*/*.png"

# Round 34 (planner, orders' O5 for C34.11; measurement only): his "select 3 squads, click one point" case through
# RtsControls.order_selection (tests/orders_probe.gd). Every map x squad count x route x arm, headless; one row a squad
# (anchor offset from the click, drive, deck / far bank, arrival, nearest foreign hull, the shuffle after arrival) and
# the table (tests/control/orders_probe_table.py). An arm is NAME:FLAGS (main's own switches: O1 --ground-cap=off, O3
# --halt-price=off; O2's when it lands). orders-probe-shots: the same in a window, top-down at arrival, desktop and phone.
ORDERS_PROBE_MAPS ?= locks crossing terminus
ORDERS_PROBE_SQUADS ?= 3 5
ORDERS_PROBE_ROUTES ?= click route
ORDERS_PROBE_ARMS ?= main: cap_off:--ground-cap=off halt_off:--halt-price=off
ORDERS_PROBE_DIR ?= $(BUILD_DIR)/orders-probe
ORDERS_PROBE_JOBS ?= 4
.PHONY: orders-probe orders-probe-shots
orders-probe: import ## O5: the multi-squad player probe, headless, ORDERS_PROBE_MAPS x _SQUADS x _ROUTES x _ARMS -> build/orders-probe/rows.jsonl + table.txt
	@rm -rf $(ORDERS_PROBE_DIR)/logs && mkdir -p $(ORDERS_PROBE_DIR)/logs
	@echo ">> orders-probe on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off)"
	@for map in $(ORDERS_PROBE_MAPS); do for n in $(ORDERS_PROBE_SQUADS); do for route in $(ORDERS_PROBE_ROUTES); do for arm in $(ORDERS_PROBE_ARMS); do \
		echo "$$map $$n $$route $$arm"; done; done; done; done | xargs -P $(ORDERS_PROBE_JOBS) -L 1 sh -c \
		'name=$${3%%:*}; flags=$$(echo "$${3#*:}" | tr "," " "); \
		timeout 600 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/orders_probe.gd -- --arena=$$0 --seed=34 \
			--probe-squads=$$1 --probe-route=$$2 --probe-arm=$$name $$flags > $(ORDERS_PROBE_DIR)/logs/$$0-$$1-$$2-$$name.log 2>&1 || true'
	@cat $(ORDERS_PROBE_DIR)/logs/*.log | grep -h '^ORDERS_PROBE_SQUAD ' | sed 's/^ORDERS_PROBE_SQUAD //' > $(ORDERS_PROBE_DIR)/rows.jsonl || true
	@grep -L '^ORDERS_PROBE {' $(ORDERS_PROBE_DIR)/logs/*.log | sed 's/^/MISSING (no ORDERS_PROBE line): /' || true
	@$(PYTHON) tests/control/orders_probe_table.py $(ORDERS_PROBE_DIR)/rows.jsonl | tee $(ORDERS_PROBE_DIR)/table.txt

ORDERS_PROBE_SHOT_SQUADS ?= 3 5
ORDERS_PROBE_SHOT_ARMS ?= main: cap_off:--ground-cap=off
ORDERS_PROBE_SHOT_ROUTES ?= click
orders-probe-shots: import ## O5: in a window, top-down at arrival and 5 s later (desktop 1280x720, phone 1560x720), ORDERS_PROBE_MAPS x _SHOT_SQUADS x _SHOT_ROUTES x _SHOT_ARMS -> build/orders-probe/shots/*.png (needs a display)
	@mkdir -p $(ORDERS_PROBE_DIR)/shots
	@for map in $(ORDERS_PROBE_MAPS); do for n in $(ORDERS_PROBE_SHOT_SQUADS); do for route in $(ORDERS_PROBE_SHOT_ROUTES); do \
	for arm in $(ORDERS_PROBE_SHOT_ARMS); do \
		name=$${arm%%:*}; flags=$$(echo "$${arm#*:}" | tr "," " "); \
		timeout 600 $(GODOT) --fixed-fps $(SIM_HZ) --path . --script res://tests/orders_probe.gd -- --arena=$$map --seed=34 \
			--probe-squads=$$n --probe-route=$$route --probe-arm=$$name --mute --probe-shots=$(ORDERS_PROBE_DIR)/shots $$flags \
			2>&1 | grep -E '^ORDERS_PROBE( \{|_SHOT)' || true; \
	done; done; done; done

# Round 35 (orders D1, C35.2): the deploy step reaches CPU elements, so its ship check carries this REPORTED fights census:
# CPU v CPU on DEPLOY_CENSUS_ARENAS (fixed arenas; random ones deal twins, R34.15) x DEPLOY_CENSUS_SEEDS (fresh), factions
# rotated by seed, each fight once per arm (on = main, off = --deploy-step=off) -> build/deploy-census/<arm>/*.log + the
# paired table (deaths, kills, stuck crew-seconds and squads deployed, by side; a gross line is > 2 se).
DEPLOY_CENSUS_ARENAS ?= locks terminus sumps
DEPLOY_CENSUS_SEEDS ?= $(shell seq 3501 3516)
DEPLOY_CENSUS_SECONDS ?= 150
DEPLOY_CENSUS_JOBS ?= 4
DEPLOY_CENSUS_DIR ?= $(BUILD_DIR)/deploy-census
DEPLOY_CENSUS_FACTIONS ?= law,gangs condemned,syndicate gangs,condemned syndicate,law
.PHONY: deploy-census
deploy-census: native-for-check import ## Round 35 (orders D1): CPU v CPU fights census, deploy step on v --deploy-step=off, DEPLOY_CENSUS_ARENAS x _SEEDS -> build/deploy-census/ + table.txt
	@rm -rf $(DEPLOY_CENSUS_DIR) && mkdir -p $(DEPLOY_CENSUS_DIR)/on $(DEPLOY_CENSUS_DIR)/off
	@echo ">> deploy-census on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@set -- $(DEPLOY_CENSUS_FACTIONS); nf=$$#; for arm in on off; do for map in $(DEPLOY_CENSUS_ARENAS); do for seed in $(DEPLOY_CENSUS_SEEDS); do \
		i=$$(( seed % nf + 1 )); eval pair=\$${$$i}; echo "$$arm $$map $$seed $$pair"; done; done; done | xargs -P $(DEPLOY_CENSUS_JOBS) -L 1 sh -c \
		'g=$${3%%,*}; r=$${3#*,}; flags=""; [ "$$0" = off ] && flags="--deploy-step=off"; \
		timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/control/deploy_census.gd -- --arena=$$1 --seed=$$2 \
			--green=$$g --rust=$$r --credits=1000 --seconds=$(DEPLOY_CENSUS_SECONDS) $$flags > $(DEPLOY_CENSUS_DIR)/$$0/$$1-$$2.log 2>&1 || true; \
		echo "  ran $$0 $$1 s$$2"'
	@grep -L '^DEPLOY_CENSUS ' $(DEPLOY_CENSUS_DIR)/*/*.log | sed 's/^/MISSING (no DEPLOY_CENSUS line): /' || true
	@$(PYTHON) tests/control/deploy_census_table.py $(DEPLOY_CENSUS_DIR)/off $(DEPLOY_CENSUS_DIR)/on | tee $(DEPLOY_CENSUS_DIR)/table.txt
