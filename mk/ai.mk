# Unit and squad AI: behavior scenarios, ladder, cost
# Owner: ai (see _agents/workstreams.md, _agents/unit_ai.md). Included by the root Makefile.

ai-scenarios: import ## Behavior scenarios (seeded mini-battles) faster than real time; FILTER=substring; pending ones may fail
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=$(FILTER) $(AI_SCEN_FLAGS)

# Knobs this file owns carry its prefix (orchestrator, round 6: `UNITS ?= 60` here silently made another stream's "30
# units" run 60). The old names still work, but ONLY when typed on the command line: $(origin) keeps another file's
# default from ever reaching these targets. Each target prints what its knobs resolved to.
cmdline = $(if $(filter command line,$(origin $(1))),$($(1)),$(2))
AI_UNITS ?= $(call cmdline,UNITS,60)
ai-perf: import ## AI CPU cost (AB=1|<switch>: round-16 BrainSwitches on/off interleaved in one fight): AI_UNITS brains fighting (default 60, the round-4 target), prints MEASURE ai_usec_per_tick (budget in _agents/unit_ai.md); BRAIN=a6 profiles another brain variant; DETAIL=1 breaks moving and shooting down further
	@echo ">> ai-perf: AI_UNITS=$(AI_UNITS) BRAIN=$(BRAIN)"
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=scenario_perf --units=$(AI_UNITS) $(if $(DETAIL),--profile-parts) $(if $(BRAIN),--green-brain=$(BRAIN) --rust-brain=$(BRAIN)) $(if $(PERF_REFUSE),--perf-refuse=$(PERF_REFUSE)) $(if $(AB),--brains-ab=$(if $(filter 1,$(AB)),all,$(AB)))

# Round 14 (squad Q2; verification.md rule 3): scenario_perf refuses to judge its budget when its reference workload
# runs more than 1.5x this machine's nominal. The nominal is recorded HERE, on an idle machine, and copied by hand
# into tests/ai_scenarios/perf_nominal.json (make remote copies back build/ and nothing else). PERF_REFUSE=off on
# ai-perf is the mutation arm: it judges regardless of load, as the scenario did before round 14.
ai-perf-nominal: import ## Record this machine's scenario_perf yardstick (run it IDLE; on builder0: make remote T=ai-perf-nominal) -> build/perf_nominal.txt, then copy the line into tests/ai_scenarios/perf_nominal.json
	@echo ">> ai-perf-nominal on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg) | $$(pgrep -c -f 'Godot_v' || echo 0) other godot"
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=scenario_perf \
		--perf-record-nominal --perf-refuse=off 2>&1 | grep -E "PERF_NOMINAL|MEASURE (perf_reference|ai_usec_per_tick )|PASS|FAIL|ERROR" | tee $(BUILD_DIR)/perf_nominal.txt
	@grep -q '^PERF_NOMINAL ' $(BUILD_DIR)/perf_nominal.txt

# Round 17 (ship W4): is a refusal LOAD or CORE TYPE? builder0 is a hybrid i5-1345U: CPUs 0-3 are two P-cores (4.7 GHz,
# HT), 4-11 eight E-cores (3.5 GHz). scenario_perf's nominal was recorded idle (the scheduler's choice: a P-core), and
# under load the scheduler parks a process wherever is free. This runs the scenario pinned to each core type in turn
# (taskset; PERF_CORES_N rounds, interleaved so the box's load hits both arms alike) and prints one PERF_CORES line per
# run: the reference ratio and the brains' cost. A machine without cpu_core/cpu_atom (the laptop) has one arm, "all".
PERF_CORES_N ?= 3
perf-cores: import ## Round 17 W4: scenario_perf pinned to P-cores vs E-cores (taskset), PERF_CORES_N interleaved rounds -> PERF_CORES lines (build/perf-cores.txt)
	@p=$$(cat /sys/devices/cpu_core/cpus 2>/dev/null); e=$$(cat /sys/devices/cpu_atom/cpus 2>/dev/null); \
	arms="$${p:+P:$$p} $${e:+E:$$e}"; [ -n "$${arms// /}" ] || arms="all:0-$$(( $$(nproc) - 1 ))"; \
	echo ">> perf-cores on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | arms $$arms | load $$(cut -d' ' -f1-3 /proc/loadavg) | $$(pgrep -c -f 'Godot_v' || echo 0) godot" | tee $(BUILD_DIR)/perf-cores.txt; \
	for i in $$(seq 1 $(PERF_CORES_N)); do for arm in $$arms; do \
		name=$${arm%%:*}; cpus=$${arm#*:}; load=$$(cut -d' ' -f1 /proc/loadavg); \
		out=$$(taskset -c $$cpus $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- \
			--filter=scenario_perf --perf-refuse=off 2>&1 || true); \
		echo "PERF_CORES arm=$$name cpus=$$cpus round=$$i load_before=$$load | $$(echo "$$out" | grep -oE 'perf_reference [0-9.]+ ms median during.*: [0-9.]+x' | sed -E 's/ median during the fight \(([0-9]+) samples\), ([0-9.]+) before it, nominal ([0-9.]+) on [a-z0-9-]+:/ (\1 samples, \2 before, nominal \3):/') | $$(echo "$$out" | grep -oE 'ai_usec_per_tick [0-9]+')" | tee -a $(BUILD_DIR)/perf-cores.txt; \
	done; done

# Round 17 (ship W4): the CPU budget JUDGED, the way `check` now does it before its fan-out (tools/perf_judge.sh: pinned
# to the P-cores, a wait for them to be quiet, up to PERF_JUDGE_TRIES attempts; refuses only when the box never is).
perf-judge: import ## Round 17 W4: scenario_perf judged first and alone on the fast cores (PERF_JUDGE_TRIES=3 PERF_JUDGE_WAIT=120) -> build/perf-judge/
	tools/perf_judge.sh $(GODOT) $(SIM_HZ) $(BUILD_DIR)/perf-judge

AI_VARIANTS_DEFAULT := r1,a4,a6
AI_VARIANTS ?= $(call cmdline,VARIANTS,$(AI_VARIANTS_DEFAULT))
AI_CHAMPION ?= $(call cmdline,CHAMPION,a6)
AI_RUNS ?= $(call cmdline,RUNS,4)
LADDER_DOCTRINE ?= individuals
# Round 17: LADDER_BUDGET / LADDER_ARENA add --budget= / --arena= (make remote's T is word-split, so a two-flag
# LADDER_EXTRA cannot be passed through it). The default armies (individuals: 5-8 units) never exercise most of the
# round-17 levers: three lever ladders came back byte-identical to the champion; price them at his size.
ai-ladder: import ## AI ELO ladder: brain AI_VARIANTS (a6,x3; x3+v3 = with CPU commander v3) play mirror armies (LADDER_DOCTRINE: a file or cpu:<archetype>, LADDER_EXTRA=--budget=1000, LADDER_BUDGET, LADDER_ARENA), each seed 4 ways; AI_CHAMPION must be beaten (AI_RUNS=4)
	@echo ">> ai-ladder: AI_VARIANTS=$(AI_VARIANTS) AI_CHAMPION=$(AI_CHAMPION) AI_RUNS=$(AI_RUNS) LADDER_DOCTRINE=$(LADDER_DOCTRINE)"
	$(PYTHON) tools/ai_ladder.py --godot $(GODOT) --variants $(AI_VARIANTS) --champion $(AI_CHAMPION) --runs $(AI_RUNS) \
		--jobs $(JOBS) --doctrine $(LADDER_DOCTRINE) $(if $(FIRST_SEED),--first-seed $(FIRST_SEED)) --extra="$(strip $(LADDER_EXTRA) $(if $(LADDER_BUDGET),--budget=$(LADDER_BUDGET)) $(if $(LADDER_ARENA),--arena=$(LADDER_ARENA)))" --json $(BUILD_DIR)/ai_ladder.json

ai-shots: import ## Staged AI fights with driving trails, frames in build/ai-shots/ (needs a display: make remote T=ai-shots; STAGE=duel|scout_runs|brawl)
	mkdir -p $(BUILD_DIR)/ai-shots
	$(GODOT) --path . --fixed-fps $(SIM_HZ) --resolution 1280x960 --script res://tests/ai_scenarios/watch_shots.gd -- $(if $(STAGE),--stage=$(STAGE)) \
		2>&1 | tee $(BUILD_DIR)/ai-shots/log.txt | grep -E "AI_SHOT|ERROR" || true
	grep -q AI_SHOTS_DONE $(BUILD_DIR)/ai-shots/log.txt

# Round 15 (squad P3): is scenario_perf's fight the same fight alone and in the suite? Its battle (LOS queries, units
# alive) is deterministic, so any difference is state a preceding scenario leaves behind. Runs it alone, then after
# each scenario file that precedes it in the suite's order (one process each, PERF_LEAK_JOBS at once), then after the
# whole suite before it, and prints one PERF_LEAK line per run. Timing numbers are not compared here, only the fight.
PERF_LEAK_BEFORE ?= scenario_commander scenario_cover scenario_cp2 scenario_dodge_rate scenario_elements scenario_evasion scenario_fire_discipline scenario_matchups scenario_motion scenario_orders
ai-perf-leak: import ## Round 15 (squad P3): scenario_perf's fight alone vs after each preceding scenario (and all of them): one PERF_LEAK line each with LOS queries and units alive; FAILS unless every fight is the one it fights alone. SCENARIO_ORDER=alpha is the pre-round-15 order (the mutation arm)
	@mkdir -p $(BUILD_DIR)/perf-leak; rm -f $(BUILD_DIR)/perf-leak/*.log
	@for before in alone $(PERF_LEAK_BEFORE) all; do \
		case $$before in alone) f="scenario_perf";; all) f="$$(echo $(PERF_LEAK_BEFORE) | tr ' ' '|')|scenario_perf";; *) f="$$before|scenario_perf";; esac; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- "--filter=$$f" --perf-refuse=off \
			$(if $(SCENARIO_ORDER),--scenario-order=$(SCENARIO_ORDER)) > $(BUILD_DIR)/perf-leak/$$before.log 2>&1 & \
		while [ $$(jobs -r | wc -l) -ge $(or $(PERF_LEAK_JOBS),4) ]; do sleep 1; done; \
	done; wait; \
	for before in alone $(PERF_LEAK_BEFORE) all; do \
		echo "PERF_LEAK $$before | $$(grep -oE 'perf_start .*' $(BUILD_DIR)/perf-leak/$$before.log | head -1) | $$(grep -oE '[0-9]+ ticks fighting, [0-9]+ alive at the end; LOS [0-9]+ queries, [0-9]+ computed' $(BUILD_DIR)/perf-leak/$$before.log || echo NO_MEASURE)"; \
	done | tee $(BUILD_DIR)/perf-leak/summary.txt; \
	fights=$$(sed -E 's/^PERF_LEAK [^|]*\|[^|]*\| //' $(BUILD_DIR)/perf-leak/summary.txt | sort -u | wc -l); \
	if [ "$$fights" -eq 1 ] && ! grep -q NO_MEASURE $(BUILD_DIR)/perf-leak/summary.txt; then echo "ai-perf-leak: ONE fight in all $$(wc -l < $(BUILD_DIR)/perf-leak/summary.txt) runs"; \
	else echo "ai-perf-leak: $$fights DIFFERENT fights -- scenario_perf is not measuring one battle"; exit 1; fi

# Round 16 (brains A1): behaviour parity for performance work. One 60 s headless --match per (map, seed): CPU armies
# of two factions at the lead's army sizes; prints AI_PARITY_DIGEST over every MATCH_RESULT minus its wall-clock
# fields. "No decision changed" = the same digest on both commits (PARITY_REF=<a saved build/ai-parity/results.jsonl>
# compares and names the runs that differ). Knobs: SEEDS=1-8 PARITY_MAPS=yard,terminus PARITY_TIME=60
# PARITY_BUDGET=2600 PARITY_GREEN=law PARITY_RUST=condemned.
PARITY_MAPS ?= yard,terminus
ai-parity: import ## Round 16: behaviour parity (a digest over 60 s matches at SEEDS=1-8 on yard and terminus); PARITY_REF=file compares
	@mkdir -p $(BUILD_DIR)/ai-parity
	$(PYTHON) tools/ai_parity.py --godot $(GODOT) --sim-hz $(SIM_HZ) --jobs $(JOBS) --seeds $(call cmdline,SEEDS,1-8) \
		--maps $(PARITY_MAPS) --time $(or $(PARITY_TIME),60) --budget $(or $(PARITY_BUDGET),2600) \
		--green $(or $(PARITY_GREEN),law) --rust $(or $(PARITY_RUST),condemned) \
		--out $(BUILD_DIR)/ai-parity/results.jsonl $(if $(PARITY_REF),--ref $(PARITY_REF)) $(if $(PARITY_FLAGS),--extra=$(PARITY_FLAGS))

# Round 16 (brains): WHICH GDScript functions the tick spends its time in, from Godot's own script profiler (the local
# debugger, `-d --profiling`), summed over the frames it samples during one headless match. The same match as
# `make sim-profile`'s round-16 workload (the lead's Sumps recording: Law v Condemned at his army sizes). Shares are the
# reading (the profiler inflates absolute times). PROF_TIME=180 PROF_BUDGET=4600 PROF_SEED=92721 PROF_ARENA=sumps
# PROF_FLAGS= (e.g. --brains-off=all for the old paths), PROF_TOP=40.
ai-script-profile: import ## Round 16: function-level GDScript profile of one headless match (Godot's script profiler, sampled frames) -> build/ai-script-profile.{log,json}
	@mkdir -p $(BUILD_DIR)
	timeout 1800 $(GODOT) --headless -d --profiling --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control \
		--green-faction=law --rust-faction=condemned --budget=$(or $(PROF_BUDGET),4600) --time-limit=$(or $(PROF_TIME),180) \
		--seed=$(or $(PROF_SEED),92721) --arena=$(or $(PROF_ARENA),sumps) $(PROF_FLAGS) < /dev/null > $(BUILD_DIR)/ai-script-profile.log 2>&1 || true
	@grep -m1 '^MATCH_RESULT' $(BUILD_DIR)/ai-script-profile.log | cut -c1-200 || { echo "ai-script-profile: the match did not finish"; exit 1; }
	$(PYTHON) tools/ai_script_profile.py $(BUILD_DIR)/ai-script-profile.log --top $(or $(PROF_TOP),40) --json $(BUILD_DIR)/ai-script-profile.json

# ...and the same profiler on HIS PATH: play's `perf-play` command line (a human-side skirmish, his flags, his window,
# the perf driver; mk/fx.mk is play's and is not edited here) with the script profiler on, so the fog field, the
# controls, the HUD and the camera scripts rank beside the brains. Needs a display (make remote T=ai-script-profile-play).
# PROF_PLAY_SEED=92721, PROF_PLAY_SECONDS (measured window per cycle, default 20), PROF_TOP.
ai-script-profile-play: import ## Round 16: function-level script profile of a human-side skirmish on his path (perf-play's flags; needs a display) -> build/ai-script-profile-play.{log,json}
	@mkdir -p $(BUILD_DIR)/perf-play/recordings
	timeout 900 $(GODOT) -d --profiling --path . --resolution $(PERF_PLAY_RES) -- --skirmish --enemy=cpu --seed=$(or $(PROF_PLAY_SEED),92721) \
		--arena=$(PERF_PLAY_ARENA) $(PERF_PLAY_FACTIONS) --announcer=voice --music=on --camera-readout=on --hints=off \
		--announcer-history=off --music-history=off --record-dir=$(CURDIR)/$(BUILD_DIR)/perf-play/recordings \
		--perf-play --perf-scene=$(CURDIR)/$(BUILD_DIR)/ai-script-profile-play.perf.json \
		--perf-warmup=$(PERF_PLAY_WARMUP) --perf-seconds=$(or $(PROF_PLAY_SECONDS),20) --perf-cycles=1 \
		< /dev/null > $(BUILD_DIR)/ai-script-profile-play.log 2>&1 || true
	@grep -q PERF_PLAY_DONE $(BUILD_DIR)/ai-script-profile-play.log || echo "ai-script-profile-play: the perf driver did not report PERF_PLAY_DONE (see the log)"
	$(PYTHON) tools/ai_script_profile.py $(BUILD_DIR)/ai-script-profile-play.log --top $(or $(PROF_TOP),60) --json $(BUILD_DIR)/ai-script-profile-play.json

# Round 16 (brains): the in-run A/B on the lead's workload (BrainsAB): one headless Sumps match (Law v Condemned, his army
# sizes) with the round's switches flipped every 30 ticks, the controller band's CPU charged per arm. Prints BRAINS_AB,
# and the run's state hash beside a plain run's (they must be equal: the switches are equalities). AB_SWITCH=all|<name>.
ai-ab-match: import ## Round 16: the round's switches on/off in 30-tick blocks inside one Sumps match (BRAINS_AB line; hash equal to a plain run; round 18: AB_FLAGS= adds match flags, e.g. --green-elements --rust-elements)
	@mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control --green-faction=law --rust-faction=condemned \
		--budget=$(or $(PROF_BUDGET),4600) --time-limit=$(or $(PROF_TIME),180) --seed=$(or $(PROF_SEED),92721) --arena=$(or $(PROF_ARENA),sumps) \
		--brains-ab-run=$(or $(AB_SWITCH),all) $(AB_FLAGS) > $(BUILD_DIR)/ai-ab-match.log 2>&1
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control --green-faction=law --rust-faction=condemned \
		--budget=$(or $(PROF_BUDGET),4600) --time-limit=$(or $(PROF_TIME),180) --seed=$(or $(PROF_SEED),92721) --arena=$(or $(PROF_ARENA),sumps) \
		$(AB_FLAGS) > $(BUILD_DIR)/ai-ab-match-plain.log 2>&1
	@grep -h '^BRAINS_AB' $(BUILD_DIR)/ai-ab-match.log || { echo "ai-ab-match: no BRAINS_AB line"; exit 1; }
	@a=$$(grep -o '"state_hash":"[0-9a-f]*"' $(BUILD_DIR)/ai-ab-match.log); b=$$(grep -o '"state_hash":"[0-9a-f]*"' $(BUILD_DIR)/ai-ab-match-plain.log); \
		echo "ai-ab-match: A/B run $$a, plain run $$b"; [ -n "$$a" ] && [ "$$a" = "$$b" ] || { echo "ai-ab-match: the A/B changed the run -- a switch is not an equality"; exit 1; }

# ...and both on HIS PATH (perf-play's command line, a display): `--brains-parts` (the brains' parts and call sites per
# tick, BRAINS_PARTS) and `--brains-ab-run=$(AB_SWITCH)` (the round's switches in 30-tick blocks, BRAINS_AB). A
# skirmish's fight is not seeded the way a headless match is, so here the A/B is read from its own two arms only.
ai-ab-play: import ## Round 16: BRAINS_PARTS + BRAINS_AB on a human-side skirmish on his path (perf-play's flags; needs a display; AB_SWITCH=all|<name>|none; round 17: LEVER=<l17* variant> prices a decision lever there, both sides on it, the player's own units exempt from far-and-idle)
	@echo ">> $@ on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg) | $$(pgrep -c -f 'Godot_v' || echo 0) godot running"
	@mkdir -p $(BUILD_DIR)/perf-play/recordings
	timeout 900 $(GODOT) --path . --resolution $(PERF_PLAY_RES) -- --skirmish --enemy=cpu --seed=$(or $(PROF_PLAY_SEED),92721) \
		--arena=$(PERF_PLAY_ARENA) $(PERF_PLAY_FACTIONS) --announcer=voice --music=on --camera-readout=on --hints=off \
		--announcer-history=off --music-history=off --record-dir=$(CURDIR)/$(BUILD_DIR)/perf-play/recordings \
		--perf-play --perf-scene=$(CURDIR)/$(BUILD_DIR)/ai-ab-play.perf.json \
		--perf-warmup=$(PERF_PLAY_WARMUP) --perf-seconds=$(or $(PROF_PLAY_SECONDS),20) --perf-cycles=1 \
		$(if $(LEVER),--green-brain=$(LEVER) --rust-brain=$(LEVER) --brains-ab-block=$(or $(LEVER_BLOCK),300) --brains-ab-skip=$(or $(LEVER_SKIP),30) --brains-census,--brains-parts) \
		$(if $(filter none,$(AB_SWITCH)),,--brains-ab-run=$(if $(LEVER),$(or $(LEVER_MODE),levers-split),$(or $(AB_SWITCH),all))) > $(BUILD_DIR)/ai-ab-play.log 2>&1 || true
	@grep -h '^BRAINS_AB\|^BRAINS_PARTS\|^BRAINS_LOD' $(BUILD_DIR)/ai-ab-play.log | cut -c1-3000 || { echo "ai-ab-play: no BRAINS lines (see build/ai-ab-play.log)"; exit 1; }

# Round 17 (brains T1): a DECISION lever's price, on one table. A lever is an `l17*` brain variant (BrainLevers: the
# champion plus one lever, OFF for everyone else). Its COST is by removal inside one run: both sides on LEVER, and
# BrainLevers.gate flipped every LEVER_BLOCK ticks (the first LEVER_SKIP of each block charged to neither arm, while
# the brains' bookings settle), so the two arms share one machine's load. A lever changes the fight, so the arms are
# blocks of one hybrid fight, not two equal fights; the run prints BRAINS_AB (the band and the whole tick, both arms),
# BRAINS_AB_PHASES (early = before the first shot, fight = after) and BRAINS_LOD (unit-ticks and thinks per think-LOD
# bucket). His Sumps workload by default (PROF_* knobs as ai-ab-match). LEVER and LEVER_SEEDS take comma lists (make
# remote's T is word-split): every lever x seed, LEVER_JOBS at once (each run is its own A/B under the shared load).
# LEVER_MODE=levers-split (the default since the first runs, 29f7578d): the lever ON for half the units and OFF for the
# other half in the SAME ticks, halves swapped each block, each controller's wall time charged to its half
# (BRAINS_AB_SPLIT, per unit-tick). LEVER_MODE=levers alternates whole blocks instead; its first five runs on builder0
# read +16 % to -16 % for levers that touch ~2 % of the work: the fight's own trend (units dying) between blocks
# swamped them, which is why the split exists.
# LEVER_PIN=0-3 pins every run to those CPUs (`taskset`): builder0 is a hybrid i5-1345U (0-3 P-cores, 4-11 E-cores), and
# a run that migrates between core types mixes two machines' ms (ship's lead, round 17). Pin numbers meant for his page.
LEVER_SEEDS ?= $(or $(PROF_SEED),92721)
ai-lever-ab: import ## Round 17: a decision lever's COST by removal inside one Sumps match (LEVER=<l17* variant>[,...], LEVER_SEEDS=a,b, LEVER_BLOCK=300, LEVER_SKIP=30, LEVER_JOBS=3)
	@[ -n "$(LEVER)" ] || { echo "ai-lever-ab: LEVER=<an l17* variant> (game/ai/brain_variants.gd)"; exit 1; }
	@mkdir -p $(BUILD_DIR)/ai-lever
	@echo ">> ai-lever-ab: LEVER=$(LEVER) seeds $(LEVER_SEEDS) on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for lever in $(subst $(comma), ,$(LEVER)); do for seed in $(subst $(comma), ,$(LEVER_SEEDS)); do \
		$(if $(LEVER_PIN),taskset -c $(LEVER_PIN)) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control --green-faction=law --rust-faction=condemned \
			--budget=$(or $(PROF_BUDGET),4600) --time-limit=$(or $(PROF_TIME),180) --seed=$$seed --arena=$(or $(PROF_ARENA),sumps) \
			--green-brain=$$lever --rust-brain=$$lever --brains-ab-run=$(or $(LEVER_MODE),levers-split) --brains-ab-block=$(or $(LEVER_BLOCK),300) \
			--brains-ab-skip=$(or $(LEVER_SKIP),30) --brains-census > $(BUILD_DIR)/ai-lever/ab-$$lever-$$seed.log 2>&1 & \
		while [ $$(jobs -r | wc -l) -ge $(or $(LEVER_JOBS),3) ]; do sleep 1; done; \
	done; done; wait; \
	for lever in $(subst $(comma), ,$(LEVER)); do for seed in $(subst $(comma), ,$(LEVER_SEEDS)); do \
		echo ">> ai-lever-ab $$lever seed $$seed"; \
		grep -h '^BRAINS_AB\|^BRAINS_LOD' $(BUILD_DIR)/ai-lever/ab-$$lever-$$seed.log || { echo "ai-lever-ab: no BRAINS_AB line (see $(BUILD_DIR)/ai-lever/ab-$$lever-$$seed.log)"; exit 1; }; \
		grep -m1 -o '"first_shot_seconds":[-0-9.]*' $(BUILD_DIR)/ai-lever/ab-$$lever-$$seed.log || true; \
	done; done

# ...and its BEHAVIOUR beside the champion's: the same matches (seeds named BEFORE the first run, PRICE_SEEDS) with both
# sides on each arm in PRICE_ARMS (the champion first), MATCH_RESULT's pace (first shot, first kill, kills, hits) and the
# brains' own census (first fight-rate second, thinks per bucket) summarised per arm by tools/ai_lever_price.py.
PRICE_SEEDS ?= 1701-1716
PRICE_ARMS ?= x5p,l17i2,l17i1,l17k,l17c,l17o
ai-lever-behaviour: import ## Round 17: each lever's behaviour beside the champion over PRICE_SEEDS (first contact, first shot, kills, thinks) -> build/ai-lever/behaviour-<arms>.json
	@mkdir -p $(BUILD_DIR)/ai-lever
	$(PYTHON) tools/ai_lever_price.py --godot $(GODOT) --sim-hz $(SIM_HZ) --jobs $(JOBS) --seeds $(PRICE_SEEDS) --arms $(PRICE_ARMS) \
		--arena $(or $(PRICE_ARENA),sumps) --time $(or $(PRICE_TIME),120) --budget $(or $(PRICE_BUDGET),4600) \
		--out $(BUILD_DIR)/ai-lever/behaviour-$(subst /,-,$(subst $(comma),_,$(PRICE_ARMS))).json

# Round 17 (brains T3): the brains' parts and the think-LOD census on his Sumps workload (no A/B): BRAINS_PARTS (incl.
# the move half by order type and stillness, `by.<type>.<still|moving>`) and BRAINS_LOD. PROF_* knobs as ai-ab-match;
# PARTS_FLAGS= adds match flags (e.g. --green-brain=l17k --rust-brain=l17k).
ai-parts-match: import ## Round 17: BRAINS_PARTS + BRAINS_LOD for one headless Sumps match (where the brains' time goes, by part and by order type)
	@mkdir -p $(BUILD_DIR)
	$(if $(LEVER_PIN),taskset -c $(LEVER_PIN)) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control --green-faction=law --rust-faction=condemned \
		--budget=$(or $(PROF_BUDGET),4600) --time-limit=$(or $(PROF_TIME),180) --seed=$(or $(PROF_SEED),92721) --arena=$(or $(PROF_ARENA),sumps) \
		--brains-parts $(PARTS_FLAGS) > $(BUILD_DIR)/ai-parts-match.log 2>&1
	@grep -h '^BRAINS_PARTS\|^BRAINS_LOD\|^BRAINS_ARM' $(BUILD_DIR)/ai-parts-match.log | cut -c1-6000 || { echo "ai-parts-match: no BRAINS_PARTS line"; exit 1; }

# Round 17 (brains T1): a lever's scenario and drill counts. The AI behaviour scenarios and the battle drills with
# both sides on LEVER (an l17* variant; BrainVariants reads the flags in any mode, and a scenario that picks its own
# variant still does). Prints the scenarios' pass/fail/pending line and every FAIL, and the drills' TACTICS_DONE line,
# to set beside the same target run with LEVER=x5p (the champion) on the same tree.
ai-lever-scenarios: import ## Round 17: the AI scenarios + battle drills with both sides on LEVER=<l17* variant> (compare with LEVER=x5p)
	@[ -n "$(LEVER)" ] || { echo "ai-lever-scenarios: LEVER=<an l17* variant or x5p>"; exit 1; }
	@mkdir -p $(BUILD_DIR)/ai-lever
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- \
		--green-brain=$(or $(LEVER_GREEN),$(LEVER)) --rust-brain=$(LEVER) > $(BUILD_DIR)/ai-lever/scenarios-$(LEVER)$(if $(LEVER_GREEN),-g$(LEVER_GREEN)).log 2>&1 || true
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/run_tactics.gd -- --drills \
		--green-brain=$(or $(LEVER_GREEN),$(LEVER)) --rust-brain=$(LEVER) > $(BUILD_DIR)/ai-lever/drills-$(LEVER)$(if $(LEVER_GREEN),-g$(LEVER_GREEN)).log 2>&1 || true
	@echo ">> ai-lever-scenarios $(LEVER) (green $(or $(LEVER_GREEN),$(LEVER)))"; grep -E "^  FAIL|^scenarios: |NOT JUDGED  " $(BUILD_DIR)/ai-lever/scenarios-$(LEVER)$(if $(LEVER_GREEN),-g$(LEVER_GREEN)).log || true
	@grep -E "TACTICS_DONE|FAIL" $(BUILD_DIR)/ai-lever/drills-$(LEVER)$(if $(LEVER_GREEN),-g$(LEVER_GREEN)).log | tail -5 || true

# Round 17 (brains T1): a decision lever's effect on DRIVING (the orchestrator's ask for the page: half-rate steering
# is a unit crossing the map). tests/nav/lever_drive_probe.gd boots the real match and reads every hull's
# Movement.state() every tick (yard's contact reading), per arm in DRIVE_ARMS (the champion first) on the SAME seeds:
# wall contacts per minute by cause x driver, wedged units, unstick fires, k-turn legs, units lost per side.
# Gangs (War Rigs: 14 m, wheeled) v Condemned (9.7 m tanks) at BUDGET 5200, as yard's count. DRIVE_MAPS, DRIVE_SEEDS,
# DRIVE_TIME=180, DRIVE_JOBS=3 -> build/ai-lever/drive.jsonl + LEVER_DRIVE_SUMMARY lines.
DRIVE_ARMS ?= x5p,l17s,l17b2
DRIVE_MAPS ?= sumps,terminus
ai-lever-drive: import ## Round 17: each lever's wall contacts, wedges, unsticks and k-turns beside the champion's, same seeds (DRIVE_ARMS, DRIVE_MAPS, DRIVE_SEEDS=1-6) -> build/ai-lever/drive.jsonl
	@echo ">> $@ on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg) | $$(pgrep -c -f 'Godot_v' || echo 0) godot running"
	@mkdir -p $(BUILD_DIR)/ai-lever; : > $(BUILD_DIR)/ai-lever/drive.jsonl
	@for m in $(subst $(comma), ,$(DRIVE_MAPS)); do for a in $(subst $(comma), ,$(DRIVE_ARMS)); do for s in $$(seq $(subst -, ,$(or $(DRIVE_SEEDS),1-6))); do \
		echo "$$a $$m $$s"; done; done; done \
	| xargs -P $(or $(DRIVE_JOBS),3) -L 1 sh -c '$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/lever_drive_probe.gd -- \
		--match --elimination --arena=$$1 --green-faction=gangs --rust-faction=condemned --budget=5200 --time-limit=$(or $(DRIVE_TIME),180) \
		--seed=$$2 --green-brain=$$0 --rust-brain=$$0 --probe-tag=$$0 2>/dev/null | grep "^LEVER_DRIVE " | cut -c13- >> $(BUILD_DIR)/ai-lever/drive.jsonl'
	@echo ">> ai-lever-drive: $$(wc -l < $(BUILD_DIR)/ai-lever/drive.jsonl) matches"
	@$(PYTHON) tools/ai_lever_drive.py $(BUILD_DIR)/ai-lever/drive.jsonl $(firstword $(subst $(comma), ,$(DRIVE_ARMS)))

# Round 17 (brains): the laptop null's ARM ASSERTION. perf-play's exact command line (mk/fx.mk is not edited: its
# variables are read), one seed, the uncapped arm, with LEVER on both sides and --brains-census, so the run prints
# BRAINS_ARM: the controller ticks the far-unit stride skipped per side, the CPU's share of unit-ticks with nothing in
# reach and no order, and the controller band's thread CPU beside the whole tick's scripts. On the laptop the same line
# comes from `make perf-play PERF_PLAY_FLAGS="--green-brain=<l> --rust-brain=<l> --brains-census"` (grep BRAINS_ in
# build/perf-play-*.log). LEVER=x5p is the control. LEVER_PLAY_SEEDS=a,b.
LEVER_PLAY_SEEDS ?= 92721
ai-lever-perfplay: import ## Round 17: perf-play's command line with LEVER on both sides + the census -> BRAINS_ARM (did the stride act on his path; where the tick goes)
	@[ -n "$(LEVER)" ] || { echo "ai-lever-perfplay: LEVER=<an l17* variant or x5p>"; exit 1; }
	@mkdir -p $(BUILD_DIR)/screenshots $(BUILD_DIR)/perf-play/recordings $(BUILD_DIR)/ai-lever
	@for seed in $(subst $(comma), ,$(LEVER_PLAY_SEEDS)); do \
		echo ">> ai-lever-perfplay $(LEVER) seed $$seed on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"; \
		timeout 600 $(GODOT) --path . --resolution $(PERF_PLAY_RES) -- --skirmish --enemy=cpu --seed=$$seed \
			--arena=$(PERF_PLAY_ARENA) $(PERF_PLAY_FACTIONS) --announcer=voice --music=on --camera-readout=on --hints=off \
			--announcer-history=off --music-history=off --render-preset=$(PERF_PLAY_PRESET) \
			--record-dir=$(CURDIR)/$(BUILD_DIR)/perf-play/recordings \
			--perf-play --perf-scene=$(CURDIR)/$(BUILD_DIR)/ai-lever/perfplay-$(LEVER)-$$seed.json \
			--perf-warmup=$(PERF_PLAY_WARMUP) --perf-seconds=$(PERF_PLAY_SECONDS) --perf-cycles=$(PERF_PLAY_CYCLES) \
			--green-brain=$(LEVER) --rust-brain=$(LEVER) --brains-census > $(BUILD_DIR)/ai-lever/perfplay-$(LEVER)-$$seed.log 2>&1 || true; \
		grep -h '^BRAINS_ARM\|^BRAINS_LOD\|^PERF_PLAY_DONE' $(BUILD_DIR)/ai-lever/perfplay-$(LEVER)-$$seed.log || echo "ai-lever-perfplay: no BRAINS_ARM line (see $(BUILD_DIR)/ai-lever/perfplay-$(LEVER)-$$seed.log)"; \
	done

# Round 18 (brains B5 (b)): the PRICE of the CPU running squad leaders (elements: formations, drills, the ambush) on
# his path. perf-play's command line, the CPU side with and without --element-cpu, INTERLEAVED per seed (on, off, on,
# off), on parade and the Sumps; both brains the champion; the census on. Arm assertion: `BRAINS_AMBUSH team 1` is
# printed only when the CPU's ElementCommander ran (and says how many ambushes it took and sprang); BRAINS_ARM gives the
# controller band and the whole tick's script CPU. A windowed laptop run opens on his desktop: the orchestrator's
# quiet-window job (workstreams.md, round 18). ELEMENT_PLAY_SEEDS=92721,1801 ELEMENT_PLAY_ARENAS="parade sumps".
ELEMENT_PLAY_SEEDS ?= 92721,1801
ELEMENT_PLAY_ARENAS ?= parade sumps
## Where the logs and perf JSONs go: keep it OUT of build/ when a remote check may copy back in the meantime (a
## copy-back deletes local build/ files builder0 does not have).
ELEMENT_PLAY_DIR ?= $(BUILD_DIR)/ai-element
.PHONY: ai-element-perfplay
ai-element-perfplay: import ## Round 18: the CPU with/without squad leaders (--element-cpu) on his path, interleaved, parade + Sumps -> build/ai-element/ (needs a display: his laptop, quiet window)
	@mkdir -p $(BUILD_DIR)/screenshots $(BUILD_DIR)/perf-play/recordings $(ELEMENT_PLAY_DIR)
	@for arena in $(ELEMENT_PLAY_ARENAS); do for seed in $(subst $(comma), ,$(ELEMENT_PLAY_SEEDS)); do for arm in on off; do \
		flag=$$( [ $$arm = on ] && echo --element-cpu || echo --no-element-cpu ); \
		echo ">> ai-element-perfplay $$arena seed $$seed elements=$$arm on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg)"; \
		timeout 600 $(GODOT) --path . --resolution $(PERF_PLAY_RES) -- --skirmish --enemy=cpu --seed=$$seed \
			--arena=$$arena $(PERF_PLAY_FACTIONS) --announcer=voice --music=on --camera-readout=on --hints=off \
			--announcer-history=off --music-history=off --render-preset=$(PERF_PLAY_PRESET) \
			--record-dir=$(CURDIR)/$(BUILD_DIR)/perf-play/recordings \
			--perf-play --perf-scene=$(abspath $(ELEMENT_PLAY_DIR))/perfplay-$$arena-$$seed-$$arm.json \
			--perf-warmup=$(PERF_PLAY_WARMUP) --perf-seconds=$(PERF_PLAY_SECONDS) --perf-cycles=$(PERF_PLAY_CYCLES) \
			$$flag --brains-census > $(ELEMENT_PLAY_DIR)/perfplay-$$arena-$$seed-$$arm.log 2>&1 || true; \
		grep -h '^BRAINS_ARM\|^BRAINS_AMBUSH\|^PERF_PLAY_DONE' $(ELEMENT_PLAY_DIR)/perfplay-$$arena-$$seed-$$arm.log || echo "ai-element-perfplay: no census lines (see $(ELEMENT_PLAY_DIR)/perfplay-$$arena-$$seed-$$arm.log)"; \
	done; done; done
