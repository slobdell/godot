# The soundtrack and the game's sound: placeholder music, the loudness and loop contract, importing the lead's
# Suno tracks, and the match-mood signal's tests.
# Owner: audio (_agents/streams/audio.md). Included by the root Makefile.

.PHONY: music-placeholders music-check music-import music-smoke audio-check

MUSIC_DIR ?= assets/music

music-placeholders: ## Regenerate the placeholder beds and stingers (synthesised here, CC0; the real tracks come from Suno)
	$(PYTHON) tools/audio/make_music_placeholders.py --out $(MUSIC_DIR)

music-check: ## Every track against the contract in assets/music/PROMPTS.md: loudness, true peak, loop points, seams
	$(PYTHON) tools/audio/check_music.py $(MUSIC_DIR)

## The lead's own workflow: turn one Suno download into a bed the director can use.
music-import: ## Import a Suno track: IN=~/Downloads/battle.mp3 STATE=battle BPM=110 [RIGHTS="Suno Pro, 2026-09-16"]
	@test -n "$(IN)" || { echo "usage: make music-import IN=<file> STATE=<state> BPM=<tempo>"; exit 2; }
	@test -n "$(STATE)" || { echo "STATE is required (garage, pre_match, lull, skirmish, battle, last_stand, victory, defeat)"; exit 2; }
	@test -n "$(BPM)" || { echo "BPM is required: the crossfade lands on a bar line"; exit 2; }
	$(PYTHON) tools/audio/import_music.py "$(IN)" --state $(STATE) --bpm $(BPM) --out $(MUSIC_DIR) \
		$(if $(RIGHTS),--rights "$(RIGHTS)")

# The sim-baseline match again (mk/core.mk), with the soundtrack following it: the music must change with the match
# and must not change the match. Same shape as announcer-record-smoke, and the same guarantee.
music-smoke: import ## A real headless match with the music on: the beds change, and the simulation hash does not
	@mkdir -p $(BUILD_DIR)/audio
	@key="glibc-$$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)"; \
	expected=$$(awk -v k="$$key" '$$1 == k {print $$2}' tests/baselines/sim_state_hash.txt); \
	$(GODOT) --headless --fixed-fps 60 --path . -- --match --elimination \
		--green-doctrine=res://doctrines/anvil_hammer.json --rust-doctrine=res://doctrines/individuals.json \
		--time-limit=40 --seed=3 --music=on 2>/dev/null > $(BUILD_DIR)/audio/music-smoke.log; \
	grep -q '^MUSIC on:' $(BUILD_DIR)/audio/music-smoke.log \
		|| { echo "music-smoke FAILED: the director never attached"; grep -i music $(BUILD_DIR)/audio/music-smoke.log; exit 1; }; \
	beds=$$(grep -c '^MUSIC_TRACK' $(BUILD_DIR)/audio/music-smoke.log); \
	distinct=$$(grep '^MUSIC_TRACK' $(BUILD_DIR)/audio/music-smoke.log | sed 's/.*track=//;s/ .*//' | sort -u | wc -l); \
	[ "$$distinct" -ge 2 ] \
		|| { echo "music-smoke FAILED: the soundtrack never changed ($$beds cues, $$distinct beds)"; \
		     grep '^MUSIC_TRACK' $(BUILD_DIR)/audio/music-smoke.log; exit 1; }; \
	actual=$$(grep MATCH_RESULT $(BUILD_DIR)/audio/music-smoke.log | $(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"); \
	if [ -n "$$expected" ] && [ "$$actual" != "$$expected" ]; then echo "music-smoke FAILED: the soundtrack changed the simulation ($$actual, baseline $$expected)"; exit 1; fi; \
	echo "music-smoke passed: $$beds bed changes across $$distinct beds, hash $$actual$${expected:+ (matches the $$key baseline)}"; \
	grep '^MUSIC_TRACK' $(BUILD_DIR)/audio/music-smoke.log | sed 's/^/  /'

audio-check: music-check music-smoke ## Everything the audio stream verifies headless beyond the announcer's own checks
	@echo "audio-check passed"
