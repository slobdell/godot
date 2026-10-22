# ---- Round 37 feedback stream: the rules made visible (_agents/streams/feedback.md) -----------------------------------

FB_DIR := $(BUILD_DIR)/feedback-shots
FB_ARENA ?= terminus
FB_RES ?= 1854x1011
FB_PRESET ?= laptop
FB_SLOTS ?= hit,pinned,repair,cone
FB_CLIP_FRAMES ?= 24
FB_FLAGS ?=

feedback-shots: import ## his picked looks staged in a real skirmish, stills at his pose + close, and clips -> build/feedback-shots/<preset>/ (needs a display: make remote T=feedback-shots; FB_PRESET=laptop|desktop FB_ARENA= FB_SLOTS= FB_CLIP_FRAMES= FB_RES=)
	rm -rf $(FB_DIR)/$(FB_PRESET) && mkdir -p $(FB_DIR)/$(FB_PRESET)
	@echo "commit $${TANK_SQUAD_COMMIT:-$$(git rev-parse --short HEAD 2>/dev/null)}$$(git diff --quiet HEAD 2>/dev/null || echo ' (+ uncommitted)') host $$(hostname) preset $(FB_PRESET) arena $(FB_ARENA) res $(FB_RES)" \
		> $(FB_DIR)/$(FB_PRESET)/SOURCE.txt
	timeout 900 $(GODOT) --path . --resolution $(FB_RES) -- --skirmish --scripted --seed=3 --no-pick-faction --mute \
		--announcer-history=off --music-history=off --render-preset=$(FB_PRESET) --arena=$(FB_ARENA) \
		--feedback-shots=$(CURDIR)/$(FB_DIR)/$(FB_PRESET) --feedback-shots-slots=$(FB_SLOTS) \
		--feedback-shots-clip-frames=$(FB_CLIP_FRAMES) $(FB_FLAGS) \
		2>&1 | tee $(FB_DIR)/$(FB_PRESET)/log.txt | grep -E '^FEEDBACK_|SCRIPT ERROR' || true
	@grep -q FEEDBACK_SHOTS_DONE $(FB_DIR)/$(FB_PRESET)/log.txt || { echo "feedback-shots: did not finish ($(FB_DIR)/$(FB_PRESET)/log.txt)"; exit 1; }
	@! grep -E 'SCRIPT ERROR' $(FB_DIR)/$(FB_PRESET)/log.txt
	@for d in $(FB_DIR)/$(FB_PRESET)/*/; do \
		[ -f "$$d/frame_000.png" ] || continue; \
		ffmpeg -loglevel error -y -framerate 12 -i "$$d/frame_%03d.png" -vf "scale=960:-2" -c:v libx264 -pix_fmt yuv420p \
			-movflags +faststart "$${d%/}.mp4" && rm -rf "$$d"; \
	done
	@cat $(FB_DIR)/$(FB_PRESET)/SOURCE.txt
	@echo "feedback-shots: $$(ls $(FB_DIR)/$(FB_PRESET)/*.png | wc -l) stills, $$(ls $(FB_DIR)/$(FB_PRESET)/*.mp4 2>/dev/null | wc -l) clips in $(FB_DIR)/$(FB_PRESET)"

FB_FIGHT_CLIPS ?= 2
FB_FIGHT_FRAMES ?= 36
FB_FIGHT_SEED ?= 3
FB_FIGHT_DIR = $(BUILD_DIR)/feedback-fight/$(FB_PRESET)-seed$(FB_FIGHT_SEED)

feedback-fight: import ## his picked looks in a REAL CPU fight (gangs v Law, nothing staged), clips following each slot's moment -> build/feedback-fight/<preset>-seed<N>/ (needs a display: make remote T=feedback-fight; FB_PRESET= FB_ARENA= FB_FIGHT_SEED= FB_FIGHT_CLIPS= FB_FIGHT_FRAMES= FB_FLAGS=)
	rm -rf $(FB_FIGHT_DIR) && mkdir -p $(FB_FIGHT_DIR)
	@echo "commit $${TANK_SQUAD_COMMIT:-$$(git rev-parse --short HEAD 2>/dev/null)}$$(git diff --quiet HEAD 2>/dev/null || echo ' (+ uncommitted)') host $$(hostname) preset $(FB_PRESET) arena $(FB_ARENA) seed $(FB_FIGHT_SEED) res $(FB_RES)" \
		> $(FB_FIGHT_DIR)/SOURCE.txt
	timeout 1200 $(GODOT) --path . --resolution $(FB_RES) -- --skirmish --player=cpu --enemy=cpu --player-faction=gangs \
		--enemy-faction=law --seed=$(FB_FIGHT_SEED) --squad-cap=5 --cinematic --no-pick-faction --mute --announcer-history=off \
		--music-history=off --render-preset=$(FB_PRESET) --arena=$(FB_ARENA) \
		--feedback-fight=$(CURDIR)/$(FB_FIGHT_DIR) --feedback-fight-clips=$(FB_FIGHT_CLIPS) \
		--feedback-fight-frames=$(FB_FIGHT_FRAMES) --feedback-fight-max-s=900 $(FB_FLAGS) \
		2>&1 | tee $(FB_FIGHT_DIR)/log.txt | grep -E '^FEEDBACK_|SCRIPT ERROR' || true
	@grep -q FEEDBACK_FIGHT_DONE $(FB_FIGHT_DIR)/log.txt || { echo "feedback-fight: did not finish"; exit 1; }
	@! grep -E 'SCRIPT ERROR' $(FB_FIGHT_DIR)/log.txt
	@for d in $(FB_FIGHT_DIR)/*/; do \
		[ -f "$$d/frame_000.png" ] || continue; \
		cp "$$d/frame_$$(printf %03d $$(( $$(ls $$d | wc -l) / 2 )))".png "$${d%/}_mid.png"; \
		ffmpeg -loglevel error -y -framerate 12 -i "$$d/frame_%03d.png" -vf "scale=960:-2" -c:v libx264 -pix_fmt yuv420p \
			-movflags +faststart "$${d%/}.mp4" && rm -rf "$$d"; \
	done
	@cat $(FB_FIGHT_DIR)/SOURCE.txt
	@echo "feedback-fight: $$(ls $(FB_FIGHT_DIR)/*.mp4 2>/dev/null | wc -l) clips in $(FB_FIGHT_DIR)"

.PHONY: feedback-shots feedback-fight
