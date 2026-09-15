# Unit and squad AI: behavior scenarios, ladder, cost
# Owner: ai (see _agents/workstreams.md, _agents/unit_ai.md). Included by the root Makefile.

ai-scenarios: import ## Behavior scenarios (seeded mini-battles) faster than real time; FILTER=substring; pending ones may fail
	$(GODOT) --headless --fixed-fps 60 --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=$(FILTER)

ai-perf: import ## AI CPU cost: 50 brains fighting, prints MEASURE ai_usec_per_tick (budget in _agents/unit_ai.md)
	$(GODOT) --headless --fixed-fps 60 --path . --script res://tests/ai_scenarios/run_scenarios.gd -- --filter=scenario_perf
