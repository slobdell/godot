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

# ---- X2 (round 4): does suppression change outcomes? ----------------------------
# Every weapon's "suppression" set to 0 is the control: the threat field stays empty, nobody is ever pinned, and
# spread loses its suppression term. A volume weapon (the scout's machine gun) should be worth MORE with it on.
SUPPRESSION_OFF := --tune=machine_gun.suppression=0,autocannon.suppression=0,cannon.suppression=0,laser.suppression=0,mortar.suppression=0,flamethrower.suppression=0

suppression-series: import ## X2: one archetype vs another with suppression on, then off (GREEN_ARCH=swarm RUST_ARCH=armor N=16 BUDGET=1000)
	@for mode in on off; do 		echo "== suppression $$mode =="; 		$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),16) --jobs $(JOBS) --time-limit 300 --score-limit 0 			--json $(BUILD_DIR)/suppression-$$mode.json 			--extra="--green-doctrine=cpu:$(or $(GREEN_ARCH),swarm) --rust-doctrine=cpu:$(or $(RUST_ARCH),armor) --elimination --budget=$(or $(BUDGET),1000) $$([ $$mode = off ] && echo '$(SUPPRESSION_OFF)')"; 	done

suppression-control: import ## X2: the same pairing counterbalanced (bases and colors swapped), suppression on then off
	@for mode in on off; do 		for swap in "" "--swap-bases"; do 			echo "== suppression $$mode $$swap =="; 			$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),16) --jobs $(JOBS) --time-limit 300 --score-limit 0 				--extra="--green-doctrine=cpu:$(or $(GREEN_ARCH),swarm) --rust-doctrine=cpu:$(or $(RUST_ARCH),armor) --elimination --budget=$(or $(BUDGET),1000) $$swap $$([ $$mode = off ] && echo '$(SUPPRESSION_OFF)')"; 			echo "== suppression $$mode $$swap, colors swapped =="; 			$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),16) --jobs $(JOBS) --time-limit 300 --score-limit 0 				--extra="--green-doctrine=cpu:$(or $(RUST_ARCH),armor) --rust-doctrine=cpu:$(or $(GREEN_ARCH),swarm) --elimination --budget=$(or $(BUDGET),1000) $$swap $$([ $$mode = off ] && echo '$(SUPPRESSION_OFF)')"; 		done; 	done

faction-match: import ## L3: one full-scale faction battle (GREEN_FACTION=condemned RUST_FACTION=gangs SEED=1), prints MATCH_RESULT
	$(GODOT) --headless --fixed-fps 60 --path . -- --match --elimination --control 		--green-faction=$(or $(GREEN_FACTION),condemned) --rust-faction=$(or $(RUST_FACTION),condemned) 		--budget=$(or $(BUDGET),5200) --time-limit=$(or $(TIME),300) --seed=$(SEED) | grep MATCH_RESULT

faction-series: import ## L3: N seeded faction battles at the baseline budget (GREEN_FACTION= RUST_FACTION= N=12 BUDGET=5200)
	$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),12) --jobs $(JOBS) --time-limit 300 --score-limit 0 		--json $(BUILD_DIR)/faction-$(or $(GREEN_FACTION),condemned)-vs-$(or $(RUST_FACTION),condemned).json 		--extra="--green-faction=$(or $(GREEN_FACTION),condemned) --rust-faction=$(or $(RUST_FACTION),condemned) --elimination --control --budget=$(or $(BUDGET),5200)"

# ---- X5 (round 4): what does the simulation cost at scale? -----------------------
# One headless match per size, run as fast as the machine allows. MATCH_RESULT's `speedup` is simulated seconds per
# real second, so ms/tick = 1000 / (60 x speedup). Run it WITHOUT brains for the simulation's own cost (this stream
# owns that) and WITH them for the whole picture (ai owns the difference). Heavy: use `make remote T=scale-bench`.
SCALE_SIZES ?= 25 40 60 100

scale-bench: import ## X5: sim cost per tick at SCALE_SIZES vehicles a side, with and without brains (BENCH_FACTION= TIME=60)
	@printf '%-8s %-8s %-10s %-10s %s\n' "a side" "brains" "speedup" "ms/tick" "budget at 60 fps = 16.7 ms"
	@for size in $(SCALE_SIZES); do 		for brains in off on; do 			$(GODOT) --headless --fixed-fps 60 --path . -- --match --bench-units=$$size 				--bench-faction=$(or $(BENCH_FACTION),condemned) --time-limit=$(or $(TIME),60) --score-limit=0 --seed=5 				$$([ $$brains = off ] && echo --no-brains) 2>/dev/null | grep MATCH_RESULT 				| $(PYTHON) -c "import json,sys; r=json.loads(sys.stdin.read().split('MATCH_RESULT ')[1]); 					print('%-8s %-8s %-10.1f %-10.3f' % ('$$size', '$$brains', r['speedup'], 1000.0/(60.0*r['speedup'])))"; 		done; 	done

faction-matrix: import ## X6: every faction pair at the baseline budget, counterbalanced (SEEDS=6 BUDGET=5200 TIME=180) -> build/faction-matrix.json
	$(PYTHON) tools/faction_matrix.py --godot $(GODOT) --jobs $(JOBS) --seeds $(or $(SEEDS),6) \
		--budget $(or $(BUDGET),5200) --time-limit $(or $(TIME),180) --json $(BUILD_DIR)/faction-matrix.json

faction-shots: import ## L3/X5: screenshots of a full-scale faction battle from above (GREEN_FACTION= RUST_FACTION= DELAY=45) -> build/screenshots/faction-*.png (needs a display)
	mkdir -p $(BUILD_DIR)/screenshots
	for delay in 12 $(or $(DELAY),45); do \
		$(GODOT) --path . --resolution 1920x1080 -- --match --elimination --control \
			--green-faction=$(or $(GREEN_FACTION),condemned) --rust-faction=$(or $(RUST_FACTION),condemned) \
			--budget=$(or $(BUDGET),5200) --time-limit=300 --seed=$(SEED) --screenshot-delay=$$delay \
			--screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/faction-$(or $(GREEN_FACTION),condemned)-vs-$(or $(RUST_FACTION),condemned)-$$delay\s.png; \
	done

# ---- CP1 (round 5): what a simulation tick costs, by section --------------------------
# M1's budget is the WHOLE tick (all _physics_process) <= 5 ms at 60 vehicles on the lead's laptop, shared with ai.
sim-profile: import ## CP1: one faction battle with SimProfile on: ms per tick by section (GREEN_FACTION= RUST_FACTION= TIME=90 SEED=3 PROFILE_FLAGS=--no-brains) -> build/sim-profile.json
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --fixed-fps 60 --path . -- --match --elimination --control --sim-profile \
		--green-faction=$(or $(GREEN_FACTION),condemned) --rust-faction=$(or $(RUST_FACTION),condemned) \
		--budget=$(or $(BUDGET),5200) --time-limit=$(or $(TIME),90) --seed=$(or $(SEED),3) $(PROFILE_FLAGS) 2>&1 \
		| tee $(BUILD_DIR)/sim-profile.log | grep -E '^SIM_PROFILE|^MATCH_RESULT' | cut -c1-2000 > $(BUILD_DIR)/sim-profile.lines
	$(PYTHON) tools/sim_profile_report.py $(BUILD_DIR)/sim-profile.log $(BUILD_DIR)/sim-profile.json

# ---- X1 (round 5): the shape of a full-scale fight ----------------------------------
engagement: import ## X1: engagement ranges, standing exchanges, kill faces, cover use in faction battles (PAIRS=condemned:condemned SEEDS=4 TIME=240 ARENA= TUNE=) -> build/engagement.json
	$(PYTHON) tools/engagement_report.py --godot $(GODOT) --jobs $(JOBS) --pairs $(or $(PAIRS),condemned:condemned) \
		--seeds $(or $(SEEDS),4) --budget $(or $(BUDGET),5200) --time-limit $(or $(TIME),240) \
		$(if $(ARENA),--arena $(ARENA)) $(if $(TUNE),--tune $(TUNE)) --json $(BUILD_DIR)/engagement.json

pace: import ## Match pace with seeded CPU armies like a skirmish (first shot, first kill, length): N=24 BUDGET=1000 CONTROL=1 -> build/pace[-control].json
	$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),24) --jobs $(JOBS) --time-limit 300 --score-limit 0 \
		--json $(BUILD_DIR)/pace$(if $(CONTROL),-control).json \
		--extra="--green-doctrine=cpu --rust-doctrine=cpu --elimination --budget=$(or $(BUDGET),1000) $(if $(CONTROL),--control)"
