# Round 26 (traffic): friendly vehicles deconflicting. T0's instrument is tests/traffic/traffic_stage.gd (his two cases:
# two friendly squads ordered through each other head-on, and across each other at right angles), run over
# TRAFFIC_CASES (arena,kind) x {both, solo_a, solo_b} x TRAFFIC_SEEDS x TRAFFIC_TICKS (C26.6's start ticks), TRAFFIC_JOBS at
# a time. The table pools them: crews arrived, friendly-stuck crew-seconds, friendly contacts (and fast ones), k-turns
# with a friendly ahead, and the crossing's last arrival over the same squad's solo time (paired by seed and tick).
# TRAFFIC_FLAGS adds probe flags (--brains-off=native, --nav-off=...). Run it on builder0: make remote T=traffic-series.

TRAFFIC_CASES ?= yard_open,head yard_open,cross terminus,head terminus,cross
TRAFFIC_SEEDS ?= 1 2 3
TRAFFIC_TICKS ?= 1 3 6 8 11 16
TRAFFIC_WHICH ?= both solo_a solo_b
TRAFFIC_JOBS ?= 6
TRAFFIC_SECONDS ?= 90
TRAFFIC_OUT ?= $(BUILD_DIR)/traffic-series.jsonl

.PHONY: traffic-series
traffic-series: import ## Round 26 (traffic T0): his two crossing cases (TRAFFIC_CASES arena,kind x both/solo x seeds x start ticks) -> build/traffic-series.jsonl + the pooled table (TRAFFIC_FLAGS for an arm)
	@rm -rf $(BUILD_DIR)/traffic-runs; mkdir -p $(BUILD_DIR)/traffic-runs
	@echo ">> traffic-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | flags '$(TRAFFIC_FLAGS)' | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for case in $(TRAFFIC_CASES); do for which in $(TRAFFIC_WHICH); do for seed in $(TRAFFIC_SEEDS); do for tick in $(TRAFFIC_TICKS); do \
		echo "$$case,$$which,$$seed,$$tick"; done; done; done; done | \
		xargs -P $(TRAFFIC_JOBS) -I{} sh -c 'set -- $$(echo {} | tr "," " "); arena=$$1; kind=$$2; which=$$3; seed=$$4; tick=$$5; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/traffic/traffic_probe.gd -- \
			--arena=$$arena --kind=$$kind --which=$$which --seed=$$seed --seconds=$(TRAFFIC_SECONDS) --lab-start-tick=$$tick \
			$(TRAFFIC_FLAGS) 2>/dev/null | grep -o "TRAFFIC_PROBE {.*" | sed "s/^TRAFFIC_PROBE {/{\"start_tick\":$$tick,/" \
			> $(BUILD_DIR)/traffic-runs/$$arena-$$kind-$$which-$$seed-$$tick.json; \
		[ -s $(BUILD_DIR)/traffic-runs/$$arena-$$kind-$$which-$$seed-$$tick.json ] \
			|| echo "{\"arena\":\"$$arena\",\"kind\":\"$$kind\",\"which\":\"$$which\",\"seed\":$$seed,\"start_tick\":$$tick,\"missing\":true}" \
			> $(BUILD_DIR)/traffic-runs/$$arena-$$kind-$$which-$$seed-$$tick.json'
	@cat $(BUILD_DIR)/traffic-runs/*.json > $(TRAFFIC_OUT)
	@$(PYTHON) tests/traffic/traffic_table.py $(TRAFFIC_OUT)

.PHONY: traffic-trace
traffic-trace: import ## Round 26 (traffic): one traced run of his case (TRAFFIC_ARENA=yard_open TRAFFIC_KIND=head TRAFFIC_SEED=1) -> build/traffic-trace.log (TRAFFIC_TRACK lines every 0.5 s)
	@mkdir -p $(BUILD_DIR)
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/traffic/traffic_probe.gd -- \
		--arena=$(or $(TRAFFIC_ARENA),yard_open) --kind=$(or $(TRAFFIC_KIND),head) --which=$(or $(TRAFFIC_WHICH_ONE),both) \
		--seed=$(or $(TRAFFIC_SEED),1) --seconds=$(TRAFFIC_SECONDS) --trace=on $(TRAFFIC_FLAGS) > $(BUILD_DIR)/traffic-trace.log 2>&1 || true
	@grep -o 'TRAFFIC_PROBE {.*' $(BUILD_DIR)/traffic-trace.log || (tail -30 $(BUILD_DIR)/traffic-trace.log && exit 1)

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
