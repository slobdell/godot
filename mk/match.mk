# Match runner and AI experiments
# Owner: gameplay (see _agents/workstreams.md). Included by the root Makefile.

# ---- Match runner (headless bots vs bots, faster than real time) ----------------
# --fixed-fps 60 makes every frame advance exactly 1/60 s of game time without
# waiting for the wall clock, so matches run as fast as the CPU allows.

match: import ## One headless match: GREEN=1 RUST=1 SCORE=5 TIME=300 SEED=1; prints MATCH_RESULT JSON
	$(GODOT) --headless --fixed-fps 60 --path . -- --match --green=$(GREEN) --rust=$(RUST) \
		--score-limit=$(SCORE) --time-limit=$(TIME) --seed=$(SEED) | grep MATCH_RESULT

matches: import ## N seeded matches in parallel with a win-rate summary (N=10 JOBS=4, same knobs as match)
	$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(N) --jobs $(JOBS) --green $(GREEN) \
		--rust $(RUST) --score-limit $(SCORE) --time-limit $(TIME) --json $(BUILD_DIR)/matches.json

determinism: import ## Same seed + same doctrines twice → byte-identical match results (experiment T0)
	mkdir -p $(BUILD_DIR)
	for run in 1 2; do \
		$(GODOT) --headless --fixed-fps 60 --path . -- --match --green-doctrine=res://doctrines/anvil_hammer.json \
			--rust-doctrine=res://doctrines/flame_rush.json --score-limit=8 --time-limit=150 --seed=11 2>/dev/null \
			| grep MATCH_RESULT | $(PYTHON) -c "import json,sys; r=json.loads(sys.stdin.read().split('MATCH_RESULT ')[1]); [r.pop(k) for k in ('real_seconds','speedup')]; print(json.dumps(r, sort_keys=True))" \
			> $(BUILD_DIR)/determinism_$$run.json; \
	done
	cmp $(BUILD_DIR)/determinism_1.json $(BUILD_DIR)/determinism_2.json
	@echo "determinism passed: $$(cat $(BUILD_DIR)/determinism_1.json | cut -c1-120)..."

watch-match: import ## Watch a doctrine match from above in a window (GREEN_DOCTRINE, RUST_DOCTRINE, SEED)
	$(GODOT) --path . -- --match --green-doctrine=res://doctrines/$(GREEN_DOCTRINE).json \
		--rust-doctrine=res://doctrines/$(RUST_DOCTRINE).json --score-limit=$(SCORE) --time-limit=$(TIME) --seed=$(SEED)

match-smoke: import ## A short 2v2 match must finish with a result, faster than real time
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --fixed-fps 60 --path . -- --match --green=2 --rust=2 --score-limit=3 --time-limit=120 --seed=7 \
		2>&1 | tee $(BUILD_DIR)/match-smoke.log | grep MATCH_RESULT
	! grep -E 'ERROR' $(BUILD_DIR)/match-smoke.log
	$(PYTHON) -c "import json,sys; r=json.loads(open('$(BUILD_DIR)/match-smoke.log').read().split('MATCH_RESULT ')[1].splitlines()[0]); \
		assert r['speedup'] > 2, r; assert sum(r['stats']['shots']) > 0, r; print('match-smoke passed:', r['winner'], r['score'], f\"{r['speedup']}x\")"

matchups: import ## R7 unit-vs-unit matrix: cost-equal armies for every pair, both bases and colors (BUDGET=600 SEEDS=3 ARENA= TUNE= FOCUS=unit ESCORT=unit BALANCE=1 writes balance.md)
	$(PYTHON) tools/matchup_matrix.py --godot $(GODOT) --jobs $(JOBS) --budget $(or $(BUDGET),600) --seeds $(or $(SEEDS),3) \
		$(if $(ARENA),--arena $(ARENA)) $(if $(TUNE),--tune $(TUNE)) $(if $(FOCUS),--focus $(FOCUS)) $(if $(ESCORT),--escort $(ESCORT)) \
		$(if $(BALANCE),--balance) --json $(BUILD_DIR)/matchups.json

duel: import ## Watch a small fight as a text timeline (shots, hits, poses): GREEN_UNITS=tank RUST_UNITS=scout,scout SEED=1 DUEL_TIME=90 [ARENA= TUNE=]
	$(PYTHON) tools/combat_duel.py --godot $(GODOT) --green $(or $(GREEN_UNITS),tank) --rust $(or $(RUST_UNITS),tank) \
		--seed $(SEED) --time-limit $(or $(DUEL_TIME),90) $(if $(ARENA),--arena $(ARENA)) $(if $(TUNE),--tune $(TUNE))

matchup-search: import ## Score --tune variants of the matchup matrix against the designed counters: VARIANTS=tools/matchup_variants/<file>.json [UNITS= SEEDS=2 ESCORT=]
	$(PYTHON) tools/matchup_search.py --godot $(GODOT) --jobs $(JOBS) --variants $(VARIANTS) --seeds $(or $(SEEDS),2) \
		$(if $(UNITS),--units $(UNITS)) $(if $(ESCORT),--escort $(ESCORT))
