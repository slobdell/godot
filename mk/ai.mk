# Unit and squad AI: behavior scenarios, ladder, cost
# Owner: ai (see _agents/workstreams.md, _agents/unit_ai.md). Included by the root Makefile.

ai-scenarios: import ## Behavior scenarios (seeded mini-battles) faster than real time; FILTER=substring; pending ones may fail
	$(GODOT) --headless --fixed-fps 60 --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=$(FILTER)

UNITS ?= 60
ai-perf: import ## AI CPU cost: UNITS brains fighting (default 60, the round-4 target), prints MEASURE ai_usec_per_tick (budget in _agents/unit_ai.md); BRAIN=a6 profiles another brain variant; DETAIL=1 breaks moving and shooting down further
	$(GODOT) --headless --fixed-fps 60 --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=scenario_perf --units=$(UNITS) $(if $(DETAIL),--profile-parts) $(if $(BRAIN),--green-brain=$(BRAIN) --rust-brain=$(BRAIN))

VARIANTS ?= r1,a4,a6
CHAMPION ?= a6
RUNS ?= 4
LADDER_DOCTRINE ?= individuals
ai-ladder: import ## AI ELO ladder: brain VARIANTS (a6,x3; x3+v3 = with CPU commander v3) play mirror armies (LADDER_DOCTRINE: a file or cpu:<archetype>, LADDER_EXTRA=--budget=1000), each seed 4 ways; CHAMPION must be beaten
	$(PYTHON) tools/ai_ladder.py --godot $(GODOT) --variants $(VARIANTS) --champion $(CHAMPION) --runs $(RUNS) \
		--jobs $(JOBS) --doctrine $(LADDER_DOCTRINE) $(if $(FIRST_SEED),--first-seed $(FIRST_SEED)) $(if $(LADDER_EXTRA),--extra="$(LADDER_EXTRA)") --json $(BUILD_DIR)/ai_ladder.json

ai-shots: import ## Staged AI fights with driving trails, frames in build/ai-shots/ (needs a display: make remote T=ai-shots; STAGE=duel|scout_runs|brawl)
	mkdir -p $(BUILD_DIR)/ai-shots
	$(GODOT) --path . --fixed-fps 60 --resolution 1280x960 --script res://tests/ai_scenarios/watch_shots.gd -- $(if $(STAGE),--stage=$(STAGE)) \
		2>&1 | tee $(BUILD_DIR)/ai-shots/log.txt | grep -E "AI_SHOT|ERROR" || true
	grep -q AI_SHOTS_DONE $(BUILD_DIR)/ai-shots/log.txt
