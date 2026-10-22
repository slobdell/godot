# Round 38 (settle): how a squad SITS once it is there (deploy, halt shape, seat deal, parked hold). _agents/streams/settle.md

# S1: orders' probe runs traced at the deploy (`--deploy-trace`: one DEPLOY_TRACE line per deploy, every squad) plus squad N's
# crews every second, per SETTLE_TRACE_CASES entry "map:squads:route:seed:squad", SETTLE_TRACE_FLAGS added to every run ->
# build/settle-trace/<entry>.log
SETTLE_TRACE_CASES ?= terminus:5:click:3767:4 terminus:5:click:3772:4
SETTLE_TRACE_FLAGS ?=
.PHONY: settle-trace
settle-trace: native-for-check import ## Round 38 (settle S1): orders-probe runs traced at the deploy, SETTLE_TRACE_CASES -> build/settle-trace/*.log
	@rm -rf $(BUILD_DIR)/settle-trace && mkdir -p $(BUILD_DIR)/settle-trace
	@echo ">> settle-trace on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | flags '$(SETTLE_TRACE_FLAGS)'"
	@for c in $(SETTLE_TRACE_CASES); do IFS=: read map n route seed sq <<< "$$c"; \
		timeout 600 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/orders_probe.gd -- --arena=$$map --seed=$$seed \
			--probe-squads=$$n --probe-route=$$route --probe-arm=main --probe-trace=$$sq --deploy-trace $(SETTLE_TRACE_FLAGS) \
			> $(BUILD_DIR)/settle-trace/$$map-$$n-$$route-$$seed-sq$$sq.log 2>&1 || true; \
		echo "$$c: $$(grep -c '^DEPLOY_TRACE' $(BUILD_DIR)/settle-trace/$$map-$$n-$$route-$$seed-sq$$sq.log) deploys"; done

# S1's judged series (the bar: _agents/streams/settle.md Status), one builder0 lane: orders' no-fight probe (12 cells x
# SETTLE_SEEDS), the fight probe (locks/crossing/terminus x 3 5 squads x click x SETTLE_FIGHT_SEEDS), the CPU census
# (traffic-census' 3 cases x SETTLE_CENSUS_SEEDS) per arm, then tests/settle/settle_judge.py -> build/settle-series/.
# Arms: SETTLE_BASE / SETTLE_ARM "name:flag,flag" (the arm also traces its deploys, the counter).
SETTLE_SEEDS ?= $(shell seq 3861 3872)
SETTLE_FIGHT_SEEDS ?= $(shell seq 3873 3878)
SETTLE_CENSUS_SEEDS ?= 3861 3862 3863
SETTLE_BASE ?= main:--deploy-trace
SETTLE_ARM ?= fit:--deploy-fit=on,--deploy-trace
SETTLE_DIR := $(BUILD_DIR)/settle-series
.PHONY: settle-series
settle-series: native-for-check import ## Round 38 (settle): S1's judged series (no-fight probe, fight probe, CPU census per arm) -> build/settle-series/verdict.txt
	@rm -rf $(SETTLE_DIR) && mkdir -p $(SETTLE_DIR)
	@echo ">> settle-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | base '$(SETTLE_BASE)' arm '$(SETTLE_ARM)'" | tee $(SETTLE_DIR)/header.txt
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ARMS="$(SETTLE_BASE) $(SETTLE_ARM)" ORDERS_PROBE_SEEDS="$(SETTLE_SEEDS)" \
		ORDERS_PROBE_DIR=$(SETTLE_DIR)/probe > $(SETTLE_DIR)/probe.out 2>&1 || true
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ROUTES=click \
		ORDERS_PROBE_ARMS="$(SETTLE_BASE),--probe-fight=on,--probe-budget=1500 $(SETTLE_ARM),--probe-fight=on,--probe-budget=1500" \
		ORDERS_PROBE_SEEDS="$(SETTLE_FIGHT_SEEDS)" ORDERS_PROBE_DIR=$(SETTLE_DIR)/fight > $(SETTLE_DIR)/fight.out 2>&1 || true
	@for arm in "$(SETTLE_BASE)" "$(SETTLE_ARM)"; do name=$${arm%%:*}; flags=$$(echo "$${arm#*:}" | tr "," " "); \
		$(MAKE) --no-print-directory traffic-census TRAFFIC_CENSUS_SEEDS="$(SETTLE_CENSUS_SEEDS)" TRAFFIC_FLAGS="$$flags" > $(SETTLE_DIR)/census-$$name.out 2>&1 || true; \
		cp $(BUILD_DIR)/traffic-census.jsonl $(SETTLE_DIR)/census-$$name.jsonl || true; done
	@cd $(SETTLE_DIR) && $(PYTHON) $(CURDIR)/tests/settle/settle_judge.py s1 probe fight census-$(firstword $(subst :, ,$(SETTLE_BASE))).jsonl \
		census-$(firstword $(subst :, ,$(SETTLE_ARM))).jsonl $(firstword $(subst :, ,$(SETTLE_BASE))) $(firstword $(subst :, ,$(SETTLE_ARM))) | tee verdict.txt
