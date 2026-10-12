# ---- scout (round 27): a scout fights from a distance it can still turn in, and reverses to keep a moving target ------
# Owner: the scout stream (_agents/streams/scout.md).

SCOUT_FILTER ?= scenario_scout_cross
scout_comma := ,
SCOUT_POOL ?= 1

.PHONY: scout-cross
scout-cross: native-for-check import ## scout S0: the lead's cases (a tank crossing the scout's nose at 5/10 m both ways; side-on against its nose driving away east), pooled over start ticks {1,3,6,8,11,16} x 3 seeds -> build/scout/cross.log (MEASURE scout_cross lines). SCOUT_PROBE=1 traces every 0.5 s; SCOUT_POOL=0 one run a case; NAV_FLAGS passes --nav-off=... etc.
	@mkdir -p $(BUILD_DIR)/scout
	@s=0; SCOUT_PROBE=$(SCOUT_PROBE) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- \
		--filter=$(SCOUT_FILTER) $(if $(filter 1,$(SCOUT_POOL)),--scout-pool) $(NAV_FLAGS) > $(BUILD_DIR)/scout/cross.log 2>&1 || s=$$?; \
	grep -E "^MEASURE scout_cross|PASS|PENDING|FAIL|^scenarios:" $(BUILD_DIR)/scout/cross.log || true; \
	echo "scout-cross: runner exited $$s (1 = a scenario failed or a pending one passed; read the lines above)"

# The census: the showmatch's own match (main.tscn, --demo-match, the same seed) headless, every fixed gun measured while
# it fights. SCOUT_SEEDS (spaces, commas or underscores: `make remote T=` word-splits) seeds at once (SCOUT_JOBS) -> build/scout/census/<seed>.log + the table.
SCOUT_SEEDS ?= 1 2 3 4 5 6 7 8
SCOUT_JOBS ?= 4
SCOUT_SECONDS ?= 180
.PHONY: scout-census
scout-census: native-for-check import ## scout S0: every fixed gun in showmatch matches (SCOUT_SEEDS, headless, the seed `make showmatch SEED=` films): fight seconds, gun on target, inside its turning room, reversing, enemy contacts -> build/scout/census/ + table
	@rm -rf $(BUILD_DIR)/scout/census; mkdir -p $(BUILD_DIR)/scout/census
	@echo ">> scout-census on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | flags '$(NAV_FLAGS)'"
	@for seed in $(subst _, ,$(subst $(scout_comma), ,$(SCOUT_SEEDS))); do echo $$seed; done | xargs -P $(SCOUT_JOBS) -I{} sh -c 'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . \
		--script res://tests/scout/scout_census.gd -- --skirmish --demo-match --clean --seed={} --arena=random --mute \
		--seconds=$(SCOUT_SECONDS) $(NAV_FLAGS) > $(BUILD_DIR)/scout/census/{}.log 2>&1 || true'
	@$(PYTHON) tests/scout/census_table.py $(BUILD_DIR)/scout/census/*.log
