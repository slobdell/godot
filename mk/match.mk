# Match runner and AI experiments
# Owner: gameplay (see _agents/workstreams.md). Included by the root Makefile.

# ---- Match runner (headless bots vs bots, faster than real time) ----------------
# --fixed-fps $(SIM_HZ) makes every frame advance exactly 1/60 s of game time without
# waiting for the wall clock, so matches run as fast as the CPU allows.

match: import ## One headless match: GREEN=1 RUST=1 SCORE=5 TIME=300 SEED=1; prints MATCH_RESULT JSON
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --green=$(GREEN) --rust=$(RUST) \
		--score-limit=$(SCORE) --time-limit=$(TIME) --seed=$(SEED) | grep MATCH_RESULT

matches: import ## N seeded matches in parallel with a win-rate summary (N=10 JOBS=4, same knobs as match)
	$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(N) --jobs $(JOBS) --green $(GREEN) \
		--rust $(RUST) --score-limit $(SCORE) --time-limit $(TIME) --json $(BUILD_DIR)/matches.json

determinism: import ## Same seed + same doctrines twice → byte-identical match results (experiment T0)
	mkdir -p $(BUILD_DIR)
	for run in 1 2; do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --green-doctrine=res://doctrines/anvil_hammer.json \
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
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --green=2 --rust=2 --score-limit=3 --time-limit=120 --seed=7 \
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

# VARIANT_FILE and SEARCH_UNITS, not VARIANTS and UNITS: see the note on `engagement` below. BOTH collided with
# mk/ai.mk's defaults, and both took it silently — this target would search the three ai-ladder brain names instead of
# the file you meant, and would always pass `--units 60` because `UNITS ?= 60` is live in every included makefile.
matchup-search: import ## Score --tune variants of the matchup matrix against the designed counters: VARIANT_FILE=tools/matchup_variants/<file>.json [SEARCH_UNITS= SEEDS=2 ESCORT=]
	$(PYTHON) tools/matchup_search.py --godot $(GODOT) --jobs $(JOBS) --variants $(VARIANT_FILE) --seeds $(or $(SEEDS),2) \
		$(if $(SEARCH_UNITS),--units $(SEARCH_UNITS)) $(if $(ESCORT),--escort $(ESCORT))

# ---- Round 9: why is nothing landing on the engine deck? ------------------------
# `Armor.is_weak_spot` is two directions and a dot product against cos(25 deg): NO position, NO hull size. So a deck
# hit cannot have gone missing because CP2 made hulls bigger, and "0 of 13 on the deck" is unexplained rather than a
# stale marker. This prints three columns per enemy hit and aggregates their DISTRIBUTION -- deliberately not a
# verdict, because three different owners are plausible and they are told apart by which column is wrong:
#   travel angles never enter the 25 deg cone      -> the scout never gets astern (a positioning question)
#   angles enter the cone but weak_spot is false    -> the flag is wrong (combat's)
#   the shooter's BEARING never gets behind         -> it never works round at all (a brain/pursuit question)

deck-angles: import ## Round 9: per-hit travel angle, shooter bearing and range for a scout hunting a tank, and their distribution (DECK_GREEN=scout DECK_RUST=tank SEED=1 DECK_TIME=25) -> build/deck-angles.json
	@echo ">> deck-angles: $(or $(DECK_GREEN),scout) vs $(or $(DECK_RUST),tank), seed $(SEED), $(or $(DECK_TIME),25) s"
	@mkdir -p $(BUILD_DIR)
	$(PYTHON) tools/combat_duel.py --godot $(GODOT) --green $(or $(DECK_GREEN),scout) --rust $(or $(DECK_RUST),tank) \
		--seed $(or $(SEED),1) --time-limit $(or $(DECK_TIME),25) --tune probe.deck=1 \
		2>&1 | tee $(BUILD_DIR)/deck-angles.log > /dev/null
	@$(PYTHON) -c "import json,sys; \
		rows=[json.loads(l.split('DECK_HIT ',1)[1]) for l in open('$(BUILD_DIR)/deck-angles.log') if 'DECK_HIT ' in l]; \
		json.dump(rows, open('$(BUILD_DIR)/deck-angles.json','w'), indent=1); \
		print('deck-angles: no enemy hits at all -- the control fired nothing, which proves nothing') if not rows else None; \
		sys.exit(0) if not rows else None; \
		band=lambda v,e: sum(1 for r in rows if e[0] <= r[v] < e[1]); \
		edges=[(0,25),(25,45),(45,90),(90,135),(135,181)]; \
		print('%d enemy hits; weak_spot flagged on %d' % (len(rows), sum(1 for r in rows if r['weak_spot']))); \
		print('travel angle (Armor.is_weak_spot fires under %.0f deg):' % rows[0]['arc_deg']); \
		[print('  %3d-%3d deg: %3d' % (e[0], e[1], band('travel_deg', e))) for e in edges]; \
		print('shooter bearing from the victim nose (180 = dead astern):'); \
		[print('  %3d-%3d deg: %3d' % (e[0], e[1], band('bearing_deg', e))) for e in edges]; \
		rs=sorted(r['range_m'] for r in rows); \
		print('range m: min %.1f  median %.1f  max %.1f' % (rs[0], rs[len(rs)//2], rs[-1]))"

# ---- X1 (round 9): is A2's switching cost actually an arm? ----------------------
# Lesson 117: round 8 shipped a commitment term into a code path that could never reach it and measured it twice.
# This proves the cost is consulted, non-zero, and DIFFERENT by hull class before anything is A/B-ed with it.
# NAMED ARCHETYPES, not a seeded "cpu" draft: the probe's claim is that both ends of the roster are on the field, and
# seed 3 drew `gang_hail`, which fields no War Rig at all -- the rig-vs-rat-rod number could not have been read from
# that run however healthy it looked. `gang_ram` fields two rigs and a rat rod; `law_line` is the counterpart.

switch-arm: import ## X1 (A2): is the switching cost consulted, and does it vary by hull class? Per-class/locomotion arm counter over one fight (ARENA=yard SEED=3 SWITCH_TIME=120 BUDGET=6500 SWITCH_GREEN_ARMY=gang_ram fields the War Rig, SWITCH_RUST_ARMY=law_line; TUNE=switch.cost=1 selects A2; default is the flat bonus) -> build/switch-arm.json
	@echo ">> switch-arm: ARENA=$(or $(ARENA),yard) SEED=$(or $(SEED),3) SWITCH_TIME=$(or $(SWITCH_TIME),120) TUNE=$(TUNE)"
	@mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/combat/switch_probe.gd -- \
		--arena=$(or $(ARENA),yard) --seed=$(or $(SEED),3) --time-limit=$(or $(SWITCH_TIME),120) \
		--budget=$(or $(BUDGET),6500) --green=$(or $(SWITCH_GREEN),gangs) --rust=$(or $(SWITCH_RUST),law) \
		--green-army=$(or $(SWITCH_GREEN_ARMY),gang_ram) --rust-army=$(or $(SWITCH_RUST_ARMY),law_line) \
		--require=$(or $(SWITCH_REQUIRE),gang_tank) $(if $(SWITCH_EVENTS),--switch-events=$(CURDIR)/$(SWITCH_EVENTS)) \
		$(if $(TRAJECTORY),--trajectory=$(CURDIR)/$(TRAJECTORY)) \
		$(if $(TUNE),--tune=$(TUNE)) 2>&1 | tee $(BUILD_DIR)/switch-arm.log | grep -E "SWITCH_ARM|SCRIPT ERROR|ERROR" || true
	@$(PYTHON) -c "import json,sys; \
		raw=open('$(BUILD_DIR)/switch-arm.log').read(); \
		sys.exit('switch-arm: the probe printed no SWITCH_ARM line') if 'SWITCH_ARM ' not in raw else None; \
		d=json.loads(raw.split('SWITCH_ARM ')[1].splitlines()[0]); \
		json.dump(d, open('$(BUILD_DIR)/switch-arm.json','w'), indent=1); \
		print('switch-arm:', d['spread']['dearest'], d['spread']['dearest_s'], 's vs', d['spread']['cheapest'], d['spread']['cheapest_s'], 's (x%s)' % d['spread']['ratio'])"

switch-arms: import ## X2 (A2): the churn A/B over the three arms (flat = default / cost = A2 / none)  and SWITCH_SEEDS, per class AND per locomotion, with the spread across seeds beside every mean (ARENA=yard SWITCH_SEEDS=1,3,7 SWITCH_TIME=120 JOBS=2) -> build/switch-arms.json
	@echo ">> switch-arms: ARENA=$(or $(ARENA),yard) SWITCH_SEEDS=$(or $(SWITCH_SEEDS),1,3,7) SWITCH_TIME=$(or $(SWITCH_TIME),120)"
	@mkdir -p $(BUILD_DIR)
	$(PYTHON) tools/switch_arms.py --godot $(GODOT) --arena $(or $(ARENA),yard) --seeds $(or $(SWITCH_SEEDS),1,3,7) \
		--seconds $(or $(SWITCH_TIME),120) --budget $(or $(BUDGET),6500) --jobs $(JOBS) \
		--green-army $(or $(SWITCH_GREEN_ARMY),gang_ram) --rust-army $(or $(SWITCH_RUST_ARMY),law_line) \
		--require $(or $(SWITCH_REQUIRE),gang_tank) $(if $(SWITCH_ARMS),--arms $(SWITCH_ARMS)) \
		--json $(BUILD_DIR)/switch-arms.json

# ---- X2 (round 4): does suppression change outcomes? ----------------------------
# Every weapon's "suppression" set to 0 is the control: the threat field stays empty, nobody is ever pinned, and
# spread loses its suppression term. A volume weapon (the scout's machine gun) should be worth MORE with it on.
SUPPRESSION_OFF := --tune=machine_gun.suppression=0,autocannon.suppression=0,cannon.suppression=0,laser.suppression=0,mortar.suppression=0,flamethrower.suppression=0

suppression-series: import ## X2: one archetype vs another with suppression on, then off (GREEN_ARCH=swarm RUST_ARCH=armor N=16 BUDGET=1000)
	@for mode in on off; do 		echo "== suppression $$mode =="; 		$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),16) --jobs $(JOBS) --time-limit 300 --score-limit 0 			--json $(BUILD_DIR)/suppression-$$mode.json 			--extra="--green-doctrine=cpu:$(or $(GREEN_ARCH),swarm) --rust-doctrine=cpu:$(or $(RUST_ARCH),armor) --elimination --budget=$(or $(BUDGET),1000) $$([ $$mode = off ] && echo '$(SUPPRESSION_OFF)')"; 	done

suppression-control: import ## X2: the same pairing counterbalanced (bases and colors swapped), suppression on then off
	@for mode in on off; do 		for swap in "" "--swap-bases"; do 			echo "== suppression $$mode $$swap =="; 			$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),16) --jobs $(JOBS) --time-limit 300 --score-limit 0 				--extra="--green-doctrine=cpu:$(or $(GREEN_ARCH),swarm) --rust-doctrine=cpu:$(or $(RUST_ARCH),armor) --elimination --budget=$(or $(BUDGET),1000) $$swap $$([ $$mode = off ] && echo '$(SUPPRESSION_OFF)')"; 			echo "== suppression $$mode $$swap, colors swapped =="; 			$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),16) --jobs $(JOBS) --time-limit 300 --score-limit 0 				--extra="--green-doctrine=cpu:$(or $(RUST_ARCH),armor) --rust-doctrine=cpu:$(or $(GREEN_ARCH),swarm) --elimination --budget=$(or $(BUDGET),1000) $$swap $$([ $$mode = off ] && echo '$(SUPPRESSION_OFF)')"; 		done; 	done

faction-match: import ## L3: one full-scale faction battle (GREEN_FACTION=condemned RUST_FACTION=gangs SEED=1), prints MATCH_RESULT
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control 		--green-faction=$(or $(GREEN_FACTION),condemned) --rust-faction=$(or $(RUST_FACTION),condemned) 		--budget=$(or $(BUDGET),5200) --time-limit=$(or $(TIME),300) --seed=$(SEED) | grep MATCH_RESULT

faction-series: import ## L3: N seeded faction battles at the baseline budget (GREEN_FACTION= RUST_FACTION= N=12 BUDGET=5200)
	$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),12) --jobs $(JOBS) --time-limit 300 --score-limit 0 		--json $(BUILD_DIR)/faction-$(or $(GREEN_FACTION),condemned)-vs-$(or $(RUST_FACTION),condemned).json 		--extra="--green-faction=$(or $(GREEN_FACTION),condemned) --rust-faction=$(or $(RUST_FACTION),condemned) --elimination --control --budget=$(or $(BUDGET),5200)"

# ---- X5 (round 4): what does the simulation cost at scale? -----------------------
# One headless match per size, run as fast as the machine allows. MATCH_RESULT's `speedup` is simulated seconds per
# real second, so ms/tick = 1000 / (60 x speedup). Run it WITHOUT brains for the simulation's own cost (this stream
# owns that) and WITH them for the whole picture (ai owns the difference). Heavy: use `make remote T=scale-bench`.
SCALE_SIZES ?= 25 40 60 100

scale-bench: import ## X5: sim cost per tick at SCALE_SIZES vehicles a side, with and without brains (BENCH_FACTION= TIME=60)
	@printf '%-8s %-8s %-10s %-10s %s\n' "a side" "brains" "speedup" "ms/tick" "budget at 60 fps = 16.7 ms"
	@for size in $(SCALE_SIZES); do 		for brains in off on; do 			$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --bench-units=$$size 				--bench-faction=$(or $(BENCH_FACTION),condemned) --time-limit=$(or $(TIME),60) --score-limit=0 --seed=5 				$$([ $$brains = off ] && echo --no-brains) 2>/dev/null | grep MATCH_RESULT 				| $(PYTHON) -c "import json,sys; r=json.loads(sys.stdin.read().split('MATCH_RESULT ')[1]); 					print('%-8s %-8s %-10.1f %-10.3f' % ('$$size', '$$brains', r['speedup'], 1000.0/($(SIM_HZ).0*r['speedup'])))"; 		done; 	done

# ARENA= names the layout. WITHOUT it every match runs on foundry, which is fine for a like-for-like A/B and wrong
# for anything conditional on terrain -- the Syndicate's designator pays off where sightlines are long and pays
# nothing in a close map, so a single-map number would be read as a property of the faction.
# X4 (round 7): ABLATE=1 is the control arm -- every unit on its plain-role directive instead of its faction's.
# The flag and the OUTPUT NAME are set from one variable on purpose: two arms writing one filename is how a control
# silently overwrites its treatment and leaves a single file that looks like both runs.
# The comparison step is where this stream's measurements have gone wrong, not the running step: a filtered arm
# against a full one, a laptop arm against a builder0 one, and a control that differed from its treatment only in
# the name of its file. `compare_arms` refuses those, and refuses the one nobody finds by reading output -- two
# arms that are secretly the same arm, whose difference is a clean and entirely plausible null.
match-pytest: ## The match tools' own tests: what compare_arms refuses to subtract, and why
	$(PYTHON) -m unittest discover -s tools -p 'test_compare_arms.py'
	$(PYTHON) -m unittest discover -s tools -p 'test_paired_arms.py'

# Round 10 (combat, stretch: A2's verdict). Both switching arms on the same seeds, each fight's trajectory logged, then
# metrics' cusp split per arm. The pre-registered reading (round 9): `tank` decides it -- tracked hulls make no creep
# cusps, so its unexplained cusps are decisions; if A2's excess reversals show up there, A2 stays off.
A2_SEEDS ?= 1 2 3 4 5 6
a2-cusps: import ## A2's verdict: switch-arm with trajectories on both arms (flat default, switch.cost=1) over A2_SEEDS, then make metrics per arm
	@mkdir -p $(BUILD_DIR)/metrics/a2
	for seed in $(A2_SEEDS); do \
		$(MAKE) --no-print-directory switch-arm SEED=$$seed TRAJECTORY=$(BUILD_DIR)/metrics/a2/flat-$$seed.jsonl || exit 1; \
		$(MAKE) --no-print-directory switch-arm SEED=$$seed TUNE=switch.cost=1 TRAJECTORY=$(BUILD_DIR)/metrics/a2/cost-$$seed.jsonl || exit 1; \
	done
	$(MAKE) --no-print-directory metrics LOGS="$(BUILD_DIR)/metrics/a2/flat-*.jsonl" METRICS_JSON=$(BUILD_DIR)/metrics/a2/flat.json
	$(MAKE) --no-print-directory metrics LOGS="$(BUILD_DIR)/metrics/a2/cost-*.jsonl" METRICS_JSON=$(BUILD_DIR)/metrics/a2/cost.json
	@# ~100 MB per 120 s fight: keep the two per-arm JSONs, not the logs (make remote copies build/ back).
	rm -f $(BUILD_DIR)/metrics/a2/*.jsonl

# Round 10 (combat, item 6; research C6/C7): the gangs-vs-law series, ONE disc site at a time. Four arms on the SAME
# seed list, both colours, one map per invocation (each stays under slot.sh's 90-minute kill): the control (the disc at
# every site, today's default), the box at the friendly-fire line-of-fire site only, at the incoming-projectile site
# only, and at both (C7's pre-registered arm). Each treatment is compared with the control per game (paired-arms);
# every match proves its arm through `controls.tuning` (faction_matrix refuses a run that did not carry it).
# SEEDS=32 is ~64 games per arm per map; `make remote T="disc-site-series ARENA=pit"`.
DISC_SITE_ARMS := lof=match.hull_disc_lof=0 incoming=match.hull_disc_incoming=0 both=match.hull_disc_lof=0,match.hull_disc_incoming=0
disc-site-series: import ## Item 6: gangs vs law, the disc site by site, paired seeds (ARENA=pit|yard SEEDS=32 TIME=180)
	@test -n "$(ARENA)" || { echo "disc-site-series: ARENA= is required (one map per run)"; exit 2; }
	$(PYTHON) tools/faction_matrix.py --godot $(GODOT) --jobs $(JOBS) --seeds $(or $(SEEDS),32) --factions gangs,law \
		--budget $(or $(BUDGET),5200) --time-limit $(or $(TIME),180) --arena $(ARENA) \
		--json $(BUILD_DIR)/disc-series-$(ARENA)-control.json
	for arm in $(DISC_SITE_ARMS); do \
		label=$${arm%%=*}; tune=$${arm#*=}; \
		$(PYTHON) tools/faction_matrix.py --godot $(GODOT) --jobs $(JOBS) --seeds $(or $(SEEDS),32) --factions gangs,law \
			--budget $(or $(BUDGET),5200) --time-limit $(or $(TIME),180) --arena $(ARENA) --tune $$tune \
			--json $(BUILD_DIR)/disc-series-$(ARENA)-$$label.json || exit 1; \
		$(PYTHON) tools/paired_arms.py --treatment $(BUILD_DIR)/disc-series-$(ARENA)-$$label.json \
			--control $(BUILD_DIR)/disc-series-$(ARENA)-control.json \
			--json $(BUILD_DIR)/disc-series-$(ARENA)-$$label-paired.json || exit 1; \
	done

# Round 10 (research C6): two arms on the SAME seeds compared game by game (discordant pairs, exact McNemar), never
# as two pooled rates. Needs faction-matrix JSONs from this round's tool (they carry `games`).
paired-arms: ## Two faction-matrix runs on the same seeds, paired per game (TREATMENT=a.json CONTROL=b.json)
	$(PYTHON) tools/paired_arms.py --treatment $(TREATMENT) --control $(CONTROL) \
		$(if $(BUILD_ARM),--build-is-the-arm '$(BUILD_ARM)')

# Both arms on every map in ARENAS, in ONE remote invocation. Four separate `make remote` calls would rsync the
# worktree four times into the same folder on builder0 while earlier runs were still reading it, and would queue for
# a heavy-run slot four times; this syncs once and holds one slot. It also runs the comparison itself, so the arms
# are subtracted by the tool that refuses bad subtractions rather than by eye afterwards.
faction-matrix-arms: import ## Both arms (normal + ABLATE) on each map in ARENAS= and the per-faction deltas
	@for map in $(or $(ARENAS),boulevard yard); do \
		$(MAKE) --no-print-directory faction-matrix ARENA=$$map SEEDS=$(SEEDS) TIME=$(TIME) JOBS=$(JOBS) BUDGET=$(BUDGET) || exit 1; \
		$(MAKE) --no-print-directory faction-matrix ARENA=$$map ABLATE=1 SEEDS=$(SEEDS) TIME=$(TIME) JOBS=$(JOBS) BUDGET=$(BUDGET) || exit 1; \
		echo ""; echo "=== $$map: faction directives ON minus OFF ==="; \
		$(MAKE) --no-print-directory compare-arms TREATMENT=$(BUILD_DIR)/faction-matrix-$$map.json \
			CONTROL=$(BUILD_DIR)/faction-matrix-$$map-plainroles.json || exit 1; \
	done

# COMPARE_FACTION, not FACTION: `mk/command.mk` defines `FACTION ?= gangs` and make variables are ONE GLOBAL
# NAMESPACE, so the bare name silently filtered every comparison to the gangs -- the same collision that ran
# `matchup-search` at `--units 60` for its entire history. Caught by reading a `make -n` expansion that contained
# a flag nobody passed.
compare-arms: ## Two faction-matrix runs, subtracted per faction (TREATMENT=a.json CONTROL=b.json [COMPARE_FACTION=gangs] [BUILD_ARM="what changed"])
	$(PYTHON) tools/compare_arms.py --treatment $(TREATMENT) --control $(CONTROL) \
		$(if $(COMPARE_FACTION),--faction $(COMPARE_FACTION)) \
		$(if $(BUILD_ARM),--build-is-the-arm $(BUILD_ARM))

# THE OUTPUT NAME CARRIES THE ARM. `-tuned` was the suffix for ANY value of TUNE, so the obvious two-run
# series -- control, then `TUNE=switch.cost=1` -- wrote both arms to one file: the second overwrote the
# first, and `compare-arms` then compared a file with itself and reported a perfect null, every cell zero,
# with nothing saying so (combat, 2026-09-20). **A null that looks like a measurement is the one kind of bug
# that running more of them cannot catch**, because every extra run reproduces it.
#
# So the TUNE spec is in the filename, sanitised, and `OUT=<label>` overrides the whole basename when a
# series wants its own names. `compare-arms` refuses byte-identical inputs as a second line of defence.
_empty :=
_space := $(_empty) $(_empty)
_comma := ,
_TUNE_SLUG := $(subst $(_space),,$(subst /,_,$(subst $(_comma),-,$(subst =,_,$(TUNE)))))
FACTION_MATRIX_NAME := $(if $(OUT),$(OUT),faction-matrix$(if $(ARENA),-$(ARENA))$(if $(ABLATE),-plainroles)$(if $(TUNE),-tuned-$(_TUNE_SLUG)))

faction-matrix: import ## X6: every faction pair at the baseline budget, counterbalanced (SEEDS=6 BUDGET=5200 TIME=180 ARENA= ABLATE= TUNE=switch.cost=1 OUT=<label>) -> build/$(FACTION_MATRIX_NAME).json; the TUNE spec is IN the name, so two arms cannot overwrite each other
	$(PYTHON) tools/faction_matrix.py --godot $(GODOT) --jobs $(JOBS) --seeds $(or $(SEEDS),6) \
		--budget $(or $(BUDGET),5200) --time-limit $(or $(TIME),180) $(if $(ARENA),--arena $(ARENA)) \
		$(if $(ABLATE),--no-faction-directives) $(if $(TUNE),--tune $(TUNE)) \
		--json $(BUILD_DIR)/$(FACTION_MATRIX_NAME).json
	@echo ">> faction-matrix wrote $(BUILD_DIR)/$(FACTION_MATRIX_NAME).json -- the arm is in the name; a second arm with a different TUNE or OUT cannot overwrite it"

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
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control --sim-profile \
		--green-faction=$(or $(GREEN_FACTION),condemned) --rust-faction=$(or $(RUST_FACTION),condemned) \
		--budget=$(or $(BUDGET),5200) --time-limit=$(or $(TIME),90) --seed=$(or $(SEED),3) $(PROFILE_FLAGS) 2>&1 \
		| tee $(BUILD_DIR)/sim-profile.log | grep -E '^SIM_PROFILE|^MATCH_RESULT' | cut -c1-2000 > $(BUILD_DIR)/sim-profile.lines
	$(PYTHON) tools/sim_profile_report.py $(BUILD_DIR)/sim-profile.log $(BUILD_DIR)/sim-profile.json

# ---- Round 5: is team identity worth wins? --------------------------------------------
# Arena measured Green winning 25-28% of seeded mirror battles on every map, bases swapped. The controls: the normal
# run, the same seeds with the ARMIES swapped between the teams (pairs cancel army strength), a true mirror (both teams
# field one army), and the mirror again with Rust processed first and with bases swapped.
team-fairness: import ## Green's win rate under army/base/order controls (FAIR_FACTION=condemned N=16 FIRST_SEED=1 TIME=240 FAIR_MODES="normal|--swap-armies|--same-army|--same-army --rust-first|--same-army --swap-bases")
	@modes='$(or $(FAIR_MODES),normal|--swap-armies|--same-army|--same-army --rust-first|--same-army --swap-bases)'; \
	IFS='|'; for mode in $$modes; do \
		unset IFS; flags=$$([ "$$mode" = normal ] || echo "$$mode"); \
		echo "== team fairness: $(or $(FAIR_FACTION),condemned) mirror, controls '$$mode', seeds $(or $(FIRST_SEED),1)+ =="; \
		$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),16) --first-seed $(or $(FIRST_SEED),1) --jobs $(JOBS) \
			--time-limit $(or $(TIME),240) --score-limit 0 \
			--json $(BUILD_DIR)/team-fairness-$$(echo "$$mode" | tr -d ' -')-$(or $(FIRST_SEED),1).json \
			--extra="--green-faction=$(or $(FAIR_FACTION),condemned) --rust-faction=$(or $(FAIR_FACTION),condemned) --elimination --control --budget=$(or $(BUDGET),5200) $$flags" \
			| grep -E "matches|wins:"; \
		IFS='|'; \
	done

# ---- X1 (round 5): the shape of a full-scale fight ----------------------------------
# VARIANT_FILE, not VARIANTS: mk/ai.mk defaults `VARIANTS ?= r1,a4,a6` (brain-variant NAMES for the ai ladder), and
# make has one global namespace, so `$(if $(VARIANTS),...)` here was always true and always wrong. `make engagement`
# fed those three names to a flag that wants a JSON path and died on FileNotFoundError — including the exact command
# streams/references/combat/README.md tells you to reproduce the round-5 baseline with. One variable name meaning two
# things in two makefiles is the bug; the fix is a name of our own (round 6, N5).
engagement: import ## X1: engagement ranges, standing exchanges, kill faces, cover use in faction battles (PAIRS=condemned:condemned SEEDS=4 TIME=240 ARENA= TUNE= VARIANT_FILE=tools/matchup_variants/<file>.json) -> build/engagement[-variants].json
	$(PYTHON) tools/engagement_report.py --godot $(GODOT) --jobs $(JOBS) --pairs $(or $(PAIRS),condemned:condemned) \
		--seeds $(or $(SEEDS),4) --budget $(or $(BUDGET),5200) --time-limit $(or $(TIME),240) \
		$(if $(ARENA),--arena $(ARENA)) $(if $(TUNE),--tune $(TUNE)) $(if $(VARIANT_FILE),--variants $(VARIANT_FILE)) \
		--json $(BUILD_DIR)/engagement$(if $(VARIANT_FILE),-variants).json

pace: import ## Match pace with seeded CPU armies like a skirmish (first shot, first kill, length): N=24 BUDGET=1000 CONTROL=1 -> build/pace[-control].json
	$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(or $(N),24) --jobs $(JOBS) --time-limit 300 --score-limit 0 \
		--json $(BUILD_DIR)/pace$(if $(CONTROL),-control).json \
		--extra="--green-doctrine=cpu --rust-doctrine=cpu --elimination --budget=$(or $(BUDGET),1000) $(if $(CONTROL),--control)"
