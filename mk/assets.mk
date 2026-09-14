# Asset pipeline: AI-generated / imported / procedural models into visual slots
# Owner: assets (see _agents/streams/assets.md). Included by the root Makefile.

.PHONY: assets-slots assets-inspect assets-normalize assets-check

ASSETS_PIPELINE := $(GODOT) --headless --path . --script res://assets/pipeline/pipeline.gd --
THEME ?= kitbash

assets-slots: import ## Print the visual slot contracts the asset pipeline enforces
	@$(ASSETS_PIPELINE) slots 2>/dev/null | grep -v '^Godot Engine'

assets-inspect: import ## Measure a model: IN=path.glb [SLOT=tank.hull] (bounds, tris, materials, contract check)
	$(ASSETS_PIPELINE) inspect --in=$(IN) $(if $(SLOT),--slot=$(SLOT))

# Extra pipeline flags go in ARGS, e.g. ARGS="--forward=+x --exclude=gun* --tint=paint*".
assets-normalize: import ## Fit a model to a slot: IN=path.glb SLOT=tank.hull THEME=kitbash [ARGS=...]
	$(ASSETS_PIPELINE) normalize --in=$(IN) --slot=$(SLOT) --theme=$(THEME) $(ARGS)
	$(GODOT) --headless --path . --import >/dev/null 2>&1

assets-check: import ## Enforce slot contracts on every generated theme (budgets, size, anchor, orientation, textures)
	$(ASSETS_PIPELINE) check $(if $(filter command line,$(origin THEME)),--theme=$(THEME))

# ---- A2: hosted generators (keys from the environment; see tools/assets/generate.py) ----------
.PHONY: assets-generate assets-test assets-mock
PROVIDER ?= meshy

assets-generate: ## Generate a model with a hosted AI service: PROVIDER=meshy SLOT=tank.hull PROMPT="..." [IMAGE=url] [NAME=]
	$(PYTHON) tools/assets/generate.py --provider $(PROVIDER) --slot $(SLOT) --prompt "$(PROMPT)" \
		$(if $(IMAGE),--image "$(IMAGE)") $(if $(NAME),--name $(NAME))

assets-test: ## Provider clients vs the local mock server + the Godot asset pipeline tests
	$(PYTHON) -m unittest discover -s tools/assets -p 'test_*.py'
	$(MAKE) --no-print-directory test FILTER=assets

assets-mock: ## Serve the mock Meshy/Tripo API on 127.0.0.1:8799 (point generate.py --base-url at it)
	$(PYTHON) tools/assets/mock_provider.py 8799

# ---- Looking at models (need a display; short windowed runs) -----------------------------------
.PHONY: assets-gallery assets-preview assets-kitbash
SCREEN ?= 1600x900

assets-gallery: import ## Screenshot a generated theme's models beside the default art: THEME=kitbash [SCREEN=2400x1080] [ONLY=kit.]
	mkdir -p $(BUILD_DIR)/screenshots
	timeout 90 $(GODOT) --path . --resolution $(SCREEN) res://assets/pipeline/gallery.tscn -- --theme=$(THEME) \
		$(if $(ONLY),--only=$(ONLY)) --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/assets-gallery-$(THEME)$(if $(ONLY),-$(ONLY))-$(SCREEN).png

# FLAGS are normal game launch flags, e.g. FLAGS="--skirmish --screenshot-delay=8".
assets-preview: import ## Screenshot the real game with THEME's generated slots swapped in [FLAGS=--demo] [SCREEN=]
	mkdir -p $(BUILD_DIR)/screenshots
	timeout 120 $(GODOT) --path . --resolution $(SCREEN) res://assets/pipeline/theme_preview.tscn -- --theme=$(THEME) \
		$(or $(FLAGS),--demo) --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/assets-preview-$(THEME)-$(SCREEN).png

assets-kitbash: ## Re-fetch the CC0 sources behind the kitbash theme into assets/incoming/ (see assets/CREDITS.md)
	tools/assets/fetch_kitbash.sh
