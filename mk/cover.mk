# Cover (round 37, C37.3/C37.4): hull-down behind real low cover. Brief: _agents/streams/cover.md.

HEAT_SEEDS ?= 1 2 3 4
HEAT_TIME ?= 180
HEAT_JOBS ?= 8
HEAT_MAPS ?=
HEAT_FLAGS ?=
## The faction pair per seed (cycled): the four factions, each against another, so no map's heat is one matchup's.
HEAT_PAIRS ?= gangs:law law:syndicate syndicate:condemned condemned:gangs

.PHONY: cover-census cover-heat
cover-census: ## K1: low cover per dealt map (pieces, length, facing, distance to lanes), no Godot -> build/cover/census.json
	$(PYTHON) tests/cover/low_cover_census.py --json $(BUILD_DIR)/cover/census.json

cover-heat: import ## K1: where hulls are hit on every dealt map: HEAT_SEEDS matches a map with --combat-log (HEAT_TIME, HEAT_JOBS, HEAT_MAPS="yard pit", HEAT_FLAGS; resumes: a log with its MATCH_RESULT is kept unless HEAT_FRESH=1) + the census beside it -> build/cover-heat/*.log, build/cover/heat.json
	$(if $(HEAT_FRESH),rm -rf $(BUILD_DIR)/cover-heat &&) mkdir -p $(BUILD_DIR)/cover-heat $(BUILD_DIR)/cover
	maps="$(HEAT_MAPS)"; [ -n "$$maps" ] || maps=$$($(PYTHON) -c 'import sys; sys.path.insert(0, "tests/cover"); import low_cover_census as c; print(" ".join(c.dealt()))'); \
	pairs=($(HEAT_PAIRS)); \
	for map in $$maps; do i=0; for seed in $(HEAT_SEEDS); do pair=$${pairs[$$((i % $${#pairs[@]}))]}; i=$$((i + 1)); \
		grep -qs '^MATCH_RESULT' $(BUILD_DIR)/cover-heat/$$map-$$seed.log || echo "$$map $$seed $${pair%%:*} $${pair##*:}"; done; done | xargs -P $(HEAT_JOBS) -L 1 sh -c '\
		timeout $$(( $(HEAT_TIME) * 6 + 300 )) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control \
			--arena=$$0 --seed=$$1 --green-faction=$$2 --rust-faction=$$3 --budget=5200 --time-limit=$(HEAT_TIME) --combat-log $(HEAT_FLAGS) \
			> $(BUILD_DIR)/cover-heat/$$0-$$1.log 2>&1; echo "HEAT_RUN $$0 seed $$1 $$2 v $$3 exit $$?"'
	$(PYTHON) tests/cover/low_cover_census.py --heat $(BUILD_DIR)/cover-heat --json $(BUILD_DIR)/cover/heat.json

# K5 (round 37): check a prepared plan of tools/make_arenas.py (COVER_K5 a | b | none) in build/cover-k5-<plan>/, arenas/
# untouched: only the plan's maps change, only barricades come in, runs clear 5 m, every R4 lane still passes.
PLAN ?= b
.PHONY: cover-k5
cover-k5: ## Round 37 (cover K5): check the prepared low-cover plan PLAN=a|b|none against arenas/ (no Godot; arenas/ untouched)
	@$(PYTHON) tests/cover/k5_check.py $(PLAN) $(BUILD_DIR)/cover-k5-$(PLAN)
