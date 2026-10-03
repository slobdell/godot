# Unit and squad AI: behavior scenarios, ladder, cost
# Owner: ai (see _agents/workstreams.md, _agents/unit_ai.md). Included by the root Makefile.

ai-scenarios: import ## Behavior scenarios (seeded mini-battles) faster than real time; FILTER=substring; pending ones may fail
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=$(FILTER)

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

AI_VARIANTS_DEFAULT := r1,a4,a6
AI_VARIANTS ?= $(call cmdline,VARIANTS,$(AI_VARIANTS_DEFAULT))
AI_CHAMPION ?= $(call cmdline,CHAMPION,a6)
AI_RUNS ?= $(call cmdline,RUNS,4)
LADDER_DOCTRINE ?= individuals
ai-ladder: import ## AI ELO ladder: brain AI_VARIANTS (a6,x3; x3+v3 = with CPU commander v3) play mirror armies (LADDER_DOCTRINE: a file or cpu:<archetype>, LADDER_EXTRA=--budget=1000), each seed 4 ways; AI_CHAMPION must be beaten (AI_RUNS=4)
	@echo ">> ai-ladder: AI_VARIANTS=$(AI_VARIANTS) AI_CHAMPION=$(AI_CHAMPION) AI_RUNS=$(AI_RUNS) LADDER_DOCTRINE=$(LADDER_DOCTRINE)"
	$(PYTHON) tools/ai_ladder.py --godot $(GODOT) --variants $(AI_VARIANTS) --champion $(AI_CHAMPION) --runs $(AI_RUNS) \
		--jobs $(JOBS) --doctrine $(LADDER_DOCTRINE) $(if $(FIRST_SEED),--first-seed $(FIRST_SEED)) $(if $(LADDER_EXTRA),--extra="$(LADDER_EXTRA)") --json $(BUILD_DIR)/ai_ladder.json

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
ai-ab-match: import ## Round 16: the round's switches on/off in 30-tick blocks inside one Sumps match (BRAINS_AB line; hash equal to a plain run)
	@mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control --green-faction=law --rust-faction=condemned \
		--budget=$(or $(PROF_BUDGET),4600) --time-limit=$(or $(PROF_TIME),180) --seed=$(or $(PROF_SEED),92721) --arena=$(or $(PROF_ARENA),sumps) \
		--brains-ab-run=$(or $(AB_SWITCH),all) > $(BUILD_DIR)/ai-ab-match.log 2>&1
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control --green-faction=law --rust-faction=condemned \
		--budget=$(or $(PROF_BUDGET),4600) --time-limit=$(or $(PROF_TIME),180) --seed=$(or $(PROF_SEED),92721) --arena=$(or $(PROF_ARENA),sumps) \
		> $(BUILD_DIR)/ai-ab-match-plain.log 2>&1
	@grep -h '^BRAINS_AB' $(BUILD_DIR)/ai-ab-match.log || { echo "ai-ab-match: no BRAINS_AB line"; exit 1; }
	@a=$$(grep -o '"state_hash":"[0-9a-f]*"' $(BUILD_DIR)/ai-ab-match.log); b=$$(grep -o '"state_hash":"[0-9a-f]*"' $(BUILD_DIR)/ai-ab-match-plain.log); \
		echo "ai-ab-match: A/B run $$a, plain run $$b"; [ -n "$$a" ] && [ "$$a" = "$$b" ] || { echo "ai-ab-match: the A/B changed the run -- a switch is not an equality"; exit 1; }

# ...and both on HIS PATH (perf-play's command line, a display): `--brains-parts` (the brains' parts and call sites per
# tick, BRAINS_PARTS) and `--brains-ab-run=$(AB_SWITCH)` (the round's switches in 30-tick blocks, BRAINS_AB). A
# skirmish's fight is not seeded the way a headless match is, so here the A/B is read from its own two arms only.
ai-ab-play: import ## Round 16: BRAINS_PARTS + BRAINS_AB on a human-side skirmish on his path (perf-play's flags; needs a display; AB_SWITCH=all|<name>|none)
	@mkdir -p $(BUILD_DIR)/perf-play/recordings
	timeout 900 $(GODOT) --path . --resolution $(PERF_PLAY_RES) -- --skirmish --enemy=cpu --seed=$(or $(PROF_PLAY_SEED),92721) \
		--arena=$(PERF_PLAY_ARENA) $(PERF_PLAY_FACTIONS) --announcer=voice --music=on --camera-readout=on --hints=off \
		--announcer-history=off --music-history=off --record-dir=$(CURDIR)/$(BUILD_DIR)/perf-play/recordings \
		--perf-play --perf-scene=$(CURDIR)/$(BUILD_DIR)/ai-ab-play.perf.json \
		--perf-warmup=$(PERF_PLAY_WARMUP) --perf-seconds=$(or $(PROF_PLAY_SECONDS),20) --perf-cycles=1 \
		--brains-parts $(if $(filter none,$(AB_SWITCH)),,--brains-ab-run=$(or $(AB_SWITCH),all)) > $(BUILD_DIR)/ai-ab-play.log 2>&1 || true
	@grep -h '^BRAINS_AB\|^BRAINS_PARTS' $(BUILD_DIR)/ai-ab-play.log | cut -c1-3000 || { echo "ai-ab-play: no BRAINS lines (see build/ai-ab-play.log)"; exit 1; }
