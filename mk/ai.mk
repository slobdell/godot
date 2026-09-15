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

ai-shots: import ## Staged AI fights with driving trails, frames in build/ai-shots/ (needs a display: make remote T=ai-shots; STAGE=duel|scout_runs|brawl)
	mkdir -p $(BUILD_DIR)/ai-shots
	$(GODOT) --path . --fixed-fps 60 --resolution 1280x960 --script res://tests/ai_scenarios/watch_shots.gd -- $(if $(STAGE),--stage=$(STAGE)) \
		2>&1 | tee $(BUILD_DIR)/ai-shots/log.txt | grep -E "AI_SHOT|ERROR" || true
	grep -q AI_SHOTS_DONE $(BUILD_DIR)/ai-shots/log.txt
