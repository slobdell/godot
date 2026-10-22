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

# S1/S2's judged series (the bars: _agents/streams/settle.md Status), one builder0 lane: orders' no-fight probe (12 cells x
# SETTLE_SEEDS), the fight probe (locks/crossing/terminus x 3 squads x click x SETTLE_FIGHT_SEEDS: the probe's fight army is
# the 3-squad one), the CPU census
# (traffic-census' 3 cases x SETTLE_CENSUS_SEEDS), for SETTLE_BASE and every SETTLE_ARMS entry "name:flag,flag" (one base
# shared by every arm), then tests/settle/settle_judge.py per arm (mode: fit* -> s1, latch* -> s2) -> build/settle-series/.
SETTLE_SEEDS ?= $(shell seq 3861 3872)
SETTLE_FIGHT_SEEDS ?= $(shell seq 3873 3884)
SETTLE_CENSUS_SEEDS ?= 3861 3862 3863
SETTLE_BASE ?= main:--deploy-trace
SETTLE_ARMS ?= fit:--deploy-fit=on,--deploy-trace latch:--deploy-latch=on,--deploy-trace
SETTLE_DIR := $(BUILD_DIR)/settle-series
_settle_name = $(firstword $(subst :, ,$(1)))
.PHONY: settle-series
settle-series: native-for-check import ## Round 38 (settle): S1/S2's judged series (no-fight probe, fight probe, CPU census; SETTLE_BASE + SETTLE_ARMS) -> build/settle-series/verdict.txt
	@rm -rf $(SETTLE_DIR) && mkdir -p $(SETTLE_DIR)
	@echo ">> settle-series on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | base '$(SETTLE_BASE)' arms '$(SETTLE_ARMS)'" | tee $(SETTLE_DIR)/header.txt
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ARMS="$(SETTLE_BASE) $(SETTLE_ARMS)" ORDERS_PROBE_SEEDS="$(SETTLE_SEEDS)" \
		ORDERS_PROBE_DIR=$(SETTLE_DIR)/probe > $(SETTLE_DIR)/probe.out 2>&1 || true
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ROUTES=click ORDERS_PROBE_SQUADS=3 \
		ORDERS_PROBE_ARMS="$(foreach a,$(SETTLE_BASE) $(SETTLE_ARMS),$(a),--probe-fight=on,--probe-budget=1500)" \
		ORDERS_PROBE_SEEDS="$(SETTLE_FIGHT_SEEDS)" ORDERS_PROBE_DIR=$(SETTLE_DIR)/fight > $(SETTLE_DIR)/fight.out 2>&1 || true
	@for arm in $(SETTLE_BASE) $(SETTLE_ARMS); do name=$${arm%%:*}; flags=$$(echo "$${arm#*:}" | tr "," " "); \
		$(MAKE) --no-print-directory traffic-census TRAFFIC_CENSUS_SEEDS="$(SETTLE_CENSUS_SEEDS)" TRAFFIC_FLAGS="$$flags" > $(SETTLE_DIR)/census-$$name.out 2>&1 || true; \
		cp $(BUILD_DIR)/traffic-census.jsonl $(SETTLE_DIR)/census-$$name.jsonl || true; done
	@cd $(SETTLE_DIR) && : > verdict.txt && for arm in $(SETTLE_ARMS); do name=$${arm%%:*}; case $$name in fit*) mode=s1;; *) mode=s2;; esac; \
		$(PYTHON) $(CURDIR)/tests/settle/settle_judge.py $$mode probe fight census-$(call _settle_name,$(SETTLE_BASE)).jsonl census-$$name.jsonl \
			$(call _settle_name,$(SETTLE_BASE)) $$name | tee -a verdict.txt || true; done

# S3 (O2 on settle) + the stretch (DEPLOY_HOLD): the fight probe only (locks/crossing/terminus x 3 squads x click x
# SETTLE_S3_SEEDS), arms latch (S2 alone: the base), held (+ --deploy-hold=on), o2 (+ --parked-hold=on), then
# tests/settle/settle_judge.py s3 -> build/settle-s3/verdict.txt. Runs after S2's verdict (the latch arm is its base).
SETTLE_S3_SEEDS ?= $(shell seq 3891 3902)
SETTLE_S3_ARMS ?= latch:--deploy-latch=on,--probe-fight=on,--probe-budget=1500 held:--deploy-latch=on,--deploy-hold=on,--probe-fight=on,--probe-budget=1500 o2:--deploy-latch=on,--deploy-hold=on,--parked-hold=on,--probe-fight=on,--probe-budget=1500
.PHONY: settle-s3
settle-s3: native-for-check import ## Round 38 (settle S3 + stretch): the fight probe, latch v held v o2 -> build/settle-s3/verdict.txt
	@rm -rf $(BUILD_DIR)/settle-s3 && mkdir -p $(BUILD_DIR)/settle-s3
	@echo ">> settle-s3 on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | arms '$(SETTLE_S3_ARMS)'" | tee $(BUILD_DIR)/settle-s3/header.txt
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ROUTES=click ORDERS_PROBE_SQUADS=3 ORDERS_PROBE_ARMS="$(SETTLE_S3_ARMS)" \
		ORDERS_PROBE_SEEDS="$(SETTLE_S3_SEEDS)" ORDERS_PROBE_DIR=$(BUILD_DIR)/settle-s3/fight > $(BUILD_DIR)/settle-s3/fight.out 2>&1 || true
	@cd $(BUILD_DIR)/settle-s3 && $(PYTHON) $(CURDIR)/tests/settle/settle_judge.py s3 fight latch held o2 | tee verdict.txt || true

# The fight read's top-up (the re-file in settle.md Status): SETTLE_BASE + SETTLE_ARMS on the fight probe only, 3 squads,
# SETTLE_TOPUP_SEEDS -> build/settle-topup/fight (merged with an earlier run's fight/ by settle_judge's caller).
SETTLE_TOPUP_SEEDS ?= $(shell seq 3879 3884)
.PHONY: settle-fight-topup
settle-fight-topup: native-for-check import ## Round 38 (settle): the S1/S2 fight read's top-up seeds -> build/settle-topup/fight
	@rm -rf $(BUILD_DIR)/settle-topup && mkdir -p $(BUILD_DIR)/settle-topup
	@echo ">> settle-fight-topup on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off)" | tee $(BUILD_DIR)/settle-topup/header.txt
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ROUTES=click ORDERS_PROBE_SQUADS=3 \
		ORDERS_PROBE_ARMS="$(foreach a,$(SETTLE_BASE) $(SETTLE_ARMS),$(a),--probe-fight=on,--probe-budget=1500)" \
		ORDERS_PROBE_SEEDS="$(SETTLE_TOPUP_SEEDS)" ORDERS_PROBE_DIR=$(BUILD_DIR)/settle-topup/fight > $(BUILD_DIR)/settle-topup/fight.out 2>&1 || true

# R38.10: S2's re-read, once (the same arm, the same bar; the never-in guard filed by the orchestrator before numbers):
# the no-fight probe 12 cells x SETTLE_RR_SEEDS, the fight probe's 3-squad top-up (SETTLE_TOPUP_SEEDS, read with the first
# read's 3873-3878) and its 5-squad cells at --probe-budget=3000 (SETTLE_FIGHT_SEEDS), the census x SETTLE_RR_CENSUS_SEEDS,
# for main and latch -> build/settle-rr/ (judged on the laptop with the first read's fight/ merged: settle.md Status).
SETTLE_RR_SEEDS ?= $(shell seq 3903 3914)
SETTLE_RR_CENSUS_SEEDS ?= 3903 3904 3905
SETTLE_RR_JOBS ?= 4
SETTLE_RR_ARMS ?= main:--deploy-trace latch:--deploy-latch=on,--deploy-trace
SETTLE_RR := $(BUILD_DIR)/settle-rr
.PHONY: settle-s2-reread
settle-s2-reread: native-for-check import ## Round 38 (settle, R38.10): S2's re-read on fresh seeds (main v latch) -> build/settle-rr/
	@rm -rf $(SETTLE_RR) && mkdir -p $(SETTLE_RR)
	@echo ">> settle-s2-reread on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | jobs $(SETTLE_RR_JOBS)" | tee $(SETTLE_RR)/header.txt
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ARMS="$(SETTLE_RR_ARMS)" ORDERS_PROBE_SEEDS="$(SETTLE_RR_SEEDS)" \
		ORDERS_PROBE_JOBS=$(SETTLE_RR_JOBS) ORDERS_PROBE_DIR=$(SETTLE_RR)/probe > $(SETTLE_RR)/probe.out 2>&1 || true
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ROUTES=click ORDERS_PROBE_SQUADS=3 ORDERS_PROBE_JOBS=$(SETTLE_RR_JOBS) \
		ORDERS_PROBE_ARMS="$(foreach a,$(SETTLE_RR_ARMS),$(a),--probe-fight=on,--probe-budget=1500)" \
		ORDERS_PROBE_SEEDS="$(SETTLE_TOPUP_SEEDS)" ORDERS_PROBE_DIR=$(SETTLE_RR)/fight3 > $(SETTLE_RR)/fight3.out 2>&1 || true
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ROUTES=click ORDERS_PROBE_SQUADS=5 ORDERS_PROBE_JOBS=$(SETTLE_RR_JOBS) \
		ORDERS_PROBE_ARMS="$(foreach a,$(SETTLE_RR_ARMS),$(a),--probe-fight=on,--probe-budget=3000)" \
		ORDERS_PROBE_SEEDS="$(SETTLE_FIGHT_SEEDS)" ORDERS_PROBE_DIR=$(SETTLE_RR)/fight5 > $(SETTLE_RR)/fight5.out 2>&1 || true
	@for arm in $(SETTLE_RR_ARMS); do name=$${arm%%:*}; flags=$$(echo "$${arm#*:}" | tr "," " "); \
		$(MAKE) --no-print-directory traffic-census TRAFFIC_JOBS=$(SETTLE_RR_JOBS) TRAFFIC_CENSUS_SEEDS="$(SETTLE_RR_CENSUS_SEEDS)" TRAFFIC_FLAGS="$$flags" > $(SETTLE_RR)/census-$$name.out 2>&1 || true; \
		cp $(BUILD_DIR)/traffic-census.jsonl $(SETTLE_RR)/census-$$name.jsonl || true; done
