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
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=scenario_perf --units=$(AI_UNITS) $(if $(DETAIL),--profile-parts) $(if $(BRAIN),--green-brain=$(BRAIN) --rust-brain=$(BRAIN))

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
