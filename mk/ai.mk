# Unit and squad AI: behavior scenarios, ladder, cost
# Owner: ai (see _agents/workstreams.md, _agents/unit_ai.md). Included by the root Makefile.

ai-scenarios: import ## Behavior scenarios (seeded mini-battles) faster than real time; FILTER=substring; pending ones may fail
	$(GODOT) --headless --fixed-fps 60 --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=$(FILTER)

ai-perf: import ## AI CPU cost: 50 brains fighting, prints MEASURE ai_usec_per_tick (budget in _agents/unit_ai.md)
	$(GODOT) --headless --fixed-fps 60 --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=scenario_perf

VARIANTS ?= r1,a4,a6
CHAMPION ?= a6
RUNS ?= 4
LADDER_DOCTRINE ?= individuals
ai-ladder: import ## AI ELO ladder: brain VARIANTS (a4,a6) play mirror armies, each seed 4 ways; CHAMPION must be beaten
	$(PYTHON) tools/ai_ladder.py --godot $(GODOT) --variants $(VARIANTS) --champion $(CHAMPION) --runs $(RUNS) \
		--jobs $(JOBS) --doctrine $(LADDER_DOCTRINE) --json $(BUILD_DIR)/ai_ladder.json
