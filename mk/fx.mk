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

facing-audit: import ## Every faction unit side-on with a red arrow along its engine forward (-Z): catches models that drive backwards → build/facing/<unit>.png (needs a display; UNITS=a,b TURRET=deg)
	rm -rf $(BUILD_DIR)/facing && mkdir -p $(BUILD_DIR)/facing
	timeout 300 $(GODOT) --path . --resolution 960x540 --script res://game/theme/gallery/facing_audit.gd -- \
		--facing-dir=$(CURDIR)/$(BUILD_DIR)/facing $(if $(UNITS),--facing-units=$(UNITS)) $(if $(TURRET),--facing-turret=$(TURRET)) 2>&1 | grep -E 'FACING_AUDIT|SCRIPT ERROR|SHADER ERROR' || true
	@grep -q . $(BUILD_DIR)/facing/*.png 2>/dev/null || { echo "facing-audit FAILED: no images"; exit 1; }
