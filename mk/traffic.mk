# Round 26 (traffic): friendly vehicles deconflicting. T0's instrument is tests/traffic/traffic_stage.gd (his two cases:
# two friendly squads ordered through each other head-on, and across each other at right angles), run over
# TRAFFIC_CASES (arena,kind) x {both, solo_a, solo_b} x TRAFFIC_SEEDS x TRAFFIC_TICKS (C26.6's start ticks), TRAFFIC_JOBS at
# a time. The table pools them: crews arrived, friendly-stuck crew-seconds, friendly contacts (and fast ones), k-turns
# with a friendly ahead, and the crossing's last arrival over the same squad's solo time (paired by seed and tick).
# TRAFFIC_FLAGS adds probe flags (--brains-off=native, --nav-off=...). Run it on builder0: make remote T=traffic-series.
# Round 29 (I3): each row is cached by (the tree's content hash, its own arguments) in tools/series_cache.sh's shared
# directory and reused only on an exact key match ("cache hit" per row) when CACHE=on. OFF by default until its proof
# (a cached base row equal to a fresh one, field for field) is run: owed (traffic Status).
# Round 31 (I4, C31.7): the cache is ADOPTED for BASE rows: CACHE=auto (the default) reuses rows when TRAFFIC_FLAGS is
# empty (the base arm) and runs every row of a flagged arm fresh; CACHE=on / CACHE=off force it. Every row is still put.
# Round 31 (I4, C31.3): the early-stop hook. SEQ_BASE=<base jsonl> SEQ_LINES='<case>=<line>,<line> <case>=...' (the bar's
# pre-registered lines, tools/judge/sequential.py's form + `allow=`, tests/traffic/seq_hook.py) [SEQ_COUNTER=tr_cross_verdicts]
# prints `SEQ <case> k/N: ... -> SERIES CONTINUE | PASS | FAIL at run j` after every finished row, over the longest finished
# prefix of the grid in the runner's order. The jobs run seed-major, start tick minor, every case together, so all cases
# advance as one. The runner never stops itself: the stream stops by judging.md's one rule and records the row.

TRAFFIC_CASES ?= yard_open,head yard_open,cross terminus,head terminus,cross
TRAFFIC_SEEDS ?= 1 2 3
TRAFFIC_TICKS ?= 1 3 6 8 11 16
TRAFFIC_WHICH ?= both solo_a solo_b
TRAFFIC_JOBS ?= 6
TRAFFIC_SECONDS ?= 90
TRAFFIC_OUT ?= $(BUILD_DIR)/traffic-series.jsonl
CACHE ?= auto
SEQ_BASE ?=
SEQ_LINES ?=
SEQ_COUNTER ?=
SEQ_CENSUS_LINES ?=
# on for a base arm (no flags) under auto
TRAFFIC_CACHE_ON = $(if $(filter on,$(CACHE)),on,$(if $(filter auto,$(CACHE)),$(if $(strip $(TRAFFIC_FLAGS)),off,on),off))

.PHONY: traffic-series
traffic-series: import ## Round 26 (traffic T0): his two crossing cases (TRAFFIC_CASES arena,kind x both/solo x seeds x start ticks) -> build/traffic-series.jsonl + the pooled table (TRAFFIC_FLAGS for an arm)
	@rm -rf $(BUILD_DIR)/traffic-runs; mkdir -p $(BUILD_DIR)/traffic-runs
	@echo ">> traffic-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | flags '$(TRAFFIC_FLAGS)' | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@tree=$$(tools/series_cache.sh tree); echo ">> traffic-series cache: $(if $(filter on,$(TRAFFIC_CACHE_ON)),ON (exact-key rows reused),OFF (every row runs)) [CACHE=$(CACHE)] | tree $$tree"; \
	$(if $(SEQ_BASE),echo ">> traffic-series early-stop hook: base $(SEQ_BASE) | lines '$(SEQ_LINES)' | counter '$(SEQ_COUNTER)'";) \
	for seed in $(TRAFFIC_SEEDS); do for tick in $(TRAFFIC_TICKS); do for case in $(TRAFFIC_CASES); do for which in $(TRAFFIC_WHICH); do \
		echo "$$case,$$which,$$seed,$$tick"; done; done; done; done | \
		TREE=$$tree xargs -P $(TRAFFIC_JOBS) -I{} sh -c 'set -- $$(echo {} | tr "," " "); arena=$$1; kind=$$2; which=$$3; seed=$$4; tick=$$5; \
		out=$(BUILD_DIR)/traffic-runs/$$arena-$$kind-$$which-$$seed-$$tick.json; \
		key=$$(tools/series_cache.sh key "$$TREE" traffic-series $$arena $$kind $$which $$seed $$tick $(TRAFFIC_SECONDS) "$(TRAFFIC_FLAGS)"); \
		if [ "$(TRAFFIC_CACHE_ON)" = on ] && tools/series_cache.sh get $$key $$out; then echo "  cache hit  $$arena $$kind $$which s$$seed t$$tick ($$key)"; \
		else \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/traffic/traffic_probe.gd -- \
			--arena=$$arena --kind=$$kind --which=$$which --seed=$$seed --seconds=$(TRAFFIC_SECONDS) --lab-start-tick=$$tick \
			$(TRAFFIC_FLAGS) 2>/dev/null | grep -o "TRAFFIC_PROBE {.*" | sed "s/^TRAFFIC_PROBE {/{\"start_tick\":$$tick,/" > $$out; \
		[ -s $$out ] \
			|| echo "{\"arena\":\"$$arena\",\"kind\":\"$$kind\",\"which\":\"$$which\",\"seed\":$$seed,\"start_tick\":$$tick,\"missing\":true}" > $$out; \
		tools/series_cache.sh put $$key $$out; echo "  ran        $$arena $$kind $$which s$$seed t$$tick"; fi; \
		$(if $(SEQ_BASE),[ "$$which" = both ] && $(PYTHON) tests/traffic/seq_hook.py series --base $(SEQ_BASE) --runs $(BUILD_DIR)/traffic-runs --lines "$(SEQ_LINES)" $(if $(SEQ_COUNTER),--counter $(SEQ_COUNTER)) | sed "s/^/  /";) true'
	@echo ">> traffic-series rows: $$(ls $(BUILD_DIR)/traffic-runs/*.json | wc -l)"
	@cat $(BUILD_DIR)/traffic-runs/*.json > $(TRAFFIC_OUT)
	@$(PYTHON) tests/traffic/traffic_table.py $(TRAFFIC_OUT)
	@$(if $(SEQ_BASE),echo ">> traffic-series early-stop reading over the whole grid:"; $(PYTHON) tests/traffic/seq_hook.py series --base $(SEQ_BASE) --runs $(BUILD_DIR)/traffic-runs --lines "$(SEQ_LINES)" $(if $(SEQ_COUNTER),--counter $(SEQ_COUNTER)),true)

.PHONY: traffic-trace
traffic-trace: import ## Round 26 (traffic): one traced run of his case (TRAFFIC_ARENA=yard_open TRAFFIC_KIND=head TRAFFIC_SEED=1) -> build/traffic-trace.log (TRAFFIC_TRACK lines every 0.5 s)
	@mkdir -p $(BUILD_DIR)
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/traffic/traffic_probe.gd -- \
		--arena=$(or $(TRAFFIC_ARENA),yard_open) --kind=$(or $(TRAFFIC_KIND),head) --which=$(or $(TRAFFIC_WHICH_ONE),both) \
		--seed=$(or $(TRAFFIC_SEED),1) --seconds=$(TRAFFIC_SECONDS) --trace=on $(TRAFFIC_FLAGS) > $(BUILD_DIR)/traffic-trace.log 2>&1 || true
	@grep -o 'TRAFFIC_PROBE {.*' $(BUILD_DIR)/traffic-trace.log || (tail -30 $(BUILD_DIR)/traffic-trace.log && exit 1)

# Round 26 (traffic T1/T3): the clump census. CPU v CPU fights (both sides under the computer's squad leaders, set up as
# army-series does) over TRAFFIC_CENSUS_CASES (arena,green,rust,credits,army) x TRAFFIC_CENSUS_SEEDS: every crew-second a
# crew under way sat still, by what was in its way (friendly / enemy / static), friendly contacts, friendly k-turns.
# Default: the Sumps at 1000 credits a side (~25: his skirmish) and the army series' two maps at 2000 (ten squads).
TRAFFIC_CENSUS_CASES ?= sumps,law,gangs,1000,opponent parade,gangs,law,2000,opponent foundry,condemned,syndicate,2000,opponent
TRAFFIC_CENSUS_SEEDS ?= 1 2 3
TRAFFIC_CENSUS_SECONDS ?= 150
.PHONY: traffic-census
traffic-census: import ## Round 26 (traffic T1): stuck crew-seconds by what is in the way (friendly/enemy/static) in CPU v CPU fights, TRAFFIC_CENSUS_CASES x TRAFFIC_CENSUS_SEEDS -> build/traffic-census.jsonl + table (TRAFFIC_FLAGS for an arm)
	@rm -rf $(BUILD_DIR)/traffic-census-runs; mkdir -p $(BUILD_DIR)/traffic-census-runs
	@echo ">> traffic-census on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | flags '$(TRAFFIC_FLAGS)' | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@$(if $(SEQ_BASE),echo ">> traffic-census early-stop hook: base $(SEQ_BASE) | lines '$(SEQ_CENSUS_LINES)'";) \
	for seed in $(TRAFFIC_CENSUS_SEEDS); do for case in $(TRAFFIC_CENSUS_CASES); do echo "$$case,$$seed"; done; done | \
		xargs -P $(TRAFFIC_JOBS) -I{} sh -c 'set -- $$(echo {} | tr "," " "); out=$(BUILD_DIR)/traffic-census-runs/$$1-$$2-$$3-$$4-$$6.json; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/traffic/census_probe.gd -- \
			--arena=$$1 --green=$$2 --rust=$$3 --credits=$$4 --army=$$5 --seed=$$6 --seconds=$(TRAFFIC_CENSUS_SECONDS) $(TRAFFIC_FLAGS) \
			2>/dev/null > $$out.log; grep -o "TRAFFIC_CENSUS {.*" $$out.log | sed "s/^TRAFFIC_CENSUS //" > $$out; \
		grep -o "TRAFFIC_ASKER {.*" $$out.log | sed "s/^TRAFFIC_ASKER //;s/^{/{\"arena\":\"$$1\",\"seed\":$$6,/" > $$out.askers; rm -f $$out.log; \
		[ -s $$out ] || echo "{\"arena\":\"$$1\",\"seed\":$$6,\"credits\":$$4,\"missing\":true}" > $$out; \
		echo "  ran        census $$1 s$$6"; \
		$(if $(SEQ_BASE),$(PYTHON) tests/traffic/seq_hook.py census --base $(SEQ_BASE) --runs $(BUILD_DIR)/traffic-census-runs --lines "$(SEQ_CENSUS_LINES)" | sed "s/^/  /";) true'
	@cat $(BUILD_DIR)/traffic-census-runs/*.json > $(BUILD_DIR)/traffic-census.jsonl
	@cat $(BUILD_DIR)/traffic-census-runs/*.askers > $(BUILD_DIR)/traffic-census-askers.jsonl 2>/dev/null || true
	@$(PYTHON) tests/traffic/census_table.py $(BUILD_DIR)/traffic-census.jsonl
	@$(if $(SEQ_BASE),echo ">> traffic-census early-stop reading over the whole grid:"; $(PYTHON) tests/traffic/seq_hook.py census --base $(SEQ_BASE) --runs $(BUILD_DIR)/traffic-census-runs --lines "$(SEQ_CENSUS_LINES)",true)

# Round 26 (traffic T0/T2): his case at his pose, before and after (needs a display: make remote T=traffic-clip).
# TRAFFIC_CLIP_CASES (arena,kind) x TRAFFIC_CLIP_ARMS (tag:--traffic-off list, "-" = none) -> build/traffic-clip/<arena>-<kind>/
# <tag>_*.png + <tag>.mp4 (10 fps = real time at every 3 ticks) + a contact sheet <tag>_sheet.png (one frame a second).
TRAFFIC_CLIP_CASES ?= yard_open,head yard_open,cross terminus,head terminus,cross
TRAFFIC_CLIP_ARMS ?= main:slide,parked on:-
TRAFFIC_CLIP_SEED ?= 1
TRAFFIC_CLIP_SECONDS ?= 40
.PHONY: traffic-clip
traffic-clip: import ## Round 26 (traffic): his crossing cases at his pose, per arm (main / CP1a / on) -> build/traffic-clip/<case>/<arm>.mp4 + contact sheets (needs a display)
	@rm -rf $(BUILD_DIR)/traffic-clip; mkdir -p $(BUILD_DIR)/traffic-clip
	@for case in $(TRAFFIC_CLIP_CASES); do arena=$${case%%,*}; kind=$${case##*,}; dir=$(CURDIR)/$(BUILD_DIR)/traffic-clip/$$arena-$$kind; mkdir -p $$dir; \
		for arm in $(TRAFFIC_CLIP_ARMS); do tag=$${arm%%:*}; off=$${arm#*:}; flag=$$([ "$$off" = - ] || echo --traffic-off=$$off); \
		timeout 900 $(GODOT) --path . --resolution 1280x720 --fixed-fps $(SIM_HZ) --script res://tests/traffic/traffic_clip.gd -- \
			--arena=$$arena --kind=$$kind --seed=$(TRAFFIC_CLIP_SEED) --seconds=$(TRAFFIC_CLIP_SECONDS) --every=3 --tag=$$tag --out=$$dir $$flag $(TRAFFIC_FLAGS) \
			> $$dir/$$tag.log 2>&1 || echo ">> traffic-clip: $$arena $$kind $$tag exited non-zero"; \
		grep -o 'TRAFFIC_CLIP {.*' $$dir/$$tag.log | cut -c1-400 || echo ">> traffic-clip: $$arena $$kind $$tag: no TRAFFIC_CLIP line"; \
		ffmpeg -loglevel error -y -framerate 10 -pattern_type glob -i "$$dir/$${tag}_*.png" -c:v libx264 -pix_fmt yuv420p $$dir/$$tag.mp4 || true; \
		ffmpeg -loglevel error -y -framerate 10 -pattern_type glob -i "$$dir/$${tag}_*.png" -vf "select='not(mod(n\,10))',scale=320:-1,tile=6x4" -frames:v 1 $$dir/$${tag}_sheet.png || true; \
		find $$dir -name "$${tag}_[0-9]*.png" ! -name "*0000.png" ! -name "*00[1-9]0.png" -delete; \
	done; done

# Round 26 (traffic CP1a2): the falsifier of "never give way to a parked friend" — a friend parked in the only lane (the
# maze's 8 m west serpentine) to where another crew is sent. TRAFFIC_PARKED_HULLS x TRAFFIC_SEEDS, both arms (the old rule:
# --traffic-off=parked) -> one PARKED_PROBE line each: reached_s, gap_m, how far the parked crew moved, the counters.
TRAFFIC_PARKED_HULLS ?= gang_tank law_tank
.PHONY: traffic-parked
traffic-parked: import ## Round 26 (traffic CP1a2): a friend parked in the only lane, both arms x TRAFFIC_PARKED_HULLS x TRAFFIC_SEEDS -> PARKED_PROBE lines
	@echo ">> traffic-parked on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown})"
	@for hull in $(TRAFFIC_PARKED_HULLS); do for seed in $(TRAFFIC_SEEDS); do for arm in old new; do \
		if [ $$arm = old ]; then flag=--traffic-off=parked; else flag=; fi; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/traffic/parked_probe.gd -- \
			--parked=$$hull --asker=law_tank --seed=$$seed --seconds=60 $$flag 2>/dev/null | grep -o 'PARKED_PROBE {.*' \
			| sed "s/^PARKED_PROBE {/PARKED_PROBE {\"arm\":\"$$arm\",/" || echo "PARKED_PROBE MISSING $$hull $$seed $$arm"; \
	done; done; done

# Round 26 (traffic): one cell of the arrive series (squad-arrive-series' exact command) traced, both arms — for the
# CP1a regression the orchestrator assigned (Sumps, law_scout:law_ifv:law_tank:law_tank, seed 1: 87.6 m short with CP1a).
TRAFFIC_SETTLE_ARENA ?= sumps
TRAFFIC_SETTLE_UNITS ?= law_scout:law_ifv:law_tank:law_tank
TRAFFIC_SETTLE_SEED ?= 1
TRAFFIC_SETTLE_ARMS ?= slide none
.PHONY: traffic-settle-trace
traffic-settle-trace: import ## Round 26 (traffic): one arrive-series cell traced per arm (--traffic-off=<arm>) -> build/traffic-settle-<arm>.log (SETTLE_TRACE/SETTLE_TRACK lines)
	@for arm in $(TRAFFIC_SETTLE_ARMS); do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/settle_probe.gd -- \
			--arena=$(TRAFFIC_SETTLE_ARENA) --dir=forward --metres=150 --seed=$(TRAFFIC_SETTLE_SEED) --units=$(TRAFFIC_SETTLE_UNITS) \
			--seconds=120 --drills=on --trace=on --traffic-off=$$arm $(TRAFFIC_FLAGS) > $(BUILD_DIR)/traffic-settle-$$arm.log 2>&1 || true; \
		echo "$$arm: $$(grep -o 'SETTLE_PROBE {.*' $(BUILD_DIR)/traffic-settle-$$arm.log | cut -c1-300)"; \
	done

.PHONY: traffic-census-one
traffic-census-one: import ## Round 26 (traffic): one census run with its whole log (CENSUS_ONE="sumps law gangs 1000 opponent 1") -> build/traffic-census-one.log
	@set -- $(or $(CENSUS_ONE),sumps law gangs 1000 opponent 1); \
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/traffic/census_probe.gd -- \
		--arena=$$1 --green=$$2 --rust=$$3 --credits=$$4 --army=$$5 --seed=$$6 --seconds=$(or $(TRAFFIC_CENSUS_SECONDS),20) $(TRAFFIC_FLAGS) \
		> $(BUILD_DIR)/traffic-census-one.log 2>&1 || true; \
	grep -E "TRAFFIC_CENSUS|SCRIPT ERROR|ERROR|error" $(BUILD_DIR)/traffic-census-one.log | head -20

.PHONY: traffic-pytest
traffic-pytest: ## Round 31 (traffic I4): the early-stop hook's Python tests (tests/traffic/test_*.py)
	$(PYTHON) -m unittest discover -s tests/traffic -p 'test_*.py'

# Round 30 (traffic T1c-b, the orchestrator's addition (d)): "no native diff" proven, not stated. The census and brains'
# ApproachStage drawn-artillery runs on the NATIVE path with every owned native execute verified against the GDScript
# (TANK_NATIVE_EXEC_VERIFY=1, as native-verify-scenarios does): a refusal in Movement.ask() marks the execute stale, and
# a mismatch would print "NativeExec verify". TRAFFIC_VERIFY_CENSUS ("arena green rust credits army seed" ;-separated),
# TRAFFIC_VERIFY_APPROACH_SEEDS -> build/traffic-native-verify/*.log; fails on any mismatch or a run with no probe line.
TRAFFIC_VERIFY_CENSUS ?= sumps law gangs 1000 opponent 7;parade gangs law 2000 opponent 8
TRAFFIC_VERIFY_APPROACH_SEEDS ?= 13 14
.PHONY: traffic-native-verify
traffic-native-verify: native import ## Round 30 (T1c-b): census + ApproachStage drawn artillery on the native path with the execute verified (TANK_NATIVE_EXEC_VERIFY=1) -> mismatches (0 = equal)
	@rm -rf $(BUILD_DIR)/traffic-native-verify; mkdir -p $(BUILD_DIR)/traffic-native-verify; d=$(BUILD_DIR)/traffic-native-verify; bad=0; \
	cases='$(TRAFFIC_VERIFY_CENSUS)'; IFS=';'; for c in $$cases; do IFS=' '; set -- $$c; log=$$d/census-$$1-$$6.log; \
		TANK_NATIVE_EXEC_VERIFY=1 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/traffic/census_probe.gd -- \
			--arena=$$1 --green=$$2 --rust=$$3 --credits=$$4 --army=$$5 --seed=$$6 --seconds=$(TRAFFIC_CENSUS_SECONDS) > $$log 2>&1 || true; \
		v=$$(grep -c "NativeExec verify" $$log || true); p=$$(grep -o '"setup_refusals":[0-9]*' $$log | head -1); \
		echo "  census $$1 s$$6: $$v mismatches, $${p:-NO PROBE LINE}"; [ "$$v" = 0 ] && [ -n "$$p" ] || bad=1; IFS=';'; done; IFS=' '; \
	for seed in $(TRAFFIC_VERIFY_APPROACH_SEEDS); do log=$$d/approach-$$seed.log; \
		TANK_NATIVE_EXEC_VERIFY=1 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/approach_probe.gd -- \
			--seed=$$seed --approach=east --seconds=90 --lab-start-tick=1 --live=on --his=artillery,artillery,artillery --theirs=law_ifv > $$log 2>&1 || true; \
		v=$$(grep -c "NativeExec verify" $$log || true); p=$$(grep -o '"repacks":[0-9]*' $$log | head -1); \
		echo "  approach s$$seed: $$v mismatches, $${p:-NO PROBE LINE}"; [ "$$v" = 0 ] && [ -n "$$p" ] || bad=1; done; \
	[ $$bad = 0 ] && echo "traffic-native-verify: 0 mismatches" || { echo "traffic-native-verify FAILED (build/traffic-native-verify/)"; exit 1; }

# ---- round 33 (traffic X1, C33.2 (1)): the far ask loop's census on skirmish stages ---------------------------------
# FAR_ARENAS x FAR_SEEDS showmatch fights (--skirmish --demo-match: both CPU sides run elements, as his opponent does),
# each through tests/traffic/far_census.gd (manoeuvre's H1B_FAR rows + what the blocker was doing that tick), FAR_JOBS at
# a time -> build/traffic-far/<arena>-<seed>.log + tests/traffic/far_table.py's table (far loops per match by
# blocker_kind, parked or moving, route left, gap, where the parked blocker stood, why it refused). FAR_FLAGS for an arm.
FAR_ARENAS ?= terminus locks random
FAR_SEEDS ?= 500 501 502 503 504 505 506 507
FAR_JOBS ?= 6
FAR_SECONDS ?= 180
FAR_FLAGS ?=
FAR_DIR ?= $(BUILD_DIR)/traffic-far
# make remote's T is word-split: FAR_RANGE=a-b replaces FAR_SEEDS, FAR_AT=a,b,c replaces FAR_ARENAS.
FAR_RANGE ?=
FAR_AT ?=
FAR_SEED_LIST = $(if $(FAR_RANGE),$(shell seq $(subst -, ,$(FAR_RANGE))),$(FAR_SEEDS))
FAR_ARENA_LIST = $(if $(FAR_AT),$(subst $(comma), ,$(FAR_AT)),$(FAR_ARENAS))
.PHONY: traffic-far-census
traffic-far-census: import ## Round 33 (traffic X1): far ask loops per skirmish fight by blocker kind and what the parked blocker was doing (FAR_ARENAS x FAR_SEEDS, FAR_FLAGS) -> build/traffic-far/ + table
	@rm -rf $(FAR_DIR); mkdir -p $(FAR_DIR)
	@echo ">> traffic-far-census on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | arenas '$(FAR_ARENA_LIST)' seeds '$(FAR_SEED_LIST)' | flags '$(FAR_FLAGS)' | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for seed in $(FAR_SEED_LIST); do for arena in $(FAR_ARENA_LIST); do echo "$$arena $$seed"; done; done | \
		xargs -P $(FAR_JOBS) -L 1 sh -c 'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . \
		--script res://tests/traffic/far_census.gd -- --skirmish --demo-match --clean --seed=$$1 --arena=$$0 --mute \
		--seconds=$(FAR_SECONDS) $(FAR_FLAGS) > $(FAR_DIR)/$$0-$$1.log 2>&1 || true; \
		grep -q "^FAR_CENSUS" $(FAR_DIR)/$$0-$$1.log && echo "  ran $$0 s$$1" || echo "  MISSING FAR_CENSUS $$0 s$$1"'
	@$(PYTHON) tests/traffic/far_table.py $(FAR_DIR)

# The same census on hull-rest's workload (his drawn faced orders, two player squads, a quiet holding enemy, foundry):
# HULL_FACTIONS x FAR_RANGE seeds (default HULL_SEEDS) x the six faced tasks, through far_census.gd -> build/traffic-far-hull/.
FAR_HULL_DIR ?= $(BUILD_DIR)/traffic-far-hull
.PHONY: traffic-far-hull
traffic-far-hull: import ## Round 33 (traffic X1): the far census on hull-rest's drawn faced orders (HULL_FACTIONS x FAR_RANGE|HULL_SEEDS x tasks) -> build/traffic-far-hull/ + table
	@rm -rf $(FAR_HULL_DIR); mkdir -p $(FAR_HULL_DIR)
	@echo ">> traffic-far-hull on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | flags '$(FAR_FLAGS)' | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for faction in $(HULL_FACTIONS); do for seed in $(if $(FAR_RANGE),$(FAR_SEED_LIST),$(HULL_SEEDS)); do for task in $(_FACING_TASKS); do \
		echo "$$faction $$seed $$task"; done; done; done | xargs -P $(FAR_JOBS) -L 1 sh -c '\
		d=$(FAR_HULL_DIR)/$$0-$$1-$$2; mkdir -p $$d; enemy=law; [ $$0 = law ] && enemy=gangs; \
		timeout 300 $(GODOT) --headless --path . --script res://tests/traffic/far_census.gd -- --skirmish --seed=$$1 \
			--no-pick-faction --mute --arena=$(FACING_ARENA) --player-faction=$$0 --enemy-faction=$$enemy \
			--tune=match.no_damage=1 --enemy=$(FACING_QUIET_ENEMY) --no-element-cpu --seconds=0 $(FAR_FLAGS) \
			--screen-test=$(CURDIR)/$$d --screen-only=$$2 > $$d.log 2>&1 || true; \
		grep -q "^FAR_CENSUS" $$d.log || echo "  MISSING FAR_CENSUS $$0 s$$1 $$2"'
	@$(PYTHON) tests/traffic/far_table.py $(FAR_HULL_DIR)

# One fight traced: FAR_ONE_ARENA, FAR_ONE_SEED, FAR_TRACE=a,b ('+' for a space in a name), FAR_FROM/FAR_TO seconds
# -> build/traffic-far-one.log (FAR_ROW + FAR_TRACE every 0.5 s). Light: tools/remote.sh --light traffic-far-one ...
FAR_ONE_ARENA ?= random
FAR_ONE_SEED ?= 403
FAR_TRACE ?=
FAR_FROM ?= 0
FAR_TO ?= 180
.PHONY: traffic-far-one
traffic-far-one: import ## Round 33 (traffic X1): one fight with the named hulls traced every 0.5 s (FAR_ONE_ARENA FAR_ONE_SEED FAR_TRACE FAR_FROM FAR_TO FAR_FLAGS) -> build/traffic-far-one.log
	@timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/traffic/far_census.gd -- --skirmish \
		--demo-match --clean --seed=$(FAR_ONE_SEED) --arena=$(FAR_ONE_ARENA) --mute --seconds=$(FAR_TO) \
		--far-trace=$(FAR_TRACE) --far-trace-from=$(FAR_FROM) --far-trace-to=$(FAR_TO) $(FAR_FLAGS) > $(BUILD_DIR)/traffic-far-one.log 2>&1 || true
	@(grep -c "^FAR_TRACE" $(BUILD_DIR)/traffic-far-one.log || true) | xargs echo "traffic-far-one: FAR_TRACE rows"; grep -m3 "SCRIPT ERROR" $(BUILD_DIR)/traffic-far-one.log || true

# The navmesh, obstacle footprints and (optionally) a far_census trace's hulls round one spot (round 32's navgap probe):
# NAVGAP_ARENA NAVGAP_X NAVGAP_Z [NAVGAP_TRACE=<FAR_TRACE log> NAVGAP_AT=<s>] -> build/traffic-navgap.json + .png
NAVGAP_ARENA ?= crossing
NAVGAP_X ?= 53
NAVGAP_Z ?= 56
NAVGAP_TRACE ?=
NAVGAP_AT ?= 0
.PHONY: traffic-navgap
traffic-navgap: import ## Round 33 (traffic X1): navmesh + obstacles (+ a trace's hulls) round NAVGAP_X/Z on NAVGAP_ARENA -> build/traffic-navgap.png
	@timeout 300 $(GODOT) --headless --path . --script res://tests/traffic/navgap_probe.gd -- --arena=$(NAVGAP_ARENA) \
		--x=$(NAVGAP_X) --z=$(NAVGAP_Z) 2>&1 | grep -o "^NAVGAP {.*" | sed "s/^NAVGAP //" > $(BUILD_DIR)/traffic-navgap.json
	@$(PYTHON) tests/traffic/navgap_plot.py $(BUILD_DIR)/traffic-navgap.json $(BUILD_DIR)/traffic-navgap.png "$(NAVGAP_ARENA) ($(NAVGAP_X), $(NAVGAP_Z))" $(NAVGAP_TRACE) $(NAVGAP_AT)
