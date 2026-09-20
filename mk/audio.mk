# The soundtrack and the game's sound: placeholder music, the loudness and loop contract, importing the lead's
# Suno tracks, and the match-mood signal's tests.
# Owner: feel (_agents/streams/feel.md); round 5 it was audio (_agents/streams/archive/round5/audio.md).

.PHONY: audio-deps music-stems music-placeholders music-check music-import music-smoke audio-check audio-pytest sfx-generate sfx-layer audio-bench audio-pass

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

music-import: audio-deps ## Import a Suno track: IN=~/Downloads/battle.mp3 STATE=battle BPM=110 [RIGHTS=...]; stems: IN=<folder> STATE=fight LAYERS="Synth=0 Drums=0.35 Bass=0.5 FX=last_stand"
	@test -n "$(IN)" || { echo "usage: make music-import IN=<file> STATE=<state> BPM=<tempo>"; exit 2; }
	@test -n "$(STATE)" || { echo "STATE is required (garage, pre_match, lull, skirmish, battle, last_stand, victory, defeat)"; exit 2; }
	@test -n "$(BPM)" || { echo "BPM is required: the crossfade lands on a bar line"; exit 2; }
	$(AUDIO_PYTHON) tools/audio/import_music.py "$(IN)" --state $(STATE) --bpm $(BPM) --out $(MUSIC_DIR) \
		$(if $(RIGHTS),--rights "$(RIGHTS)") $(if $(LAYERS),--layers "$(LAYERS)") $(if $(FROM),--from $(FROM)) $(if $(TO),--to $(TO)) $(if $(STATES),--states $(STATES))

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
audio-pass: import audio-deps ## The whole mix of a 30-a-side match → build/audio/pass.{wav,mp3,png,json} (needs a display; PASS_SECONDS=150, ARENA=pit, PASS_FACTION=syndicate PASS_ENEMY=condemned, PASS_FLAGS=--audio-solo=music)
	@mkdir -p $(BUILD_DIR)/audio
	timeout $$(( $(PASS_SECONDS) + 300 )) $(GODOT) --path . --resolution 1280x720 $(PASS_GODOT_FLAGS) -- --skirmish --cinematic --player=cpu --enemy=cpu \
		--seed=3 --budget=6500 --no-pick-faction --player-faction=$(PASS_FACTION) --enemy-faction=$(PASS_ENEMY) $(if $(ARENA),--arena=$(ARENA)) $(PASS_FLAGS) --announcer=voice --music=on --announcer-history=off \
		--audio-record=$(CURDIR)/$(BUILD_DIR)/audio/pass.wav --audio-record-seconds=$(PASS_SECONDS) 2>&1 \
		| tee $(BUILD_DIR)/audio/pass.log | grep -E '^AUDIO_RECORD|SCRIPT ERROR' || true
	@grep -q 'AUDIO_RECORDED .*error=0' $(BUILD_DIR)/audio/pass.log || { echo "audio-pass FAILED: no recording"; exit 1; }
	$(AUDIO_PYTHON) tools/audio/pass_report.py $(BUILD_DIR)/audio/pass.wav $(BUILD_DIR)/audio/pass.log

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
	@echo "audio-launch-smoke passed: a flagless player launch has the announcer's voice and the music"
