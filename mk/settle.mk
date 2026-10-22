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
