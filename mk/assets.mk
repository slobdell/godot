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
