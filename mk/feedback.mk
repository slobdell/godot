# ---- Round 37 feedback stream: the rules made visible (_agents/streams/feedback.md) -----------------------------------

FB_DIR := $(BUILD_DIR)/feedback-shots
FB_ARENA ?= terminus
FB_RES ?= 1854x1011
FB_PRESET ?= laptop
FB_SLOTS ?= hit,pinned,repair,cone
FB_CLIP_FRAMES ?= 24
FB_FLAGS ?=

feedback-shots: import ## F1: every look of every feedback slot staged in a real skirmish, stills at his pose + close, and clips -> build/feedback-shots/<preset>/ (needs a display: make remote T=feedback-shots; FB_PRESET=laptop|desktop FB_ARENA= FB_SLOTS= FB_CLIP_FRAMES= FB_RES=)
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

feedback-page: ## F1: the lead's directions page from build/feedback-shots/<preset>/ -> build/feedback-page/index.html (pure Python; FB_PRESET=)
	python3 tests/feedback/directions_page.py --shots $(FB_DIR)/$(FB_PRESET) --out $(BUILD_DIR)/feedback-page

.PHONY: feedback-shots feedback-page
