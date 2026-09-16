# The soundtrack and the game's sound: placeholder music, the loudness and loop contract, importing the lead's
# Suno tracks, and the match-mood signal's tests.
# Owner: audio (_agents/streams/audio.md). Included by the root Makefile.

.PHONY: music-placeholders music-check music-import audio-check

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

audio-check: music-check ## Everything the audio stream verifies headless beyond the announcer's own checks
	@echo "audio-check passed"
