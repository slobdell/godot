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
		--budget=$(PERF_BUDGET) --no-pick-faction --cinematic $(if $(PERF_SOUND),,--mute) --announcer-history=off --music-history=off --render-preset=desktop \
		--perf-scene=$(CURDIR)/$(BUILD_DIR)/$(PERF_NAME).json --perf-shot=$(CURDIR)/$(BUILD_DIR)/screenshots/$(PERF_NAME).png \
		--perf-warmup=$(PERF_WARMUP) --perf-seconds=$(PERF_SECONDS) --perf-cycles=$(PERF_CYCLES) \
		$(if $(PERF_LAYERS),--perf-layers=$(PERF_LAYERS)) $(PERF_FLAGS) \
		2>&1 | tee $(BUILD_DIR)/$(PERF_NAME).log | grep -E '^PERF_SCENE|SCRIPT ERROR' || true
	@echo "instance-uniform errors: $$(grep -c 'Too many instances using shader instance variables' $(BUILD_DIR)/$(PERF_NAME).log || true)"
	@echo "other engine errors:     $$(grep -E '^ERROR|SCRIPT ERROR' $(BUILD_DIR)/$(PERF_NAME).log | grep -vc 'Too many instances using shader instance variables' || true)"
	@grep -q PERF_SCENE_DONE $(BUILD_DIR)/$(PERF_NAME).log

# Round 16 (play P1, CP1): THE GAME HE PLAYS, measured. `perf-scene` is a spectated CPU-v-CPU match with its own camera
# and the sound muted; this is his `make skirmish` launch with a human side (the fog field, the controls, the markers,
# the booth, the music and the recorder live), at his window, Law v Condemned on the Sumps as his 2026-10-02 recording.
# Two arms per seed in one target: UNCAPPED (what a frame costs) and --perf-capped (LOCKED_30: does it hold, and what
# share of frames miss the 34.3 ms line -- "choppy"). Layers: perf_scene.gd PLAY_LAYERS, or PERF_PLAY_LAYERS=a,b.
# Output: build/perf-play-<seed>[-capped].json, build/perf-play.json (= the first seed's uncapped arm, perf-scene's
# shape), screenshots build/screenshots/perf-play-<seed>*.png, and tools/perf_play_report.py's table + PERF_PLAY line.
PERF_PLAY_RES ?= 1854x1011
PERF_PLAY_SEEDS ?= 92721 31337
PERF_PLAY_ARENA ?= sumps
PERF_PLAY_FACTIONS ?= --player-faction=law --enemy-faction=condemned
PERF_PLAY_WARMUP ?= 6
PERF_PLAY_SECONDS ?= 2.5
PERF_PLAY_CYCLES ?= 2
PERF_PLAY_ARMS ?= uncapped capped
PERF_PLAY_LAYERS ?=
PERF_PLAY_FLAGS ?=
# The files' prefix: a second arm (e.g. PERF_PLAY_FLAGS=--sim-off=visfield_thread) keeps the first run's files with
# PERF_PLAY_NAME=perf-play-thread. PERF_PLAY_ARMS may add `frozen`: uncapped with --tune=match.no_damage=1 (nobody
# dies, so two RUNS see a comparable census; a windowed match diverges between runs past ~tick 150, render's finding).
PERF_PLAY_NAME ?= perf-play
# Render's R9 preset (chosen per launch by the adapter: integrated -> `laptop`, which his laptop AND builder0 are).
# `desktop` (the default) compares with every run before R9; PERF_PLAY_PRESET=laptop (with its own PERF_PLAY_NAME) is
# the frame he will actually feel. An unknown flag is ignored, so this is harmless before R9 merges.
PERF_PLAY_PRESET ?= desktop

perf-play: import ## Round 16 CP1: his path measured -- a human-side skirmish with his flags at his window, uncapped AND capped, layers no_visfield/no_controls/no_audio/no_recorder → build/perf-play*.json, PERF_PLAY line (needs a display; PERF_PLAY_SEEDS, PERF_PLAY_ARMS, PERF_PLAY_LAYERS, PERF_PLAY_FLAGS)
	mkdir -p $(BUILD_DIR)/screenshots $(BUILD_DIR)/perf-play/recordings
	@set -e; for seed in $(PERF_PLAY_SEEDS); do for arm in $(PERF_PLAY_ARMS); do \
		name=$(PERF_PLAY_NAME)-$$seed$$( [ $$arm = uncapped ] || echo -$$arm ); \
		printf '>> perf-play seed=%s arm=%s | load %s | %s other godot\n' $$seed $$arm "$$(cut -d' ' -f1-3 /proc/loadavg)" "$$(pgrep -c -f 'Godot_v4' || echo 0)"; \
		timeout 600 $(GODOT) --path . --resolution $(PERF_PLAY_RES) -- --skirmish --enemy=cpu --seed=$$seed \
			--arena=$(PERF_PLAY_ARENA) $(PERF_PLAY_FACTIONS) --announcer=voice --music=on --camera-readout=on --hints=off \
			--announcer-history=off --music-history=off --render-preset=$(PERF_PLAY_PRESET) \
			--record-dir=$(CURDIR)/$(BUILD_DIR)/perf-play/recordings \
			--perf-play --perf-scene=$(CURDIR)/$(BUILD_DIR)/$$name.json --perf-shot=$(CURDIR)/$(BUILD_DIR)/screenshots/$$name.png \
			--perf-warmup=$(PERF_PLAY_WARMUP) --perf-seconds=$(PERF_PLAY_SECONDS) --perf-cycles=$(PERF_PLAY_CYCLES) \
			$$( [ $$arm = capped ] && echo --perf-capped || true ) $$( [ $$arm = frozen ] && echo --tune=match.no_damage=1 || true ) \
			$(if $(PERF_PLAY_LAYERS),--perf-layers=$(PERF_PLAY_LAYERS)) $(PERF_PLAY_FLAGS) \
			> $(BUILD_DIR)/$$name.log 2>&1 || true; \
		grep -E '^PERF_PLAY_(START|DRIVEN)|SCRIPT ERROR' $(BUILD_DIR)/$$name.log || true; \
		echo "   engine errors: $$(grep -cE '^ERROR|SCRIPT ERROR' $(BUILD_DIR)/$$name.log || true)"; \
		grep -q PERF_PLAY_DONE $(BUILD_DIR)/$$name.log || { echo "perf-play $$name did not finish: $(BUILD_DIR)/$$name.log"; exit 1; }; \
	done; done
	cp $(BUILD_DIR)/$(PERF_PLAY_NAME)-$(firstword $(PERF_PLAY_SEEDS)).json $(BUILD_DIR)/$(PERF_PLAY_NAME).json 2>/dev/null || true
	python3 tools/perf_play_report.py $(foreach seed,$(PERF_PLAY_SEEDS),$(BUILD_DIR)/$(PERF_PLAY_NAME)-$(seed).json $(BUILD_DIR)/$(PERF_PLAY_NAME)-$(seed)-capped.json $(BUILD_DIR)/$(PERF_PLAY_NAME)-$(seed)-frozen.json)

CROWD_RES ?= 1920x1080
crowd-look: import ## Feel X1: can a player see the crowd? A real skirmish shot at every camera zoom, with/without the crowd and fog → build/crowd-look/*.png, CROWD_LOOK lines (needs a display; CROWD_FLAGS="--fx-quality=low", ARENA=)
	rm -rf $(BUILD_DIR)/crowd-look && mkdir -p $(BUILD_DIR)/crowd-look
	timeout 600 $(GODOT) --path . --resolution $(CROWD_RES) -- --skirmish --scripted --seed=3 --no-pick-faction --mute \
		$(if $(ARENA),--arena=$(ARENA)) --crowd-look=$(CURDIR)/$(BUILD_DIR)/crowd-look $(CROWD_FLAGS) \
		2>&1 | tee $(BUILD_DIR)/crowd-look/log.txt | grep -E '^CROWD_LOOK|SCRIPT ERROR|^SKIRMISH_CAMERA' || true
	@grep -q CROWD_LOOK_DONE $(BUILD_DIR)/crowd-look/log.txt

SIZE_RES ?= 1920x1080
size-look: import ## Round 8: the War Rig beside a scout and a tank at the lead's camera (21 deg, 49 m, FOV 35), once per candidate length → build/size-look/rig_<m>.png, SIZE_LOOK lines (needs a display; LENGTHS=5.6,10,12, ARENA=, SIZE_FLAGS="--player-faction=gangs --budget=6500")
	rm -rf $(BUILD_DIR)/size-look && mkdir -p $(BUILD_DIR)/size-look
	timeout 300 $(GODOT) --path . --resolution $(SIZE_RES) -- --skirmish --scripted --seed=3 --no-pick-faction --mute \
		$(if $(ARENA),--arena=$(ARENA)) --size-look=$(CURDIR)/$(BUILD_DIR)/size-look $(if $(LENGTHS),--size-look-lengths=$(LENGTHS)) $(SIZE_FLAGS) \
		2>&1 | tee $(BUILD_DIR)/size-look/log.txt | grep -E '^SIZE_LOOK|SCRIPT ERROR' || true
	@grep -q SIZE_LOOK_DONE $(BUILD_DIR)/size-look/log.txt

RIG_HINGE_RES ?= 1920x1080
rig-hinge: import ## Feel X2, S2: the War Rig bending at the fifth wheel -- its hinge in a LIVE match, then a corner shot at the lead's pose (21 deg, FOV 35, 49 m) and from 45 deg for detail -> build/rig-hinge/ (needs a display; RIG_HINGE_FLAGS=, ARENA=)
	rm -rf $(BUILD_DIR)/rig-hinge && mkdir -p $(BUILD_DIR)/rig-hinge
	timeout 1500 $(GODOT) --path . --resolution $(RIG_HINGE_RES) -- --skirmish --scripted --seed=3 --no-pick-faction --mute \
		$(if $(ARENA),--arena=$(ARENA)) --rig-hinge=$(CURDIR)/$(BUILD_DIR)/rig-hinge \
		$(or $(RIG_HINGE_FLAGS),--player=cpu:gang_ram --player-faction=gangs --budget=6500) \
		2>&1 | tee $(BUILD_DIR)/rig-hinge/log.txt | grep -E '^RIG_HINGE|SCRIPT ERROR' || true
	@grep -q RIG_HINGE_DONE $(BUILD_DIR)/rig-hinge/log.txt || { grep -E 'RIG_HINGE_FAILED|SCRIPT ERROR' $(BUILD_DIR)/rig-hinge/log.txt; echo "rig-hinge FAILED"; exit 1; }
	@echo "Now LOOK at $(BUILD_DIR)/rig-hinge/strip_*.png -- the strips are written LAST, after every frame."
	@ls $(BUILD_DIR)/rig-hinge/strip_*.png

.PHONY: perf-trailer-ab
# WITHIN-RUN, and that is the whole point. The first version of this target ran two perf-scenes back to back in one
# slot and diffed them -- which show then showed to be worthless on a loaded box: its own back-to-back pair reported
# the instrumented arm 43% FASTER than the control, i.e. noise swamping any real difference. perf-scene already
# alternates `all` and a layer seconds apart for every other layer; the trailer gets the same treatment.
# THE TWO GUARDS ARE NOT EQUALLY STRONG, and it matters which one you trust.
#   `no_damage` per phase is the ARM ASSERTION: it reads `Armor.no_damage`, the same static `Tank.take_hit` gates
#   on, so it proves the freeze TOOK. It caught combat's initialisation-order bug -- the knob was accepted with no
#   error and never reached the predicate (2026-09-20, 13 of 13 phases false while the census walked 90 -> 77).
#   A constant census is NECESSARY BUT NOT SUFFICIENT: it can be satisfied by causes that have nothing to do with
#   this knob. combat's yaw constraint, if ever switched on, freezes most of an army at spawn (1100+ continuous
#   refused ticks, crews never departing) -- the census would sit perfectly still and the scene would not be a
#   battle at all. So never read a flat census as evidence the freeze worked; read the flag.
perf-trailer-ab: import ## M1: what the War Rig's hinge costs a frame, measured WITHIN one run (the no_trailer layer against the `all` phases either side)
	@printf '>> perf-trailer-ab BEFORE: load %s | %s other godot\n' \
		"$$(cut -d' ' -f1-3 /proc/loadavg)" "$$(pgrep -c -f 'Godot_v4' || echo 0)"
	@$(MAKE) --no-print-directory perf-scene PERF_NAME=perf-trailer PERF_LAYERS=no_trailer \
		PERF_FLAGS="--player-faction=gangs --enemy-faction=gangs --tune=match.no_damage=1"
	@printf '>> perf-trailer-ab AFTER:  load %s | %s other godot\n' \
		"$$(cut -d' ' -f1-3 /proc/loadavg)" "$$(pgrep -c -f 'Godot_v4' || echo 0)"
	@$(PYTHON) -c "import json;\
d=json.load(open('$(BUILD_DIR)/perf-trailer.json'));\
ph=d['phases'];\
print();\
print('PERF_TRAILER_AB phase      avg_ms   p95_ms   p99_ms  draws  vehicles');\
[print('PERF_TRAILER_AB %-10s %7.2f %8.2f %8.2f %6d %9d' % (p['phase'], p['avg_ms'], p['p95_ms'], p['p99_ms'], p['draw_calls'], p['vehicles'])) for p in ph];\
cyc=[((ph[i-1]['avg_ms']+ph[i+1]['avg_ms'])/2.0 - ph[i]['avg_ms'], ph[i]['vehicles'], ph[i-1]['vehicles'], ph[i+1]['vehicles']) for i in range(1,len(ph)-1) if ph[i]['phase']!='all'];\
print();\
[print('PERF_TRAILER_AB cycle %d: %+6.2f ms   (census %d / %d / %d)' % (n+1, c[0], c[2], c[1], c[3])) for n,c in enumerate(cyc)];\
keep=cyc[1:] if len(cyc)>2 else cyc;\
note=' (first cycle discarded: warm-up)' if len(cyc)>2 else ' (too few cycles to discard warm-up; run PERF_CYCLES=6)';\
costs=[c[0] for c in keep];\
mean=sum(costs)/len(costs); spread=max(costs)-min(costs);\
same=all(c>0 for c in costs) or all(c<0 for c in costs);\
census=[v for c in keep for v in c[1:]]; moved=(max(census)-min(census))>0;\
print();\
print('PERF_TRAILER_AB cycles kept: %s%s' % (', '.join('%+.2f' % c for c in costs), note));\
print('PERF_TRAILER_AB mean %+.2f ms, spread %.2f ms, signs %s, census %s' % (mean, spread, 'AGREE' if same else 'DISAGREE', 'CONSTANT' if not moved else 'MOVED %d..%d' % (min(census), max(census))));\
bad=[];\
frozen=[p for p in ph if not p.get('no_damage')];\
bad.append('the census freeze was OFF in %d of %d phases: this bench REFUSES to report without --tune=match.no_damage=1, because a caveat is the part that gets dropped when a number is quoted' % (len(frozen), len(ph))) if frozen else None;\
off=[c for c in costs if (c>0) != (mean>0)];\
bad.append('cycles disagreeing with the mean sign above the 0 bound in %d of %d samples (peak %+.2f ms)' % (len(off), len(costs), max(off, key=abs) if off else 0.0)) if not same else None;\
dev=[abs(c-mean) for c in costs];\
bad.append('per-cycle deviation from the mean above the |mean| bound of %.2f ms in %d of %d samples (peak %.2f ms)' % (abs(mean), sum(1 for d in dev if d > abs(mean)), len(dev), max(dev))) if spread > abs(mean) else None;\
rng=[max(c[1:])-min(c[1:]) for c in keep];\
bad.append('vehicle census change between phases above the 0 bound in %d of %d samples (peak %d vehicles), so the phases are not the same scene' % (sum(1 for r in rng if r > 0), len(rng), max(rng))) if moved else None;\
bad.append('usable cycles below the 2-cycle bound: %d of %d (run PERF_CYCLES=6)' % (len(keep), len(cyc))) if len(keep) < 2 else None;\
bad=[b for b in bad if b];\
print('PERF_TRAILER_AB VERDICT: ' + ('USABLE -- %+.2f ms CPU' % mean if not bad else 'NOT USABLE -- ' + '; '.join(bad) + '. Do not quote this number.'));\
print('PERF_TRAILER_AB M1 budget is 33.3 ms (a locked 30 fps at 1080p, 30 a side). Read the cost against that, not against zero.')"

AIRSHIP_RES ?= 1920x1080
airship-look: import ## Feel X7: is the Syndicate airship EVER in the lead's field of view? Sweeps every camera yaw x the whole orbit at his pose and reports the fraction -> build/airship-look/ (needs a display; AIRSHIP_FLAGS=, ARENA=)
	rm -rf $(BUILD_DIR)/airship-look && mkdir -p $(BUILD_DIR)/airship-look
	timeout 900 $(GODOT) --path . --resolution $(AIRSHIP_RES) -- --skirmish --scripted --seed=3 --no-pick-faction --mute \
		$(if $(ARENA),--arena=$(ARENA)) --airship-look=$(CURDIR)/$(BUILD_DIR)/airship-look $(AIRSHIP_FLAGS) \
		2>&1 | tee $(BUILD_DIR)/airship-look/log.txt | grep -E '^AIRSHIP_LOOK|SCRIPT ERROR' || true
	@grep -q AIRSHIP_LOOK_DONE $(BUILD_DIR)/airship-look/log.txt || { grep -E 'AIRSHIP_LOOK_FAILED|SCRIPT ERROR' $(BUILD_DIR)/airship-look/log.txt; echo "airship-look FAILED"; exit 1; }
	@ls $(BUILD_DIR)/airship-look/*.png

airship-shot: import ## Round 11: frames of the Syndicate broadcast airship AT the lead's pose, deterministically flown to a tick (proves the art, the screens, the scale and the attitude; it makes no claim about how OFTEN he sees it) -> build/airship-shot/ (needs a display; ARENA=terminus, TICKS=0,900,1800, SEQUENCE=1 for the climb-over-a-block and camera-meets-hull frames, CLIP=1 to add 20 s of the live camera meeting the hull as clip.mp4, AIRSHIP_EXTRA=--airship-shot-pose=x,z,yawdeg,tick)
	rm -rf $(BUILD_DIR)/airship-shot && mkdir -p $(BUILD_DIR)/airship-shot
	timeout 600 $(GODOT) --path . --resolution $(AIRSHIP_RES) -- --skirmish --scripted --seed=3 --no-pick-faction --mute \
		--arena=$(or $(ARENA),terminus) --airship-shot=$(CURDIR)/$(BUILD_DIR)/airship-shot \
		$(if $(TICKS),--airship-shot-ticks=$(TICKS)) $(if $(SEQUENCE),--airship-shot-sequence) $(if $(CLIP),--airship-shot-clip) $(AIRSHIP_EXTRA) \
		2>&1 | tee $(BUILD_DIR)/airship-shot/log.txt | grep -E '^AIRSHIP_SHOT|SCRIPT ERROR' || true
	@grep -q AIRSHIP_SHOT_DONE $(BUILD_DIR)/airship-shot/log.txt || { grep -E 'SCRIPT ERROR' $(BUILD_DIR)/airship-shot/log.txt; echo "airship-shot FAILED"; exit 1; }
	@if ls $(BUILD_DIR)/airship-shot/clip_000.png >/dev/null 2>&1; then \
		ffmpeg -loglevel error -y -framerate 10 -i $(BUILD_DIR)/airship-shot/clip_%03d.png -vf scale=960:-2 -pix_fmt yuv420p \
			$(BUILD_DIR)/airship-shot/clip.mp4 && rm -f $(BUILD_DIR)/airship-shot/clip_*.png && echo $(BUILD_DIR)/airship-shot/clip.mp4; fi
	@ls $(BUILD_DIR)/airship-shot/*.png

rig-vanish: import ## Round 14 A0: the lead's two War Rigs that "turned invisible" -- his Locks match (seed 76424, Gangs v Condemned), two rigs at the swing-bridge ends where his stood, framed at his pose from YAWS camera yaws; per frame the nodes' visibility AND the pixels the rig actually draws (rendered with and without it) -> build/rig-vanish/ (needs a display; DRIVE=1 drives them there instead of placing them; DEPLOY=1 frames the deployed army 10 ticks in and lists any hull off the floor; REPLAY=<recording> replays his orders and logs every rig every tick; RIG_UNTIL=3400; RIG_ARENA=locks RIG_SEED=76424)
	rm -rf $(BUILD_DIR)/rig-vanish && mkdir -p $(BUILD_DIR)/rig-vanish
	timeout 900 $(GODOT) --path . --resolution 960x540 --fixed-fps $(SIM_HZ) --script res://game/theme/fx/bench/rig_vanish.gd -- \
		--skirmish --no-pick-faction --mute --no-record --hints=off --arena=$(or $(RIG_ARENA),locks) --seed=$(or $(RIG_SEED),76424) \
		--player-faction=gangs --enemy-faction=condemned --rig-vanish=$(CURDIR)/$(BUILD_DIR)/rig-vanish \
		$(if $(YAWS),--rig-vanish-yaws=$(YAWS)) $(if $(DRIVE),--rig-vanish-drive) $(if $(DEPLOY),--rig-vanish-deploy) $(if $(REPLAY),--rig-vanish-replay=$(abspath $(REPLAY))) $(if $(RIG_UNTIL),--rig-vanish-until=$(RIG_UNTIL)) \
		2>&1 | tee $(BUILD_DIR)/rig-vanish/log.txt | grep -E '^RIG_VANISH|^TANK_OFF_FLOOR|^ARMY_LAYOUT|SCRIPT ERROR' || true
	@grep -q RIG_VANISH_DONE $(BUILD_DIR)/rig-vanish/log.txt || { echo "rig-vanish FAILED"; exit 1; }

VIEW_MAPS ?= terminus yard crossing
VIEW_ARMS ?= off climb
VIEW_SEEDS ?= 7
VIEW_JOBS ?= 3
airship-view: import ## Round 14 A1/A3: the airship against the LIVE camera in a real skirmish driven the way the lead plays (the next group attack-moved every 12 s, the vision camera framing it; nothing dies and no control point, so every run is the full VIEW_S): per map, arm and seed, % of ticks the hull is in his frame, % it HIDES THE FIGHT (cuts the sight lines to the ground he looks at), the intrusions and their cause, mean yaw rate; then pooled per map and arm -> build/airship-view/ (headless; VIEW_MAPS="terminus yard crossing" VIEW_ARMS="off climb" (steer = the orbit term alone; climblive = climb over the live camera only; round 15 B2: climblow = climb only over the sight lines + a margin, climbsink = sink back 1.5x faster, climblowsink = both; B1: climbrest = plan against the camera's rest pose and climb over its lift zone, climbrest{low,sink,lowsink} = with the B2 levers, climbrestlead[low] = also climb for where the camera is heading; B4: *nolift = the camera never lifts over the hull, inside% counts the lens inside it; B2: climbliverestlow[sink] = viewrest+viewlow climbing for the live camera only) VIEW_SEEDS="7" VIEW_JOBS=3 VIEW_S=240; VIEW_DISPLAY=1 renders, ~6 fps on builder0, and saves the three worst frames per run; VIEW_TRACE=1 writes a per-tick trace_<map>_<arm>.csv per run, read by tools/airship_view_pool.py --trace)
	rm -rf $(BUILD_DIR)/airship-view && mkdir -p $(BUILD_DIR)/airship-view
	@for map in $(VIEW_MAPS); do for arm in $(VIEW_ARMS); do for seed in $(VIEW_SEEDS); do echo "$$map $$arm $$seed"; done; done; done | \
		xargs -P $(VIEW_JOBS) -L 1 sh -c 'timeout 1500 $(GODOT) $(if $(VIEW_DISPLAY),--resolution 1280x720,--headless) --path . --fixed-fps $(SIM_HZ) --script res://game/theme/arena_kit/airship/airship_view.gd -- \
			--skirmish --no-pick-faction --mute --no-record --hints=off --camera-readout=off --no-control --tune=match.no_damage=1 \
			--arena=$$0 --seed=$$2 --airship-view=$(CURDIR)/$(BUILD_DIR)/airship-view/$$1/$$2 --airship-view-seconds=$(or $(VIEW_S),240) $(if $(VIEW_TRACE),--airship-view-trace) \
			$$( case $$1 in off) echo --airship-off=viewclimb,viewsteer;; climb) echo --airship-on=viewclimb;; climblive) echo --airship-on=viewclimb --airship-off=climbsquads;; steer) echo --airship-on=viewsteer;; steerclimb) echo --airship-on=viewsteer,viewclimb;; climblow) echo --airship-on=viewclimb,viewlow;; climbsink) echo --airship-on=viewclimb,viewsink;; climblowsink) echo --airship-on=viewclimb,viewlow,viewsink;; climbrest) echo --airship-on=viewclimb,viewrest;; climbrestlow) echo --airship-on=viewclimb,viewrest,viewlow;; climbrestsink) echo --airship-on=viewclimb,viewrest,viewsink;; climbrestlowsink) echo --airship-on=viewclimb,viewrest,viewlow,viewsink;; climbrestlead) echo --airship-on=viewclimb,viewrest,viewlead;; climbrestleadlow) echo --airship-on=viewclimb,viewrest,viewlead,viewlow;; climbnolift) echo --airship-on=viewclimb --airship-off=cameralift;; climbrestnolift) echo --airship-on=viewclimb,viewrest --airship-off=cameralift;; climbrestlownolift) echo --airship-on=viewclimb,viewrest,viewlow --airship-off=cameralift;; climbliverestlow) echo --airship-on=viewclimb,viewrest,viewlow --airship-off=climbsquads;; climbliverestlowsink) echo --airship-on=viewclimb,viewrest,viewlow,viewsink --airship-off=climbsquads;; esac ) > $(BUILD_DIR)/airship-view/$$0-$$1-$$2.log 2>&1 || true'
	@grep -hE '^AIRSHIP_VIEW |AIRSHIP_VIEW_(FAILED|STALLED|CAUSES)|SCRIPT ERROR' $(BUILD_DIR)/airship-view/*.log | sort -k2,2 -k3,3 || true
	@$(PYTHON) tools/airship_view_pool.py $(BUILD_DIR)/airship-view
	@! grep -L AIRSHIP_VIEW_DONE $(BUILD_DIR)/airship-view/*.log | grep . || { echo "airship-view FAILED (see the logs above)"; exit 1; }

airship-report: import ## Round 11: how the broadcast airship flies each map -- % of the flight inside something drawn (must be 0), % at its low cruise, % in the lead's frame; per map, then POOLED (round 21: MAPS defaults to the live Arena.ROTATION; MAPS=a,b LEG_S=60 seconds per leg; AIRSHIP_FLAGS=--airship-off=x; headless)
	$(GODOT) --headless --path . --script res://game/theme/arena_kit/airship/airship_report.gd -- \
		$(if $(MAPS),--maps=$(MAPS)) $(if $(LEG_S),--seconds=$(LEG_S)) $(AIRSHIP_FLAGS) 2>&1 | grep -E '^AIRSHIP_REPORT|SCRIPT ERROR'
	@echo

facing-audit: import ## Every faction unit side-on with a red arrow along its engine forward (-Z): catches models that drive backwards → build/facing/<unit>.png (needs a display; UNITS=a,b TURRET=deg VIEW=side|top|quarter TINT=1: turret magenta, weapon yellow, cut gun cyan; BEND=deg: a trailer's hinge; MUZZLE=1: the simulated muzzle as a green ball + FACING_MUZZLE gap)
	rm -rf $(BUILD_DIR)/facing && mkdir -p $(BUILD_DIR)/facing
	timeout 300 $(GODOT) --path . --resolution 960x540 --script res://game/theme/gallery/facing_audit.gd -- \
		--facing-dir=$(CURDIR)/$(BUILD_DIR)/facing $(if $(UNITS),--facing-units=$(UNITS)) $(if $(TURRET),--facing-turret=$(TURRET)) $(if $(VIEW),--facing-view=$(VIEW)) $(if $(TINT),--facing-tint) $(if $(BEND),--facing-articulation=$(BEND)) $(if $(MUZZLE),--facing-muzzle) 2>&1 | grep -E 'FACING_AUDIT|FACING_MUZZLE|SCRIPT ERROR|SHADER ERROR' || true
	@grep -q . $(BUILD_DIR)/facing/*.png 2>/dev/null || { echo "facing-audit FAILED: no images"; exit 1; }

.PHONY: turret-probe
turret-probe: import ## Feel R5: each unit's drawn roof profile, turret/weapon art bounds and pivot in the tank frame -> build/turret-probe.json (headless; UNITS=a,b)
	@mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . --script res://game/theme/gallery/turret_probe.gd -- \
		--turret-probe-json=$(CURDIR)/$(BUILD_DIR)/turret-probe.json $(if $(UNITS),--turret-probe-units=$(UNITS)) \
		2>&1 | grep -E '^TURRET_PROBE|SCRIPT ERROR' || true
	@grep -q . $(BUILD_DIR)/turret-probe.json 2>/dev/null || { echo "turret-probe FAILED: no json"; exit 1; }

.PHONY: rim-pair
# Feel round 10, backlog 4: the per-faction rim as a PAIR at his pose (show's rule 12: one variable). Four arms of the
# same seed and frame -- show off/on x rim off/on -- each size-look's army.png (the army framed at 21 deg, 49 m, FOV
# 35). The eye judges; the frames are a pair per variable. Needs a display: `make remote T=rim-pair`.
rim-pair: import ## Feel: the per-faction hull rim, show off/on x rim off/on, one frame each at his pose -> build/rim-pair/<arm>/army.png (needs a display; ARENA=terminus, RIM_FLAGS=)
	rm -rf $(BUILD_DIR)/rim-pair && mkdir -p $(BUILD_DIR)/rim-pair
	@for arm in show-rim show-norim noshow-rim noshow-norim; do \
		flags=""; case $$arm in *noshow*) flags="$$flags --no-show";; esac; case $$arm in *norim*) flags="$$flags --no-faction-rim";; esac; \
		mkdir -p $(BUILD_DIR)/rim-pair/$$arm; \
		timeout 300 $(GODOT) --path . --resolution $(SIZE_RES) -- --skirmish --scripted --seed=3 --no-pick-faction --mute \
			--arena=$(or $(ARENA),terminus) --size-look=$(CURDIR)/$(BUILD_DIR)/rim-pair/$$arm --size-look-lengths=14 $$flags $(RIM_FLAGS) \
			> $(BUILD_DIR)/rim-pair/$$arm/log.txt 2>&1 || true; \
		grep -E '^SIZE_LOOK_ARMY|SCRIPT ERROR' $(BUILD_DIR)/rim-pair/$$arm/log.txt | sed "s/^/$$arm: /" || true; \
		test -f $(BUILD_DIR)/rim-pair/$$arm/army.png || { echo "rim-pair FAILED: no frame for $$arm"; exit 1; }; \
	done

.PHONY: lane-pair
# B10 / C11 (round 10): the lane markings as a PAIR at his pose on the Terminus (one variable: --no-lane-marks), the
# army framed at 21 deg / 49 m / FOV 35 at the start -- his opening view. Needs a display: `make remote T=lane-pair`.
lane-pair: import ## Feel: kerb paint, centre dashes and junction pools off/on at his pose -> build/lane-pair/<arm>/army.png (needs a display; ARENA=terminus)
	rm -rf $(BUILD_DIR)/lane-pair && mkdir -p $(BUILD_DIR)/lane-pair
	@for arm in marks nomarks; do \
		flags=""; case $$arm in nomarks) flags="--no-lane-marks";; esac; \
		mkdir -p $(BUILD_DIR)/lane-pair/$$arm; \
		timeout 300 $(GODOT) --path . --resolution $(SIZE_RES) -- --skirmish --scripted --seed=3 --no-pick-faction --mute \
			--arena=$(or $(ARENA),terminus) --size-look=$(CURDIR)/$(BUILD_DIR)/lane-pair/$$arm --size-look-lengths=14 $$flags \
			> $(BUILD_DIR)/lane-pair/$$arm/log.txt 2>&1 || true; \
		grep -E '^SIZE_LOOK_ARMY|SCRIPT ERROR' $(BUILD_DIR)/lane-pair/$$arm/log.txt | sed "s/^/$$arm: /" || true; \
		test -f $(BUILD_DIR)/lane-pair/$$arm/army.png || { echo "lane-pair FAILED: no frame for $$arm"; exit 1; }; \
	done

.PHONY: class-look
# Fleet round 15, F1 (garage's tour: "My tanks and IFVs look the same in the fight"): every faction's tank and IFV at
# his pose (21 deg, FOV 35, 72 m), five headings, lit and as a silhouette mask, at desktop (1920x1080) and phone
# (1800x810). CLASS_LOOK lines: per-heading area, box, mean lit colour, bright share, the pair's centred silhouette IoU;
# CLASS_LOOK_PAIR: the pair's mean/max IoU and drawn length ratio. Needs a display: `make remote T=class-look`.
CLASS_LOOK_SIZES ?= 1920x1080 1800x810
class-look: import ## Fleet F1: each faction's tank vs IFV at his pose (72 m), lit + silhouette, desktop and phone -> build/class-look/<size>/ + CLASS_LOOK lines + sheet.png (needs a display; PAIRS=condemned,law DISTANCE=49 HEADINGS=side,away UNITS=tank,ifv CLASS_LOOK_FLAGS=--no-class-mark for the unmarked before; LINEUP=1: every faction's scout/IFV/tank in one frame -> lineup_<heading>.png)
	rm -rf $(BUILD_DIR)/class-look && mkdir -p $(BUILD_DIR)/class-look
	@for size in $(CLASS_LOOK_SIZES); do \
		mkdir -p $(BUILD_DIR)/class-look/$$size; \
		timeout 600 $(GODOT) --path . --resolution $$size --script res://game/theme/gallery/class_look.gd -- \
			--class-look-dir=$(CURDIR)/$(BUILD_DIR)/class-look/$$size --class-look-size=$$size \
			$(if $(PAIRS),--class-look-pairs=$(PAIRS)) $(if $(DISTANCE),--class-look-distance=$(DISTANCE)) \
			$(if $(HEADINGS),--class-look-headings=$(HEADINGS)) $(if $(UNITS),--class-look-units=$(UNITS)) $(CLASS_LOOK_FLAGS) \
			$(if $(LINEUP),--class-look-lineup) \
			> $(BUILD_DIR)/class-look/$$size/log.txt 2>&1 || true; \
		grep -E '^CLASS_LOOK|SCRIPT ERROR|SHADER ERROR' $(BUILD_DIR)/class-look/$$size/log.txt || true; \
		grep -q CLASS_LOOK_DONE $(BUILD_DIR)/class-look/$$size/log.txt || { echo "class-look FAILED at $$size"; exit 1; }; \
		! grep -q CLASS_LOOK_STUCK $(BUILD_DIR)/class-look/$$size/log.txt || { echo "class-look FAILED: a unit did not turn"; exit 1; }; \
	done
	-$(PYTHON) tools/assets/class_look_sheet.py $(BUILD_DIR)/class-look

# Round 18 (finale E1): every frame through the END of a match, cut into physics / process / draw / rest, with a marker
# at the final kill, `finished`, the kill cam, the banner and the results (game/theme/fx/bench/frame_trace.gd). A
# scripted skirmish that ends by elimination early (the sumps, seed 1, ~tick 518: the kill cam's own witness), his
# window, his flags (voice, music), his preset by default (the adapter picks: `laptop` on a UHD 620). One JSON line a
# frame in build/end-trace/<name>-<run>.jsonl; FRAME_TRACE lines (the marks; `summary max_ms=` = the largest frame
# within 1 s of the final kill, `typical_ms` = the median of the 4 s before). Needs a display: on the laptop it OPENS
# ON HIS DESKTOP (~40 s a run). END_TRACE_PRESET=desktop|laptop forces one; END_TRACE_FLAGS adds a removal arm.
# Where traces go. A remote check's copy-back MIRRORS build/ (--delete), which erased this stream's first traces mid-run:
# point a long series outside build/ (END_TRACE_DIR=<scratchpad>).
END_TRACE_DIR ?= $(BUILD_DIR)/end-trace
END_TRACE_DIR_ABS = $(abspath $(END_TRACE_DIR))
END_TRACE_ARGS ?= --arena=sumps --seed=1 --budget=6500
END_TRACE_RES ?= 1854x1011
END_TRACE_RUNS ?= 3
END_TRACE_PRESET ?=
END_TRACE_FLAGS ?=
END_TRACE_NAME ?= end-trace
END_TRACE_AFTER ?= 6
# END_TRACE_COLD=1: every shader compiles as on the first run after an update -- this worktree's OWN Godot shader cache
# (override.cfg's custom user dir; never the shared "Tank Squad" one) is emptied before each run and Mesa's is disabled.
END_TRACE_COLD ?=
# END_TRACE_COLD_DIR: the user dir whose shader cache cold mode empties INSTEAD of override.cfg's. For the self-test's stub
# only (a real Godot writes its cache where override.cfg says, so a cold proof read from another dir would be false).
# Without either, cold mode prints END_TRACE_COLD_REFUSED and exits 3, and the measure reads that as NOT JUDGED. (The
# `|| true` on the sed: with no override.cfg sed exits 2, and under `set -e` that killed the recipe BEFORE the refusal
# could print -- the main checkout's "end-trace exited 2" on 2026-10-04.)
END_TRACE_COLD_DIR ?=
# Where the private user dir is named (a worktree's override.cfg); the self-test points it at nothing.
END_TRACE_OVERRIDE_CFG ?= override.cfg
# Engine flags (before `--`): builder0's hidden window is held at 1 fps by the compositor unless vsync is off.
END_TRACE_ENGINE ?=
# E6: END_TRACE_SHOTS=1 saves the end as he sees it (kill cam start, hold, ramp, end, +1 s) beside the traces.
END_TRACE_SHOTS ?=
.PHONY: end-trace
end-trace: import ## Finale E1: per-frame trace through the end of a scripted elimination at his window (marks: kill, finished, kill cam, banner) -> build/end-trace/*.jsonl, FRAME_TRACE lines (needs a display; END_TRACE_RUNS, END_TRACE_PRESET, END_TRACE_FLAGS, END_TRACE_NAME)
	mkdir -p $(END_TRACE_DIR)
	@set -e; for run in $$(seq 1 $(END_TRACE_RUNS)); do \
		name=$(END_TRACE_NAME)-$$run; \
		printf '>> end-trace %s | %s | load %s | %s other godot\n' $$name "$$(git rev-parse --short HEAD 2>/dev/null || echo remote)" "$$(cut -d' ' -f1-3 /proc/loadavg)" "$$(pgrep -c -f 'Godot_v4' || echo 0)"; \
		if [ -n "$(END_TRACE_COLD)" ]; then \
			dir=$(or $(END_TRACE_COLD_DIR),$$(sed -n 's/^config\/custom_user_dir_name="\(.*\)"/\1/p' $(END_TRACE_OVERRIDE_CFG) 2>/dev/null || true)); \
			[ -n "$$dir" ] || { echo "END_TRACE_COLD_REFUSED: no private Godot user dir here (override.cfg names none), so emptying a shader cache could only hit the shared one"; exit 3; }; \
			rm -rf "$$HOME/.local/share/$$dir/shader_cache"; echo "   cold: emptied ~/.local/share/$$dir/shader_cache, MESA_SHADER_CACHE_DISABLE=true"; \
			before=$$( (find "$$HOME/.local/share/$$dir/shader_cache" -type f 2>/dev/null || true) | wc -l); \
		fi; \
		$(if $(END_TRACE_COLD),MESA_SHADER_CACHE_DISABLE=true) timeout 300 $(GODOT) --path . --resolution $(END_TRACE_RES) $(END_TRACE_ENGINE) -- --skirmish --scripted $(END_TRACE_ARGS) \
			--announcer=voice --music=on --announcer-history=off --music-history=off \
			$(if $(END_TRACE_PRESET),--render-preset=$(END_TRACE_PRESET)) \
			--frame-trace=$(END_TRACE_DIR_ABS)/$$name.jsonl --frame-trace-after=$(END_TRACE_AFTER) $(if $(END_TRACE_SHOTS),--frame-trace-shots=$(END_TRACE_DIR_ABS)) $(END_TRACE_FLAGS) \
			> $(END_TRACE_DIR)/$$name.log 2>&1 || godot=$$?; \
		echo "   godot exited $${godot:-0}"; \
		if [ -n "$(END_TRACE_COLD)" ]; then \
			after=$$( (find "$$HOME/.local/share/$$dir/shader_cache" -type f 2>/dev/null || true) | wc -l); \
			scene=$$( (find "$$HOME/.local/share/$$dir/shader_cache/SceneShaderGLES3" -type f 2>/dev/null || true) | wc -l); \
			echo "END_TRACE_COLD godot_cache_files_before=$$before after=$$after scene_shader_files=$$scene mesa_cache=disabled" | tee -a $(END_TRACE_DIR)/$$name.log; \
		fi; \
		grep -E '^(FRAME_TRACE|KILL_CAM|RENDER_PRESET)|SCRIPT ERROR' $(END_TRACE_DIR)/$$name.log || true; \
		echo "   engine errors: $$(grep -cE '^ERROR|SCRIPT ERROR' $(END_TRACE_DIR)/$$name.log || true)"; \
		grep -q FRAME_TRACE_DONE $(END_TRACE_DIR)/$$name.log || { echo "end-trace $$name did not finish: $(END_TRACE_DIR)/$$name.log"; exit 1; }; \
		[ "$${godot:-0}" -eq 0 ] || { echo "end-trace $$name: godot exited $$godot (a trace run quits with 0)"; exit 1; }; \
		godot=0; \
	done

# Round 18 (finale E4): the class cannot come back unseen. One COLD end-trace (this worktree's own Godot shader cache
# emptied, Mesa's off: the first match after an update) with vsync OFF (builder0's hidden window is otherwise held at
# 1 fps by the compositor), printed as END_FRAME MEASURE lines, then judged ONLY where the machine can tell a compile
# from load (the round-17 rule: a named NOT JUDGED row, never a silent skip):
#   NOT JUDGED  no display (DISPLAY and WAYLAND_DISPLAY unset) | not proved cold | the match's median frame > END_FRAME_MEDIAN_MAX ms
#   FAIL        the run died, or Godot exited non-zero, with a display present (lesson 255: the exit code is read)
# COLD, proved: end-trace's END_TRACE_COLD empties THIS worktree's own Godot cache (~/.local/share/<override.cfg
# custom_user_dir_name>/shader_cache; never the shared "Tank Squad" one) and runs Godot with MESA_SHADER_CACHE_DISABLE=true,
# then prints `END_TRACE_COLD godot_cache_files_before=0 after=N scene_shader_files=M`: Godot writes a SceneShaderGLES3
# file only for a variant it compiled, so M > 0 from an emptied folder is the compiles of THIS run. Unproved = NOT JUDGED.
#   FAIL        the largest frame past load (tick >= 15) or within 1 s of the final kill > END_FRAME_MAX_MS
# Calibrated at 04911931/91208026 (sumps seed 1, cold): with the warm-up the worst frame past load was 258-404 ms (laptop
# UHD 620, builder0 Iris Xe); without it 1.5-2.8 s. ~90 s on builder0 (one run plus its cold first frame).
END_FRAME_MAX_MS ?= 1000
END_FRAME_MEDIAN_MAX ?= 150
.PHONY: end-frame-measure
end-frame-measure: import ## Finale E4: one cold scripted elimination with vsync off -> END_FRAME MEASURE lines; FAIL when a frame past load or at the final kill exceeds END_FRAME_MAX_MS, or when the run dies with a display present; NOT JUDGED (named) where the machine cannot judge: no display, or no private user dir (needs override.cfg's custom_user_dir_name)
	@rm -f $(BUILD_DIR)/end-trace/end-frame-1.jsonl $(BUILD_DIR)/end-trace/end-frame-1.log
	@mkdir -p $(BUILD_DIR)/end-trace
	@# Lesson 255: the run's exit code is READ, never swallowed: end-trace exits non-zero when Godot does or the trace
	@# did not finish, and that status reaches the verdict below (a dead run with a display is a FAIL, not "no trace").
	@s=0; $(MAKE) --no-print-directory end-trace END_TRACE_RUNS=1 END_TRACE_COLD=1 END_TRACE_ENGINE=--disable-vsync \
		END_TRACE_NAME=end-frame > $(BUILD_DIR)/end-trace/end-frame-make.log 2>&1 || s=$$?; \
		grep -E '^(>>|FRAME_TRACE (match|summary)|   |end-trace|END_TRACE)' $(BUILD_DIR)/end-trace/end-frame-make.log || true; \
		echo "$$s" > $(BUILD_DIR)/end-trace/end-frame-status
	@$(PYTHON) -c "import json,sys,os;\
p='$(BUILD_DIR)/end-trace/end-frame-1.jsonl';\
rows=[json.loads(l) for l in open(p)] if os.path.exists(p) else [];\
s=([r['summary'] for r in rows if 'summary' in r] or [None])[0];\
nj=lambda why: (print('END_FRAME NOT JUDGED: '+why), sys.exit(0));\
fail=lambda why: (print('END_FRAME JUDGED FAIL: '+why), sys.exit(1));\
status=open('$(BUILD_DIR)/end-trace/end-frame-status').read().strip();\
shown=os.environ.get('DISPLAY','') or os.environ.get('WAYLAND_DISPLAY','');\
s is None and not shown and nj('no display (DISPLAY and WAYLAND_DISPLAY unset): nothing can be drawn here');\
s is None and 'END_TRACE_COLD_REFUSED' in open('$(BUILD_DIR)/end-trace/end-frame-make.log').read() and nj('this checkout has no private Godot user dir (override.cfg custom_user_dir_name), so a cold run cannot be made or proved here');\
s is None and fail('the run died with a display present (%s): end-trace exited %s -- $(BUILD_DIR)/end-trace/end-frame-make.log' % (shown, status));\
status != '0' and fail('end-trace exited %s although a trace was written -- $(BUILD_DIR)/end-trace/end-frame-make.log' % status);\
import re;\
cold=re.findall(r'END_TRACE_COLD godot_cache_files_before=(\d+) after=(\d+) scene_shader_files=(\d+)', open('$(BUILD_DIR)/end-trace/end-frame-1.log').read());\
(not cold or int(cold[-1][0]) != 0 or int(cold[-1][2]) == 0) and nj('the run was not proved cold (needs END_TRACE_COLD godot_cache_files_before=0 and scene_shader_files > 0: %s)' % (cold[-1] if cold else 'no line'));\
print('END_FRAME COLD godot_cache_files_before=%s after=%s scene_shader_files=%s (the scene shaders this run compiled)' % cold[-1]);\
print('END_FRAME MEASURE match_median_ms=%.0f match_max_ms=%.0f at_tick=%d final_kill_max_ms=%.0f (cold cache, vsync off, sumps seed 1)' % (s['match_median_ms'], s['match_max_ms'], s['match_max_tick'], s['max_ms']));\
s['match_median_ms'] > $(END_FRAME_MEDIAN_MAX) and nj('the match median frame is %.0f ms (> $(END_FRAME_MEDIAN_MAX)): this machine cannot tell a compile from load right now' % s['match_median_ms']);\
bad=[k for k in ('match_max_ms','max_ms') if s[k] > $(END_FRAME_MAX_MS)];\
print('END_FRAME JUDGED ' + ('FAIL: %s above $(END_FRAME_MAX_MS) ms -- a first use compiles mid-match (make end-trace END_TRACE_COLD=1, then the marks of that frame)' % ', '.join('%s=%.0f' % (k, s[k]) for k in bad) if bad else 'PASS'));\
sys.exit(1 if bad else 0)"

# Ship's proof for end-frame-measure's verdicts (lesson 255), without a GPU run: a stub "Godot" that prints nothing and
# exits 134 must read FAIL with a display and the named NOT JUDGED without one, and a checkout with no private user dir
# its own named NOT JUDGED. The stub's cold runs empty a throwaway dir (END_TRACE_COLD_DIR), so this passes in a checkout
# without override.cfg (the main one) as well as in a worktree. (A good cold run reads PASS: run the
# target itself.) The stub answers `--import` with 0 (so the death is the TRACE run's, not the import's) and every other
# launch with 134. Each `|| true` below: the inner make is EXPECTED to exit 2 (FAIL) or 0 (NOT JUDGED); the grep after
# it is the assertion.
.PHONY: end-frame-measure-selftest
end-frame-measure-selftest: ## Finale E4: end-frame-measure's verdicts against a stub engine that dies (FAIL with a display, NOT JUDGED without)
	@mkdir -p $(BUILD_DIR)/end-trace; stub=$(CURDIR)/$(BUILD_DIR)/end-trace/stub-godot.sh; \
	printf '#!/bin/sh\ncase " $$* " in *" --import "*) exit 0;; esac\nexit 134\n' > $$stub; chmod +x $$stub; \
	out=$$(DISPLAY=:99 $(MAKE) --no-print-directory -o import end-frame-measure GODOT=$$stub END_TRACE_COLD_DIR=tank_squad_end_frame_selftest 2>&1 || true); \
	echo "$$out" | grep -q 'godot exited 134' \
		|| { echo "$$out"; echo "end-frame-measure-selftest FAILED: the stub's trace run never ran (died elsewhere)"; exit 1; }; \
	echo "$$out" | grep -q 'END_FRAME JUDGED FAIL: the run died with a display present' \
		|| { echo "$$out"; echo "end-frame-measure-selftest FAILED: a dead run with a display did not FAIL"; exit 1; }; \
	out=$$(env -u DISPLAY -u WAYLAND_DISPLAY $(MAKE) --no-print-directory -o import end-frame-measure GODOT=$$stub END_TRACE_COLD_DIR=tank_squad_end_frame_selftest 2>&1 || true); \
	echo "$$out" | grep -q 'END_FRAME NOT JUDGED: no display' \
		|| { echo "$$out"; echo "end-frame-measure-selftest FAILED: no display did not read NOT JUDGED"; exit 1; }; \
	out=$$(DISPLAY=:99 $(MAKE) --no-print-directory -o import end-frame-measure GODOT=$$stub END_TRACE_OVERRIDE_CFG=/nonexistent 2>&1 || true); \
	echo "$$out" | grep -q 'END_FRAME NOT JUDGED: this checkout has no private Godot user dir' \
		|| { echo "$$out"; echo "end-frame-measure-selftest FAILED: a checkout without override.cfg did not read the named NOT JUDGED"; exit 1; }; \
	echo "end-frame-measure-selftest passed: a trace run that exits 134 with a display = FAIL; no display = NOT JUDGED; no private user dir = NOT JUDGED (named)"

# Round 18 (finale, lent by the orchestrator): desktop-smoke's intermittent "N resources still in use at exit", by
# removal. The EXPORTED binary, exactly desktop-smoke's run (headless, its flags, the voice beside it), QUIT_LEAK_RUNS
# plain runs per arm, arms interleaved; each run's exit code is read (lesson 255) and the leak line counted.
QUIT_LEAK_RUNS ?= 6
QUIT_LEAK_ARMS ?= base music_off voice_off prefetch_off late_quit
# Also: `verbose` (the engine's --verbose: names what is still in use, when it leaks).
.PHONY: quit-leak-arms
quit-leak-arms: export-desktop ## Finale: desktop-smoke's exit-leak by removal (arms: base music_off voice_off prefetch_off late_quit; QUIT_LEAK_RUNS each) -> QUIT_LEAK table
	rsync -a --delete --exclude=.gdignore --exclude=README.md assets/announcer/clips/ $(BUILD_DIR)/desktop/voice/
	@mkdir -p $(BUILD_DIR)/quit-leak; rm -f $(BUILD_DIR)/quit-leak/*.log; \
	for k in $$(seq 1 $(QUIT_LEAK_RUNS)); do for arm in $(QUIT_LEAK_ARMS); do \
		flags="$(DESKTOP_SMOKE_FLAGS)"; engine=""; \
		case $$arm in music_off) flags="$$flags --music=off";; voice_off) flags="$$flags --announcer=text";; \
			prefetch_off) flags="$$flags --music-prefetch=off";; verbose) engine=--verbose;; late_quit) flags="$$(echo $$flags | sed 's/--hash-until=90/--hash-until=300/')";; esac; \
		s=0; timeout 300 $(BUILD_DIR)/desktop/tank_squad.x86_64 --headless $$engine -- $$flags > $(BUILD_DIR)/quit-leak/$$arm-$$k.log 2>&1 || s=$$?; \
		leak=$$(grep -cE 'resources still in use at exit' $(BUILD_DIR)/quit-leak/$$arm-$$k.log || true); \
		tick=$$(grep -oE '^SIM_HASH tick=[0-9]+' $(BUILD_DIR)/quit-leak/$$arm-$$k.log | tail -1 | cut -d= -f2); \
		echo "QUIT_LEAK run arm=$$arm k=$$k exit=$$s leak=$$leak last_tick=$${tick:-none} load=$$(cut -d' ' -f1 /proc/loadavg)"; \
	done; done; \
	for arm in $(QUIT_LEAK_ARMS); do \
		n=$$( (grep -l "resources still in use at exit" $(BUILD_DIR)/quit-leak/$$arm-*.log 2>/dev/null || true) | wc -l); \
		echo "QUIT_LEAK arm=$$arm leaked $$n of $(QUIT_LEAK_RUNS)"; \
	done
