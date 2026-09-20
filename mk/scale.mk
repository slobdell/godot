# The roster at real relative scale (scale stream, round 9, contract S1). Owner: scale (_agents/workstreams.md).
# The rule and its history: _agents/game_design.md *Round 9 direction*; the table: _agents/roster_scale.md.
# Included by the root Makefile.

.PHONY: roster-scale roster-boxes roster-pytest

ROSTER_BOXES_JSON = $(BUILD_DIR)/roster-boxes.json

# The Godot half: every unit's approved mesh, and the box that mesh fills at the unit's derived length, via feel's
# SizeLook.box_at_length(). Headless -- it reads mesh bounds, it does not render.
roster-boxes: import ## S1: measure every unit's mesh and the box it fills at its derived length -> build/roster-boxes.json (LENGTHS=unit:m,unit:m to try a length before changing the catalog)
	@mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . --script res://tests/scale/roster_boxes.gd -- \
		--roster-json=$(CURDIR)/$(ROSTER_BOXES_JSON) $(if $(LENGTHS),--roster-lengths=$(LENGTHS)) \
		2>&1 | grep -E '^ROSTER_BOXES|SCRIPT ERROR' || true
	@test -s $(ROSTER_BOXES_JSON) || { echo "roster-boxes FAILED: no $(ROSTER_BOXES_JSON)"; exit 1; }

roster-scale: roster-boxes ## S1: the whole roster as a table -- reference vehicle, cited length, K, target length, today's box, the mesh's box, MISMATCH (JSON=path to save it)
	$(PYTHON) tools/roster_scale.py --boxes $(ROSTER_BOXES_JSON) $(if $(JSON),--json $(JSON))

# Deliberately NOT in `make check`, for arena-pytest's reason (mk/arena.mk): it guards an instrument only this
# stream reads, and the contract itself is guarded by tests/test_units_scale.gd, which IS in check.
roster-pytest: ## The roster tools' own tests: the catalog reader, and that it refuses rather than falls back
	$(PYTHON) -m unittest discover -s tools -p 'test_roster*.py'

.PHONY: roster-lineup

LINEUP_RES ?= 1920x1080
# The lead's look before CP2 merges (backlog item 2). Needs a display: `make remote T=roster-lineup`. It rides a real
# skirmish, like `size-look` does, so the vehicles stand on the arena floor under the game's own lighting rather than
# in a gallery -- round 8's lesson was that a gallery answered a question he had not asked.
roster-lineup: import ## S1: every vehicle at the new scale, side by side, labelled -> build/roster-lineup/lineup_*.png (needs a display; ARENA=, LINEUP_FLAGS=)
	rm -rf $(BUILD_DIR)/roster-lineup && mkdir -p $(BUILD_DIR)/roster-lineup
	timeout 420 $(GODOT) --path . --resolution $(LINEUP_RES) -- --skirmish --scripted --seed=3 --no-pick-faction --mute \
		$(if $(ARENA),--arena=$(ARENA)) --size-look=$(CURDIR)/$(BUILD_DIR)/roster-lineup --size-look-lineup $(LINEUP_FLAGS) \
		2>&1 | tee $(BUILD_DIR)/roster-lineup/log.txt | grep -E '^SIZE_LOOK|SCRIPT ERROR' || true
	@grep -q SIZE_LOOK_DONE $(BUILD_DIR)/roster-lineup/log.txt
	@ls $(BUILD_DIR)/roster-lineup/*.png

.PHONY: arena-cover

# A3 (round 9): the cover figure that REPLACED `make arena-report`'s centre-point `hull_cover.reach`. Needs Godot
# because it CALLS `Arena.cover_fraction` rather than reimplementing it in Python -- a second copy of that query in
# the report tool is exactly the mirror Invariant 0 is about, and the report tool already carried two of them.
arena-cover: import ## A3: how much of a hull each map actually hides, by hull length, under Arena.cover_fraction (ARENAS=yard,pit) -> build/arena-cover.json
	@mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . --script res://tests/scale/cover_sweep.gd -- \
		$(if $(ARENAS),--arenas=$(ARENAS)) --json=$(CURDIR)/$(BUILD_DIR)/arena-cover.json \
		2>&1 | grep -E '^ARENA_COVER|SCRIPT ERROR' || true
	@grep -q . $(BUILD_DIR)/arena-cover.json 2>/dev/null || { echo "arena-cover FAILED: no json"; exit 1; }
