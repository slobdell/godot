# Asset pipeline: AI-generated / imported / procedural models into visual slots
# Owner: assets (see _agents/streams/assets.md). Included by the root Makefile.

.PHONY: assets-slots assets-inspect assets-normalize assets-check assets-textures

ASSETS_PIPELINE := $(GODOT) --headless --path . --script res://assets/pipeline/pipeline.gd --
THEME ?= kitbash

assets-slots: import ## Print the visual slot contracts the asset pipeline enforces
	@$(ASSETS_PIPELINE) slots 2>/dev/null | grep -v '^Godot Engine'

assets-inspect: import ## Measure a model: IN=path.glb [SLOT=tank.hull] (bounds, tris, materials, contract check)
	$(ASSETS_PIPELINE) inspect --in=$(IN) $(if $(SLOT),--slot=$(SLOT))

# Extra pipeline flags go in ARGS, e.g. ARGS="--forward=+x --exclude=gun* --tint=paint*".
assets-normalize: import ## Fit a model to a slot: IN=path.glb SLOT=tank.hull THEME=kitbash [ARGS=...]
	$(ASSETS_PIPELINE) normalize --in=$(IN) --slot=$(SLOT) --theme=$(THEME) $(ARGS)
	$(MAKE) --no-print-directory assets-textures THEME=$(THEME)

# Import first (extracts the GLB's textures), apply the policy, import again with it.
assets-textures: ## Apply the web/mobile texture import policy to a generated theme's maps: THEME=kitbash
	$(GODOT) --headless --path . --import >/dev/null 2>&1
	$(ASSETS_PIPELINE) textures --theme=$(THEME) 2>/dev/null | grep 'policy' || true
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
.PHONY: assets-gallery assets-preview assets-kitbash assets-procedural assets-report assets-web-gallery assets-unit assets-prison-dozer
SCREEN ?= 1600x900

# build/.gdignore: without it Godot imports every screenshot PNG and exports them into the web .pck.
assets-gallery: import ## Screenshot a generated theme's models beside the default art: THEME=kitbash [SCREEN=1920x864] [ONLY=kit.] [NIGHT=1]
	mkdir -p $(BUILD_DIR)/screenshots && touch $(BUILD_DIR)/.gdignore
	timeout 90 $(GODOT) --path . --resolution $(SCREEN) res://assets/pipeline/gallery.tscn -- --theme=$(THEME) \
		$(if $(ONLY),--only=$(ONLY)) $(if $(NIGHT),--night) \
		--screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/assets-gallery-$(THEME)$(if $(ONLY),-$(ONLY))$(if $(NIGHT),-night)-$(SCREEN).png

# FLAGS are normal game launch flags, e.g. FLAGS="--skirmish --screenshot-delay=8".
assets-preview: import ## Screenshot the real game with THEME's generated slots swapped in [FLAGS=--demo] [SCREEN=]
	mkdir -p $(BUILD_DIR)/screenshots && touch $(BUILD_DIR)/.gdignore
	timeout 120 $(GODOT) --path . --resolution $(SCREEN) res://assets/pipeline/theme_preview.tscn -- --theme=$(THEME) \
		$(or $(FLAGS),--demo) --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/assets-preview-$(THEME)-$(SCREEN).png

assets-unit: import ## Close-up turnaround of THEME's assembled tank (hull + turret + cannon), day and night [SCREEN=900x600]
	mkdir -p $(BUILD_DIR)/screenshots && touch $(BUILD_DIR)/.gdignore
	for light in day night; do \
		timeout 120 $(GODOT) --path . --resolution 900x600 --script res://assets/pipeline/unit_view.gd -- \
			$(THEME) $(CURDIR)/$(BUILD_DIR)/screenshots/$(THEME)-unit-$$light.png $$light | grep UNIT_VIEW; \
	done

assets-procedural: import ## A4: build the procedural neon kit (containers, barriers, poles, billboards, scrap) into THEME=neon_kit
	$(GODOT) --headless --path . --script res://assets/pipeline/procedural_kit.gd -- --theme=$(if $(filter command line,$(origin THEME)),$(THEME),neon_kit)
	$(MAKE) --no-print-directory assets-textures THEME=$(if $(filter command line,$(origin THEME)),$(THEME),neon_kit)

assets-report: import ## A5: per-asset tris/draw calls/texture memory for every theme, then the web .pck breakdown
	$(GODOT) --headless --path . --script res://assets/pipeline/budget_report.gd 2>/dev/null | grep -E '^\||^###'
	touch $(BUILD_DIR)/.gdignore
	$(MAKE) --no-print-directory export-web >/dev/null
	$(PYTHON) tools/assets/pck_report.py $(BUILD_DIR)/web/index.pck

# Release web templates refuse a scene path on the command line, so this exports a source-only copy of the
# project whose main scene is the gallery (tools/assets/web_gallery.sh).
assets-web-gallery: import $(TEMPLATES_OK) $(WEB_SMOKE_DEPS) ## Render a theme's gallery in headless Chrome (WebGL 2): textures/emissive work in the browser [ONLY= NIGHT=1]
	CHROME=$(CHROME) tools/assets/web_gallery.sh $(GODOT) $(THEME) $(SMOKE_PORT) \
		$(BUILD_DIR)/screenshots/assets-web-gallery-$(THEME)$(if $(ONLY),-$(ONLY))$(if $(NIGHT),-night).png \
		"$(if $(ONLY),&only=$(ONLY))$(if $(NIGHT),&night)"

assets-prison-dozer: ## Rebuild the prison_dozer theme (the art-direction north star, Meshy-generated) from its recipe
	tools/assets/build_prison_dozer.sh

assets-kitbash: ## Rebuild the kitbash theme from its recipe: fetch CC0 sources, normalize every slot (tools/assets/build_kitbash.sh)
	tools/assets/build_kitbash.sh
