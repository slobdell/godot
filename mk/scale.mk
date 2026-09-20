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

.PHONY: grid-fairness

# Item 3's OWN fairness control, and it is a different experiment from `make arena-series`.
#
# arena-series plays FACTION armies, and a faction army never stands on the spawn grid: `Match.load_doctrine` ends in
# `ArmyLayout.deploy()`, which re-lays every unit by its own hull size at tick 0, synchronously, before any physics
# step. So arena-series measures whether the ARENA and its navmesh are fair; it cannot see this grid at all.
#
# What lives on the grid is what `Match.spawn_tank` puts there and leaves: network players and legacy bots. So the
# control for a spawn-grid change is a BOT series -- which is also verification.md's prescription
# (`--runs 60 --green 2 --rust 2`, with and without `--swap-bases`) and the E0 configuration that recorded 51% after
# the mirrored half-bake fixed the 64% south bias (squad_ai_design.md's fairness row, trip-up 21).
#
# Two arms, same seeds. `tools/match_series.py` has no swap-applied guard of its own (arena_series.py does), so the
# positive control for THIS arm is `test_swapping_the_bases_actually_moves_where_a_team_spawns` in
# tests/test_spawn_grid.gd: it asserts the flag moves the geometry on both the constants and every baked list. A win
# rate from these two arms means nothing without that test green -- an unapplied swap gives two identical arms and a
# perfectly plausible 50/50.
grid-fairness: import ## Item 3: the SPAWN GRID's swap-bases control, 2v2 bots (the only units that stand on it) (N=60 TIME=300 SCORE=5) -> build/grid-fairness-{normal,swapped}.json
	@mkdir -p $(BUILD_DIR)
	@for arm in normal swapped; do \
		echo "== grid fairness: 2v2 bots, $$arm bases, seeds 1-$(or $(N),60) =="; \
		$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),60) --jobs $(JOBS) \
			--green 2 --rust 2 --score-limit $(or $(SCORE),5) --time-limit $(or $(TIME),300) \
			--json $(BUILD_DIR)/grid-fairness-$$arm.json \
			$$([ $$arm = swapped ] && echo "--extra=--swap-bases") \
			| grep -E "matches|wins:" || exit 1; \
	done

.PHONY: spawn-probe

# Diagnostic for main's red spawn test: says WHERE the flagged units are and WHAT they intersect, which the test
# itself cannot (it reports names only). Reproduces the test's setup exactly -- foundry, seed_spawns(9, 6.0), a full
# Army.MAX_ARMY_UNITS army a side.
spawn-probe: import ## Why a full army spawns inside geometry: positions + the bodies hit (ARENA=foundry PROBE_FLAGS=--pollute=X|--pollute-free=X)
	$(GODOT) --headless --path . --script res://tests/scale/spawn_block_probe.gd -- \
		$(if $(ARENA),--arena=$(ARENA)) $(PROBE_FLAGS) 2>&1 | grep -E '^SPAWN_PROBE|SCRIPT ERROR' || true

.PHONY: lamp-frames

# The acceptance test for the Terminus lamps (round 9, feel's finding): the floor has to read, and the vehicles have
# to read ON it, at the pose the lead plays at. Shot as a PAIR -- `--no-show` and then with the show -- because the
# show MODULATES what is already lit and its `pools` channel is not the floor's baseline (ruled with show). A frame
# that looks lit only with the show on has not fixed anything; the lamps are the baseline and the show is the gloss.
# Same seed and the same delay for both arms, so the only difference between the two images is the show.
lamp-frames: import ## The Terminus lamp pair at the player's camera, show OFF then ON (ARENA=terminus DELAY=20) -> build/lamps/
	rm -rf $(BUILD_DIR)/lamps && mkdir -p $(BUILD_DIR)/lamps
	for arm in off on; do \
		flags=$$([ $$arm = off ] && echo "--no-show"); \
		$(GODOT) --path . --resolution 1920x1080 -- --skirmish --scripted --seed=3 --mute \
			--arena=$(or $(ARENA),terminus) $$flags --screenshot-delay=$(or $(DELAY),20) \
			--screenshot=$(CURDIR)/$(BUILD_DIR)/lamps/terminus-show-$$arm.png 2>&1 \
			| grep -E "ERROR|SCRIPT ERROR" || true; \
	done
	@ls -la $(BUILD_DIR)/lamps/*.png
