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
