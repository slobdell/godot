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
