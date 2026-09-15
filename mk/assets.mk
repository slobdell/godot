# Asset pipeline: AI-generated / imported / procedural models into visual slots
# Owner: assets (see _agents/streams/archive/round1/assets.md). Included by the root Makefile.

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

assets-unit: import ## Close-up turnaround of THEME's assembled tank (hull + turret + cannon), day and night [UNIT=ifv YAW=0]
	mkdir -p $(BUILD_DIR)/screenshots && touch $(BUILD_DIR)/.gdignore
	for light in day night; do \
		timeout 120 $(GODOT) --path . --resolution 900x600 --script res://assets/pipeline/unit_view.gd -- \
			$(THEME) $(CURDIR)/$(BUILD_DIR)/screenshots/$(THEME)$(if $(UNIT),-$(UNIT))-unit-$$light.png $$light $(or $(YAW),0) $(UNIT) | grep UNIT_VIEW; \
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

# ---- Round 2 (art stream): the lead's concept review gate and the Meshy ledger (tools/assets/review.py) ----------
.PHONY: art-concept art-review art-review-status art-decide
GROUP ?= concepts
TARGET_SLOT ?= unit.tank
EST_3D ?= 15

# One photoreal concept image (≈9 credits, logged in assets/meshy_ledger.md), registered on the review sheet.
# REFS=path.png (repeatable via space-separated list) makes it image-to-image from references.
art-concept: ## Generate a concept image for the lead's review: NAME=scout_a TITLE="…" PROMPT="…" GROUP=<the slot the options compete for> [TARGET_SLOT= EST_3D= NOTES=<tradeoff> REFS= KEEP_BG=1 for scenes]
	@test -n "$(NAME)" -a -n "$(PROMPT)" -a -n "$(TITLE)" || { echo "need NAME=, TITLE=, PROMPT="; exit 2; }
	$(PYTHON) tools/assets/generate.py --provider meshy --slot unit.tank --concept-only --prompt "$(PROMPT)" \
		--name meshy/$(NAME) $(foreach r,$(REFS),--reference $(r)) $(if $(KEEP_BG),--keep-background)
	$(PYTHON) tools/assets/review.py add --id $(NAME) --concept assets/incoming/meshy/$(NAME).concept.json \
		--group "$(GROUP)" --target "$(TARGET_SLOT)" --title "$(TITLE)" --est-3d $(EST_3D) --notes "$(NOTES)"

art-review: ## Build the lead's concept review sheet: build/review/index.html (+ images)
	$(PYTHON) tools/assets/review.py build

art-review-status: ## List review items (waiting / approved / rejected) and the credits spent
	@$(PYTHON) tools/assets/review.py status

art-decide: ## Record the lead's decision: ID=scout_a DECISION=approved|rejected|superseded WORDS="the lead's words"
	$(PYTHON) tools/assets/review.py decide $(ID) $(DECISION) --words "$(WORDS)"

# ---- Round 2 (art X3): the arena floor's texture set from CC0 ambientCG sources -------------------------------
.PHONY: assets-ground
assets-ground: ## Rebuild the arena floor textures (tools/assets/build_ground.py; downloads CC0 sources if missing)
	$(PYTHON) tools/assets/build_ground.py
	$(GODOT) --headless --path . --import >/dev/null 2>&1
	$(ASSETS_PIPELINE) textures --dir=res://game/theme/cyberpunk/ground 2>/dev/null | grep 'policy' || true
	$(GODOT) --headless --path . --import >/dev/null 2>&1

.PHONY: assets-view
assets-view: import ## Turnaround of a raw model before normalizing: IN=path.glb [SPLIT=1 FORWARD=+x] → build/screenshots/view-<name>.png
	mkdir -p $(BUILD_DIR)/screenshots && touch $(BUILD_DIR)/.gdignore
	timeout 120 $(GODOT) --path . --resolution 900x600 --script res://assets/pipeline/model_view.gd -- $(IN) \
		$(CURDIR)/$(BUILD_DIR)/screenshots/view-$(basename $(notdir $(IN)))$(if $(SPLIT),-split).png $(if $(SPLIT),--split --forward=$(or $(FORWARD),+z)) \
		| grep -E 'size|triangles|islands|labels|MODEL_VIEW'

.PHONY: assets-roster
assets-roster: ## Rebuild the round-2 unit roster theme (scout, IFV, artillery, Lancer) from its Meshy recipe
	tools/assets/build_roster.sh

.PHONY: assets-arena-kit
assets-arena-kit: ## Rebuild the gladiator arena kit theme (props, stands, gate, floodlight tower) from its Meshy recipe
	tools/assets/build_arena_kit.sh

# ---- The lead's review page (tools/assets/review_page.py; process: _agents/streams/references/concept_review.md) ----
.PHONY: art-review-page art-apply-decisions art-concept-batch
art-review-page: ## Build the tap-to-approve review page from waiting concepts: TITLE="Concept review #2" [ALL=1 GROUPS=<group prefix> INTRO= OUT=] → build/review_page/
	$(PYTHON) tools/assets/review_page.py build --title "$(or $(TITLE),Concept review)" $(if $(ALL),--all) \
		$(if $(GROUPS),--groups "$(GROUPS)") $(if $(INTRO),--intro "$(INTRO)") $(if $(OUT),--out "$(OUT)")

# One batch of concepts from a committed spec (tools/assets/concept_batch.py): LIST=1 prints the prompts without spending.
art-concept-batch: ## Generate and register a spec's missing concepts: SPEC=assets/review/batches/x.json [ONLY=<faction or id> LIST=1]
	@test -n "$(SPEC)" || { echo "need SPEC="; exit 2; }
	$(PYTHON) tools/assets/concept_batch.py $(SPEC) $(foreach o,$(ONLY),--only $(o)) $(if $(LIST),--list)

art-apply-decisions: ## Record the lead's taps from the review page: DIR=<read_db out_dir> URL=<artifact url>
	@test -n "$(DIR)" || { echo "need DIR= (the folder read_db saved the decisions collection into)"; exit 2; }
	$(PYTHON) tools/assets/review_page.py apply --decisions "$(DIR)" --url "$(URL)"

# ---- Round 3 (assets X1/X2): the arena kit: stackable containers and giant ad screens ---------------------------
.PHONY: assets-containers assets-ads arena-kit-gallery
assets-containers: ## Rebuild the containers' shared texture set (tools/assets/build_containers.py; CC0 ambientCG + procedural)
	$(PYTHON) tools/assets/build_containers.py
	$(GODOT) --headless --path . --import >/dev/null 2>&1

assets-ads: ## Rebuild the placeholder ads for the giant screens (tools/assets/build_ads.py → game/theme/arena_kit/ads/)
	$(PYTHON) tools/assets/build_ads.py
	$(GODOT) --headless --path . --import >/dev/null 2>&1

arena-kit-gallery: import ## Screenshot the container yard (and ad screens) at night: close, yard, doors, 200 m overview → build/screenshots/arena-kit-*.png [VIEWS=a,b SCREEN=]
	mkdir -p $(BUILD_DIR)/screenshots && touch $(BUILD_DIR)/.gdignore
	timeout 120 $(GODOT) --path . --resolution $(SCREEN) res://game/theme/gallery/arena_kit_gallery.tscn -- \
		--shots-dir=$(CURDIR)/$(BUILD_DIR)/screenshots $(if $(VIEWS),--views=$(VIEWS))
