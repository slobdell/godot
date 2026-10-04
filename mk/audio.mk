# The soundtrack and the game's sound: placeholder music, the loudness and loop contract, importing the lead's
# Suno tracks, and the match-mood signal's tests.
# Owner: feel (_agents/streams/archive/round10/feel.md); round 5 it was audio (_agents/streams/archive/round5/audio.md).

.PHONY: audition-clips mix-ab layout-ab bus-order booth-match audio-deps music-stems music-placeholders music-check music-import music-smoke audio-check audio-pytest sfx-generate sfx-layer audio-bench audio-pass weapon-sheet

MUSIC_DIR ?= assets/music
## The audio tools need numpy and scipy. Use the system Python when it has them (the laptop), else a venv inside the
## machine's own toolchain folder (builder0 has neither and no sudo): `make audio-deps` makes it once (~5 s, 220 MB).
AUDIO_VENV := .tools/audio-venv
AUDIO_PYTHON = $(shell $(PYTHON) -c "import numpy, scipy" 2>/dev/null && echo $(PYTHON) || echo $(AUDIO_VENV)/bin/python)

music-placeholders: audio-deps ## Regenerate the placeholder beds and stingers (synthesised here, CC0; the real tracks come from Suno)
	$(AUDIO_PYTHON) tools/audio/make_music_placeholders.py --out $(MUSIC_DIR)

music-check: audio-deps ## Every track against the contract in assets/music/PROMPTS.md: loudness, true peak, loop points, seams
	$(AUDIO_PYTHON) tools/audio/check_music.py $(MUSIC_DIR)

## The lead's own workflow: turn one Suno download into a bed the director can use.
music-stems: ## Split a Suno track into drums/bass/other/vocals with demucs on builder0: IN=~/Downloads/track.mp3 [OUT=folder]
	tools/audio/split_stems.sh "$(IN)" $(OUT)

music-import: audio-deps ## Import a Suno track: IN=~/Downloads/battle.mp3 STATE=battle BPM=110 [RIGHTS=...] [ID=battle_b for a second take]; stems: IN=<folder> STATE=fight LAYERS="Synth=0 Drums=0.35 Bass=0.5 FX=last_stand"
	@test -n "$(IN)" || { echo "usage: make music-import IN=<file> STATE=<state> BPM=<tempo>"; exit 2; }
	@test -n "$(STATE)" || { echo "STATE is required (garage, pre_match, lull, skirmish, battle, last_stand, victory, defeat)"; exit 2; }
	@test -n "$(BPM)" || { echo "BPM is required: the crossfade lands on a bar line"; exit 2; }
	$(AUDIO_PYTHON) tools/audio/import_music.py "$(IN)" --state $(STATE) --bpm $(BPM) --out $(MUSIC_DIR) \
		$(if $(RIGHTS),--rights "$(RIGHTS)") $(if $(LAYERS),--layers "$(LAYERS)") $(if $(FROM),--from $(FROM)) $(if $(TO),--to $(TO)) $(if $(STATES),--states $(STATES)) $(if $(ID),--id $(ID))

# The sim-baseline match again (mk/core.mk), with the soundtrack following it: the music must change with the match
# and must not change the match. Same shape as announcer-record-smoke, and the same guarantee.
## Round 6 (combat's report): the "did the music change the simulation" question is differential, so it is answered
## against a control run of the same match without the music, not against the shared baseline file, which moves on
## purpose whenever the simulation changes and then accused the soundtrack of breaking it.
## **VERIFIED BY EXPERIMENT, round 9 (feel), because a lesson said otherwise for two rounds.** orchestration lesson
## 65 and feel's round-9 brief both still described this target as asking the ABSOLUTE question against the shared
## baseline file. It does not, and has not since round 6. Proved both ways on the laptop, 2026-09-20:
##   * with a DELIBERATELY STALE baseline line for this machine's glibc, `sim-baseline` goes red (so the file is
##     live here) and this target still PASSES -- it never opens the file;
##   * with the instrumented run's seed skewed so the two hashes must differ, this target FAILS and names the
##     subsystem -- so the comparison is live and can go red, not merely silent.
## A guard nobody has seen fail is not known to work (Invariant 0), which is why both halves were run.
music-smoke: import ## A real headless match with the music on: the beds change, and the simulation hash does not
	@mkdir -p $(BUILD_DIR)/audio
	@expected=$$($(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination \
		--green-doctrine=res://doctrines/anvil_hammer.json --rust-doctrine=res://doctrines/individuals.json \
		--time-limit=40 --seed=3 2>/dev/null | grep MATCH_RESULT | $(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"); \
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination \
		--green-doctrine=res://doctrines/anvil_hammer.json --rust-doctrine=res://doctrines/individuals.json \
		--time-limit=40 --seed=3 --music=on 2>/dev/null > $(BUILD_DIR)/audio/music-smoke.log; \
	grep -q '^MUSIC on:' $(BUILD_DIR)/audio/music-smoke.log \
		|| { echo "music-smoke FAILED: the director never attached"; grep -i music $(BUILD_DIR)/audio/music-smoke.log; exit 1; }; \
	beds=$$(grep -c '^MUSIC_TRACK' $(BUILD_DIR)/audio/music-smoke.log); \
	distinct=$$(grep '^MUSIC_TRACK' $(BUILD_DIR)/audio/music-smoke.log | sed 's/.*track=//;s/ .*//' | sort -u | wc -l); \
	layers=$$(grep -c '^MUSIC_LAYERS' $(BUILD_DIR)/audio/music-smoke.log || true); \
	[ "$$distinct" -ge 2 ] || [ "$$layers" -ge 1 ] \
		|| { echo "music-smoke FAILED: the soundtrack never changed ($$beds cues, $$distinct beds, $$layers layer changes)"; \
		     grep '^MUSIC' $(BUILD_DIR)/audio/music-smoke.log; exit 1; }; \
	actual=$$(grep MATCH_RESULT $(BUILD_DIR)/audio/music-smoke.log | $(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"); \
	if [ -z "$$expected" ] || [ "$$actual" != "$$expected" ]; then echo "music-smoke FAILED: the soundtrack changed the simulation ($$actual, without it $$expected)"; exit 1; fi; \
	echo "music-smoke passed: $$beds bed changes across $$distinct beds, $$layers layer changes, hash $$actual$${expected:+ (matches the same match without the music)}"; \
	grep -E '^MUSIC_(TRACK|LAYERS)' $(BUILD_DIR)/audio/music-smoke.log | sed 's/^/  /'
	@# Round 13 (G2): the garage plays its own bed, and FIGHT hands it to the match's opening, in one process. The
	@# loop's quit leaves the engine's exit-time "resources still in use" line on some runs (seen on 1dae1959 once in two):
	@# a shutdown artefact of quitting mid-scene, not an error in the run, so it alone is not counted.
	timeout 300 $(GODOT) --headless --path . -- --garage --garage-scratch --garage-autofight=3 --music=on --enemy=cpu:siege \
		--seed=4 --army-loop-time=12 --army-loop-delay=0.5 --army-loop-auto=quit > $(BUILD_DIR)/audio/music-garage-smoke.log 2>&1 || true
	@$(PYTHON) -c "import re,sys; log=open('$(BUILD_DIR)/audio/music-garage-smoke.log').read(); \
		cues=re.findall(r'^MUSIC_TRACK state=(\S+) track=(\S+)', log, re.M); fight=log.find('GARAGE_FIGHT'); \
		after=[c for c in re.finditer(r'^MUSIC_TRACK state=(\S+)', log, re.M) if c.start() > fight]; \
		errors=[l for l in log.splitlines() if 'ERROR' in l and 'resources still in use at exit' not in l]; \
		ok=bool(cues) and cues[0][0]=='garage' and fight>0 and bool(after) and after[0].group(1)=='pre_match' and not errors; \
		print('music-smoke (garage) %s: %s%s' % ('passed' if ok else 'FAILED', ' -> '.join('%s:%s' % c for c in cues) or 'no cues', \
			''.join('\n  ' + e for e in errors))); \
		sys.exit(0 if ok else 1)"

## Round 5 X1-X2: sound effects from ElevenLabs, layered under the synthesised transients.
## Lead gate 1 (approved round 5): pilot first (PILOT=1), the lead listens, then the batch. Every real run is ledgered.
SFX_VENV_PYTHON ?= $(if $(wildcard $(HOME)/.venvs/tank-squad-audio/bin/python),$(HOME)/.venvs/tank-squad-audio/bin/python,$(PYTHON))

sfx-generate: ## ElevenLabs sound-effect masters: DRY_RUN by default; APPROVED=1 spends credits [PILOT=1] [ONLY=tank_boom,mg_loop]
	@if [ "$(APPROVED)" = "1" ]; then \
		$(SFX_VENV_PYTHON) -c "import elevenlabs" 2>/dev/null || { echo "pip install elevenlabs==2.24.0 (tools/announcer/requirements.txt), or a venv at ~/.venvs/tank-squad-audio"; exit 1; }; \
		$(SFX_VENV_PYTHON) tools/audio/sfx_generate.py --approved $(if $(PILOT),--pilot) $(if $(ONLY),--only $(ONLY)); \
	else \
		$(PYTHON) tools/audio/sfx_generate.py --dry-run $(if $(PILOT),--pilot) $(if $(ONLY),--only $(ONLY)); \
		echo; echo "(dry run: nothing was sent; APPROVED=1 spends credits)"; \
	fi

sfx-layer: audio-deps ## Masters -> the shipped takes in assets/audio/layered + game/theme/audio/sfx_layers.gd (free; needs the masters) [ONLY=...]
	$(AUDIO_PYTHON) tools/audio/sfx_layer.py $(if $(ONLY),--only $(ONLY)) --report $(BUILD_DIR)/audio/sfx_layer.json
	$(GODOT) --headless --path . --import >/dev/null 2>&1 || true
	@# A new loop's .import only exists after that first import, with Godot's compressed default: set it to PCM and
	@# import again, or the loop plays a fifth of itself (orientation trip-up 74).
	$(AUDIO_PYTHON) -c "import sys; sys.path.insert(0, 'tools/audio'); import sfx_layer; [print('loop import set to PCM:', p.name) for p in sfx_layer.keep_loops_uncompressed(sfx_layer.LAYERED, sfx_layer.loop_sounds(sfx_layer.sfx_generate.load_sources()))]"
	$(GODOT) --headless --path . --import >/dev/null 2>&1 || true

## M1 (fx_tricks.md): booth, music and crowd <= 0.3 ms of script per frame. perf-scene runs --mute, so it cannot see
## audio; this times each audio system under a battle busier than a real one. Informational, not in check.
audio-bench: import ## Per-frame script cost of every audio system at 60 vehicles, headless → build/audio/bench.json
	@mkdir -p $(BUILD_DIR)/audio
	$(GODOT) --headless --path . --script res://game/audio/audio_bench.gd -- $(CURDIR)/$(BUILD_DIR)/audio/bench.json 2>&1 \
		| tee $(BUILD_DIR)/audio/bench.log | grep -E '^AUDIO_BENCH|SCRIPT ERROR|^ERROR' || true
	@grep -q AUDIO_BENCH_DONE $(BUILD_DIR)/audio/bench.log

## X6: listen to it whole. A CPU-vs-CPU match at 30+ a side with everything on, recorded from the Master bus, then
## measured (loudness, true peak, clipping) and turned into an MP3 and a spectrogram to look at. Needs a display
## (FxWorld, the sound effects, only exists with one): make remote T=audio-pass.
PASS_SECONDS ?= 150
## Who fights in the pass. Faction matters to the ear: the Syndicate's weapons are the energy family (SfxWeapons).
PASS_FACTION ?= gangs
PASS_ENEMY ?= law
## Vsync off (feel, round 6): on builder0 a vsync'd window on the idle desktop presents at a crawl, and the game ran ~10x
## slower than the wall-clock recording (8 s of match in 90 s of audio, round 5 and 6; muted just the same, so not the
## audio). With vsync off, FrameTarget's frame cap still paces it: 25.6 s of match in a 30 s pass.
PASS_GODOT_FLAGS ?= --disable-vsync
PASS_SEED ?= 3
PASS_BUDGET ?= 6500
audio-pass: import audio-deps ## The whole mix of a 30-a-side match → build/audio/pass.{wav,mp3,png,json} (needs a display; PASS_SECONDS=150, ARENA=pit, PASS_FACTION=syndicate PASS_ENEMY=condemned, PASS_FLAGS=--audio-solo=music)
	@mkdir -p $(BUILD_DIR)/audio
	rm -f $(BUILD_DIR)/audio/pass.*.wav
	timeout $$(( $(PASS_SECONDS) + 300 )) $(GODOT) --path . --resolution 1280x720 $(PASS_GODOT_FLAGS) -- --skirmish --cinematic --player=cpu --enemy=cpu \
		--seed=$(PASS_SEED) --budget=$(PASS_BUDGET) --no-pick-faction --player-faction=$(PASS_FACTION) --enemy-faction=$(PASS_ENEMY) $(if $(ARENA),--arena=$(ARENA)) $(PASS_FLAGS) --announcer=voice --music=on --announcer-history=off \
		--audio-record=$(CURDIR)/$(BUILD_DIR)/audio/pass.wav --audio-record-seconds=$(PASS_SECONDS) 2>&1 \
		| tee $(BUILD_DIR)/audio/pass.log | grep -E '^AUDIO_RECORD|SCRIPT ERROR' || true
	@grep -q 'AUDIO_RECORDED .*error=0' $(BUILD_DIR)/audio/pass.log || { echo "audio-pass FAILED: no recording"; exit 1; }
	$(AUDIO_PYTHON) tools/audio/pass_report.py $(BUILD_DIR)/audio/pass.wav $(BUILD_DIR)/audio/pass.log
	@# Round 17 G1: with PASS_FLAGS=--audio-taps, what the limiter and the ducks took, moment by moment.
	@if [ -f $(BUILD_DIR)/audio/pass.world_in.wav ]; then $(AUDIO_PYTHON) tools/audio/pass_taps.py $(BUILD_DIR)/audio/pass.wav; fi

## Round 17 G1 (guns): every weapon and impact sound measured twice - as the file we ship, and as it reaches the
## Master bus alone through the game's own voices and buses at the overhead camera's distances, with the limiters,
## the distance filter and the trim taken out one at a time so each stage's cost is a difference of two recordings.
## Headless (the Dummy driver mixes in real time), ~20 min for every sound; ONLY= for a few.
weapon-sheet: import audio-deps ## G1: the weapon sheet, source vs what reaches the master → build/audio/weapon_sheet.{md,json} [ONLY=tank_boom,mg_round]
	rm -rf $(BUILD_DIR)/audio/arrivals && mkdir -p $(BUILD_DIR)/audio/arrivals
	$(GODOT) --headless --path . --script res://game/audio/weapon_probe.gd -- $(CURDIR)/$(BUILD_DIR)/audio/arrivals $(ONLY) 2>&1 \
		| tee $(BUILD_DIR)/audio/weapon_probe.log | grep -E '^WEAPON_PROBE (driver|missing)|SCRIPT ERROR' || true
	@grep -q WEAPON_PROBE_DONE $(BUILD_DIR)/audio/weapon_probe.log || { echo "weapon-sheet FAILED: the probe did not finish"; exit 1; }
	$(AUDIO_PYTHON) tools/audio/weapon_sheet.py --arrivals $(BUILD_DIR)/audio/arrivals $(if $(ONLY),--only $(ONLY)) > /dev/null
	@echo "weapon-sheet: $(BUILD_DIR)/audio/weapon_sheet.md"

## Round 17 G4: the audition page's fight clips. The same match recorded once per ARM through the game's mix, then the
## same window cut from each (tools/audio/audition_clips.py; loudness stated, not matched away). An arm is
## name@flag+flag ("+" joins flags): today@--mix=launch+--sfx-direction=all:0 is the game before round 17. Defaults:
## his match (the Sumps, Law v Condemned, seed 92721, budget 4600). Needs a display: make remote T=audition-clips.
AUDITION ?= today@--mix=launch+--sfx-direction=all:0 \
	tank_0@--sfx-direction=tank_boom:0 tank_a@--sfx-direction=tank_boom:a tank_b@--sfx-direction=tank_boom:b tank_c@--sfx-direction=tank_boom:c \
	25mm_0@--sfx-direction=autocannon_shot:0 25mm_b@--sfx-direction=autocannon_shot:b 25mm_c@--sfx-direction=autocannon_shot:c \
	mg_0@--sfx-direction=mg_loop:0 mg_b@--sfx-direction=mg_loop:b kill_0@--sfx-direction=explosion_big:0 kill_b@--sfx-direction=explosion_big:b \
	duck_launch@--booth-duck=launch+--audio-taps duck_mid@--booth-duck=mid+--audio-taps duck_new@--booth-duck=new+--audio-taps
AUDITION_SECONDS ?= 75
AUDITION_MATCH ?= --arena=sumps --seed=92721 --budget=4600 --player-faction=law --enemy-faction=condemned
audition-clips: import audio-deps ## G4: one real-fight recording per arm -> build/audio/audition/ (AUDITION="name@--flag+--flag ...")
	@mkdir -p $(BUILD_DIR)/audio/audition
	@for spec in $(AUDITION); do \
		name=$${spec%%@*}; flags=$$(echo "$${spec#*@}" | tr '+' ' '); echo ">> audition: $$name ($$flags)"; \
		timeout $$(( $(AUDITION_SECONDS) + 300 )) $(GODOT) --path . --resolution 1280x720 $(PASS_GODOT_FLAGS) -- --skirmish --cinematic --player=cpu --enemy=cpu \
			--no-pick-faction $(AUDITION_MATCH) $$flags --announcer=voice --music=on --announcer-history=off \
			--audio-record=$(CURDIR)/$(BUILD_DIR)/audio/audition/fight_$$name.wav --audio-record-seconds=$(AUDITION_SECONDS) \
			> $(BUILD_DIR)/audio/audition/fight_$$name.log 2>&1 || true; \
		grep -q 'AUDIO_RECORDED .*error=0' $(BUILD_DIR)/audio/audition/fight_$$name.log || { echo "audition-clips FAILED: no recording for $$name"; exit 1; }; \
	done
	$(AUDIO_PYTHON) tools/audio/audition_clips.py $(BUILD_DIR)/audio/audition --reference fight_today.wav

## Round 17 G2: before and after on ONE tree and ONE match: each MATCH in AB_MATCHES played twice, the launch mix and
## sound (--mix=launch --sfx-direction=all:0) and the game as it is now, with the bus taps; the loudness, the stages,
## the booth and the music for each -> build/audio/ab/<match>_<arm>.*. Needs a display: make remote T=mix-ab.
AB_MATCHES ?= sumps@--arena=sumps+--seed=92721+--budget=4600+--player-faction=law+--enemy-faction=condemned \
	foundry@--arena=foundry+--seed=3+--budget=6500+--player-faction=gangs+--enemy-faction=law
AB_SECONDS ?= 150
mix-ab: import audio-deps ## G2: the launch mix vs now, same tree, same matches, with the taps -> build/audio/ab/
	@rm -rf $(BUILD_DIR)/audio/ab && mkdir -p $(BUILD_DIR)/audio/ab
	@for match in $(AB_MATCHES); do \
		mname=$${match%%@*}; mflags=$$(echo "$${match#*@}" | tr '+' ' '); \
		for arm in launch now; do \
			armflags=$$( [ $$arm = launch ] && echo "--mix=launch --sfx-direction=all:0" || echo ""); \
			out=$(CURDIR)/$(BUILD_DIR)/audio/ab/$${mname}_$$arm.wav; echo ">> mix-ab: $$mname $$arm"; \
			timeout $$(( $(AB_SECONDS) + 300 )) $(GODOT) --path . --resolution 1280x720 $(PASS_GODOT_FLAGS) -- --skirmish --cinematic --player=cpu --enemy=cpu \
				--no-pick-faction $$mflags $$armflags --audio-taps --announcer=voice --music=on --announcer-history=off --announcer-seed=7 \
				--audio-record=$$out --audio-record-seconds=$(AB_SECONDS) > $${out%.wav}.log 2>&1 || true; \
			grep -q 'AUDIO_RECORDED .*error=0' $${out%.wav}.log || { echo "mix-ab FAILED: no recording for $$mname $$arm"; exit 1; }; \
			$(AUDIO_PYTHON) tools/audio/pass_report.py $$out $${out%.wav}.log | head -2; \
			$(AUDIO_PYTHON) tools/audio/pass_taps.py $$out; \
		done; \
	done

## Round 17: res://default_bus_layout.tres must change nothing native. His match, the declared layout vs
## --no-bus-layout (buses built at runtime as before), interleaved LAYOUT_RUNS times each, with the taps: the booth, the
## World bus around the booth's sidechain, the music, the crowd. -> build/audio/layout_ab/. Needs a display.
LAYOUT_RUNS ?= 2
LAYOUT_SECONDS ?= 90
layout-ab: import audio-deps ## The bus layout's native equality: declared vs runtime buses, same match, taps -> build/audio/layout_ab/
	@rm -rf $(BUILD_DIR)/audio/layout_ab && mkdir -p $(BUILD_DIR)/audio/layout_ab
	@for n in $$(seq 1 $(LAYOUT_RUNS)); do for arm in runtime declared; do \
		armflags=$$( [ $$arm = runtime ] && echo "--no-bus-layout" || echo ""); \
		out=$(CURDIR)/$(BUILD_DIR)/audio/layout_ab/$${arm}_$$n.wav; echo ">> layout-ab: $$arm run $$n"; \
		timeout $$(( $(LAYOUT_SECONDS) + 300 )) $(GODOT) --path . --resolution 1280x720 $(PASS_GODOT_FLAGS) -- --skirmish --cinematic --player=cpu --enemy=cpu \
			--no-pick-faction $(AUDITION_MATCH) $$armflags --audio-taps --crowd-meter --announcer=voice --music=on --announcer-history=off --announcer-seed=7 \
			--audio-record=$$out --audio-record-seconds=$(LAYOUT_SECONDS) > $${out%.wav}.log 2>&1 || true; \
		grep -q 'AUDIO_RECORDED .*error=0' $${out%.wav}.log || { echo "layout-ab FAILED: no recording for $$arm $$n"; exit 1; }; \
		grep -E '^AUDIO_BUSES' $${out%.wav}.log; \
	done; done
	$(AUDIO_PYTHON) tools/audio/layout_ab.py $(BUILD_DIR)/audio/layout_ab

## Round 17: the order the game builds its buses in, windowed (headless has no FxWorld and builds them differently).
## BUS_ORDER_TREE is a project folder (a scratch copy of any commit: git archive <sha> | tar -x -C .tree); the probe
## (tools/audio/bus_order_probe.gd) is injected there as an autoload and prints BUS_ORDER once his match has run.
BUS_ORDER_TREE ?= .
BUS_ORDER_FLAGS ?=
bus-order: ## Ground truth for the bus order, windowed: BUS_ORDER_TREE=<project dir> [BUS_ORDER_FLAGS=--no-bus-layout] (needs a display)
	cp tools/audio/bus_order_probe.gd $(BUS_ORDER_TREE)/bus_order_probe.gd
	grep -q 'BusOrderProbe' $(BUS_ORDER_TREE)/project.godot || printf '\n[autoload]\n\nBusOrderProbe="*res://bus_order_probe.gd"\n' >> $(BUS_ORDER_TREE)/project.godot
	$(GODOT) --headless --path $(BUS_ORDER_TREE) --import > /dev/null 2>&1 || true
	timeout 240 $(GODOT) --path $(BUS_ORDER_TREE) --resolution 1280x720 $(PASS_GODOT_FLAGS) -- --skirmish --cinematic --player=cpu --enemy=cpu \
		--no-pick-faction $(AUDITION_MATCH) $(BUS_ORDER_FLAGS) --announcer=voice --music=on --announcer-history=off 2>&1 | grep -E '^BUS_(ORDER|LAYOUT_CHANGED)' | tee $(BUILD_DIR)/bus_order.txt

## Round 17: the acceptance test for the booth's duck (the orchestrator's definition): the lead picks a setting BY EAR
## from the page's clips, and the shipped build is right when it reproduces the clip of that setting - booth over the
## battle (median and busiest tenth) on the same window of his match, the shipped DEFAULT vs the page's clip, equal
## within the run-to-run spread. BOOTH_MATCH_REF is the page's recording of the setting the build ships (MID).
## Booth seeds (--announcer-seed): both arms speak the SAME lines per seed (the booth is not seeded by the match:
## two runs of one match otherwise speak different lines, and booth-over-battle moves with them); three seeds give
## the spread.
BOOTH_MATCH_SEEDS ?= 7 8 9
BOOTH_MATCH_REF ?= $(BUILD_DIR)/audio/audition/fight_duck_mid.wav
## BOOTH_MATCH_REF_TREE=<project dir> (a git-archive copy of the page's tree) runs the reference LIVE, interleaved with
## the shipped build in the same session (two runs of one seed in different sessions differ by a few dB on this ratio).
BOOTH_MATCH_REF_TREE ?=
BOOTH_MATCH_REF_FLAGS ?= --booth-duck=mid
booth-match: import audio-deps ## The shipped booth duck reproduces the page's clip of it: default build vs the page's tree (BOOTH_MATCH_REF_TREE) or a stored clip, same match (needs a display)
	@rm -rf $(BUILD_DIR)/audio/booth_match && mkdir -p $(BUILD_DIR)/audio/booth_match
	@$(if $(BOOTH_MATCH_REF_TREE),$(GODOT) --headless --path $(BOOTH_MATCH_REF_TREE) --import > /dev/null 2>&1 || true)
	@for n in $(BOOTH_MATCH_SEEDS); do for arm in $(if $(BOOTH_MATCH_REF_TREE),ref) shipped; do \
		tree=$$( [ $$arm = ref ] && echo "$(BOOTH_MATCH_REF_TREE)" || echo "."); flags=$$( [ $$arm = ref ] && echo "$(BOOTH_MATCH_REF_FLAGS)" || echo ""); \
		out=$(CURDIR)/$(BUILD_DIR)/audio/booth_match/$${arm}_$$n.wav; echo ">> booth-match: $$arm run $$n"; \
		timeout $$(( $(AUDITION_SECONDS) + 300 )) $(GODOT) --path $$tree --resolution 1280x720 $(PASS_GODOT_FLAGS) -- --skirmish --cinematic --player=cpu --enemy=cpu \
			--no-pick-faction $(AUDITION_MATCH) $$flags --audio-taps --announcer=voice --music=on --announcer-history=off --announcer-seed=$$n \
			--audio-record=$$out --audio-record-seconds=$(AUDITION_SECONDS) > $${out%.wav}.log 2>&1 || true; \
		grep -q 'AUDIO_RECORDED .*error=0' $${out%.wav}.log || { echo "booth-match FAILED: no recording, $$arm seed $$n"; exit 1; }; \
	done; done
	$(AUDIO_PYTHON) tools/audio/booth_match.py $(if $(BOOTH_MATCH_REF_TREE),--live,$(BOOTH_MATCH_REF)) $(BUILD_DIR)/audio/booth_match

audio-deps: ## numpy and scipy for the audio tools: nothing when the system Python has them, else .tools/audio-venv
	@if $(PYTHON) -c "import numpy, scipy" 2>/dev/null; then true; \
	elif [ -x $(AUDIO_VENV)/bin/python ] && $(AUDIO_VENV)/bin/python -c "import numpy, scipy" 2>/dev/null; then true; \
	else echo ">> audio-deps: creating $(AUDIO_VENV)"; $(PYTHON) -m venv $(AUDIO_VENV) \
		&& $(AUDIO_VENV)/bin/pip install -q -r tools/audio/requirements.txt; fi

audio-pytest: audio-deps ## The audio tools' Python tests (music contract, the sound-effect pipeline against a mock client)
	$(AUDIO_PYTHON) -m unittest discover -s tools/audio -p 'test_*.py'

audio-check: audio-pytest music-check music-smoke ## Everything the audio stream verifies headless beyond the announcer's own checks
	@echo "audio-check passed"

## Feel (round 6): the lead found "the audio is defaulted to off". The player's own way in (title -> SKIRMISH -> faction
## menu -> FIGHT, through real clicks: control's shell-playtest driver) with NO audio flags must come up with the booth
## speaking and the music on. Needs a display (make remote T=audio-launch-smoke); not in check, which is headless.
AUDIO_LAUNCH_DIR := $(BUILD_DIR)/audio-launch
audio-launch-smoke: import ## A player's launch with no audio flags gets the announcer's voice and the music (needs a display)
	rm -rf $(AUDIO_LAUNCH_DIR) && mkdir -p $(AUDIO_LAUNCH_DIR)
	timeout 360 $(GODOT) --path . --resolution 1920x1080 -- --title --hints=fresh --shell-playtest=$(CURDIR)/$(AUDIO_LAUNCH_DIR) 2>&1 \
		| tee $(AUDIO_LAUNCH_DIR)/run.log | grep -E 'ANNOUNCER_BOOTH|^MUSIC on|SHELL_PLAYTEST_DONE' || true
	@grep -q 'ANNOUNCER_BOOTH mode=voice' $(AUDIO_LAUNCH_DIR)/run.log || { echo "audio-launch-smoke FAILED: no speaking booth in a flagless launch"; exit 1; }
	@grep -q '^MUSIC on' $(AUDIO_LAUNCH_DIR)/run.log || { echo "audio-launch-smoke FAILED: no music in a flagless launch"; exit 1; }
	@! awk '/TITLE_START/{exit} /ANNOUNCER_BOOTH/{found=1} END{exit !found}' $(AUDIO_LAUNCH_DIR)/run.log 		|| { echo "audio-launch-smoke FAILED: the title's backdrop fight got a booth"; exit 1; }
	@# Round 16 (play P4): the menu's music carries through the loader into the match: carried playing, adopted playing,
	@# one director (one "MUSIC on" after the title), and the adopted bed is the carried one.
	@$(PYTHON) -c "import re,sys; log=open('$(AUDIO_LAUNCH_DIR)/run.log').read(); log=log[log.find('TITLE_START'):]; \
		c=re.search(r'^MUSIC_CARRY carried track=(\S+) playing=true', log, re.M); a=re.search(r'^MUSIC_CARRY adopted track=(\S+) playing=true', log, re.M); \
		ons=len(re.findall(r'^MUSIC on', log, re.M)); ok=bool(c and a and c.group(1)==a.group(1) and ons==1); \
		print('audio-launch-smoke (music through the loader) %s: carried %s, adopted %s, directors %d' % ('passed' if ok else 'FAILED', c and c.group(1), a and a.group(1), ons)); sys.exit(0 if ok else 1)"
	@# Round 13 (G2): the title's GARAGE, by taps and with no audio flags (tests/garage/garage_tour.gd): the garage's bed,
	@# then the match's opening after FIGHT.
	timeout 400 $(GODOT) --path . --resolution 1920x1080 --script res://tests/garage/garage_tour.gd -- --tour-fresh \
		--tour-out=$(CURDIR)/$(AUDIO_LAUNCH_DIR)/garage --tour-match=15 > $(AUDIO_LAUNCH_DIR)/garage.log 2>&1 || true
	@grep -E '^(MUSIC_TRACK|MUSIC on|GARAGE_FIGHT|TOUR_DONE)' $(AUDIO_LAUNCH_DIR)/garage.log | sed 's/^/  /'
	@$(PYTHON) -c "import re,sys; log=open('$(AUDIO_LAUNCH_DIR)/garage.log').read(); fight=log.find('GARAGE_FIGHT'); \
		states=[(m.start(), m.group(1)) for m in re.finditer(r'^MUSIC_TRACK state=(\S+)', log, re.M)]; \
		before=[s for at, s in states if at < fight]; after=[s for at, s in states if at > fight]; \
		ok=fight > 0 and before[:1]==['garage'] and after[:1]==['pre_match'] and 'ANNOUNCER_BOOTH mode=voice' in log; \
		print('audio-launch-smoke (garage) %s: before FIGHT %s, after %s' % ('passed' if ok else 'FAILED', before, after)); sys.exit(0 if ok else 1)"
	@echo "audio-launch-smoke passed: a flagless player launch has the announcer's voice and the music"
