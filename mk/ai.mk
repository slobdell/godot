# Unit and squad AI: behavior scenarios, ladder, cost
# Owner: ai (see _agents/workstreams.md, _agents/unit_ai.md). Included by the root Makefile.

ai-scenarios: import ## Behavior scenarios (seeded mini-battles) faster than real time; FILTER=substring; pending ones may fail
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=$(FILTER)

# Knobs this file owns carry its prefix (orchestrator, round 6: `UNITS ?= 60` here silently made another stream's "30
# units" run 60). The old names still work, but ONLY when typed on the command line: $(origin) keeps another file's
# default from ever reaching these targets. Each target prints what its knobs resolved to.
cmdline = $(if $(filter command line,$(origin $(1))),$($(1)),$(2))
AI_UNITS ?= $(call cmdline,UNITS,60)
ai-perf: import ## AI CPU cost: AI_UNITS brains fighting (default 60, the round-4 target), prints MEASURE ai_usec_per_tick (budget in _agents/unit_ai.md); BRAIN=a6 profiles another brain variant; DETAIL=1 breaks moving and shooting down further
	@echo ">> ai-perf: AI_UNITS=$(AI_UNITS) BRAIN=$(BRAIN)"
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=scenario_perf --units=$(AI_UNITS) $(if $(DETAIL),--profile-parts) $(if $(BRAIN),--green-brain=$(BRAIN) --rust-brain=$(BRAIN)) $(if $(PERF_REFUSE),--perf-refuse=$(PERF_REFUSE))

# Round 14 (squad Q2; verification.md rule 3): scenario_perf refuses to judge its budget when its reference workload
# runs more than 1.5x this machine's nominal. The nominal is recorded HERE, on an idle machine, and copied by hand
# into tests/ai_scenarios/perf_nominal.json (make remote copies back build/ and nothing else). PERF_REFUSE=off on
# ai-perf is the mutation arm: it judges regardless of load, as the scenario did before round 14.
ai-perf-nominal: import ## Record this machine's scenario_perf yardstick (run it IDLE; on builder0: make remote T=ai-perf-nominal) -> build/perf_nominal.txt, then copy the line into tests/ai_scenarios/perf_nominal.json
	@echo ">> ai-perf-nominal on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg) | $$(pgrep -c -f 'Godot_v' || echo 0) other godot"
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=scenario_perf \
		--perf-record-nominal --perf-refuse=off 2>&1 | grep -E "PERF_NOMINAL|MEASURE (perf_reference|ai_usec_per_tick )|PASS|FAIL|ERROR" | tee $(BUILD_DIR)/perf_nominal.txt
	@grep -q '^PERF_NOMINAL ' $(BUILD_DIR)/perf_nominal.txt

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
ai-perf-leak: import ## Round 15 (squad P3): scenario_perf's fight alone vs after each preceding scenario (and all of them): one PERF_LEAK line each with LOS queries and units alive; FAILS unless every fight is the one it fights alone. PERF_START=loose is the pre-round-15 start (the mutation arm)
	@mkdir -p $(BUILD_DIR)/perf-leak; rm -f $(BUILD_DIR)/perf-leak/*.log
	@for before in alone $(PERF_LEAK_BEFORE) all; do \
		case $$before in alone) f="scenario_perf";; all) f="$$(echo $(PERF_LEAK_BEFORE) | tr ' ' '|')|scenario_perf";; *) f="$$before|scenario_perf";; esac; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- "--filter=$$f" --perf-refuse=off \
			$(if $(PERF_START),--perf-start=$(PERF_START)) > $(BUILD_DIR)/perf-leak/$$before.log 2>&1 & \
		while [ $$(jobs -r | wc -l) -ge $(or $(PERF_LEAK_JOBS),4) ]; do sleep 1; done; \
	done; wait; \
	for before in alone $(PERF_LEAK_BEFORE) all; do \
		echo "PERF_LEAK $$before | $$(grep -oE 'perf_start .*' $(BUILD_DIR)/perf-leak/$$before.log | head -1) | $$(grep -oE '[0-9]+ ticks fighting, [0-9]+ alive at the end; LOS [0-9]+ queries, [0-9]+ computed' $(BUILD_DIR)/perf-leak/$$before.log || echo NO_MEASURE)"; \
	done | tee $(BUILD_DIR)/perf-leak/summary.txt; \
	fights=$$(sed -E 's/^PERF_LEAK [^|]*\|[^|]*\| //' $(BUILD_DIR)/perf-leak/summary.txt | sort -u | wc -l); \
	if [ "$$fights" -eq 1 ] && ! grep -q NO_MEASURE $(BUILD_DIR)/perf-leak/summary.txt; then echo "ai-perf-leak: ONE fight in all $$(wc -l < $(BUILD_DIR)/perf-leak/summary.txt) runs"; \
	else echo "ai-perf-leak: $$fights DIFFERENT fights -- scenario_perf is not measuring one battle"; exit 1; fi
