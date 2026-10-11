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
	@for case in $(TRAFFIC_CENSUS_CASES); do for seed in $(TRAFFIC_CENSUS_SEEDS); do echo "$$case,$$seed"; done; done | \
		xargs -P $(TRAFFIC_JOBS) -I{} sh -c 'set -- $$(echo {} | tr "," " "); out=$(BUILD_DIR)/traffic-census-runs/$$1-$$2-$$3-$$4-$$6.json; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/traffic/census_probe.gd -- \
			--arena=$$1 --green=$$2 --rust=$$3 --credits=$$4 --army=$$5 --seed=$$6 --seconds=$(TRAFFIC_CENSUS_SECONDS) $(TRAFFIC_FLAGS) \
			2>/dev/null | grep -o "TRAFFIC_CENSUS {.*" | sed "s/^TRAFFIC_CENSUS //" > $$out; \
		[ -s $$out ] || echo "{\"arena\":\"$$1\",\"seed\":$$6,\"credits\":$$4,\"missing\":true}" > $$out'
	@cat $(BUILD_DIR)/traffic-census-runs/*.json > $(BUILD_DIR)/traffic-census.jsonl
	@$(PYTHON) tests/traffic/census_table.py $(BUILD_DIR)/traffic-census.jsonl
