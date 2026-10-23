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
SETTLE_RR_JOBS ?= 14
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

# R38.11: S1 v2 (deciding = the deploy leg), on seeds never read for S1: the no-fight probe 12 cells x SETTLE_V2_SEEDS, the
# fight probe 3-squad (budget 1500) and 5-squad (budget 3000) cells x SETTLE_V2_FIGHT_SEEDS, main v fit -> build/settle-s1v2/
SETTLE_V2_SEEDS ?= $(shell seq 3921 3932)
SETTLE_V2_FIGHT_SEEDS ?= $(shell seq 3933 3944)
SETTLE_V2_JOBS ?= 14
SETTLE_V2_ARMS ?= main:--deploy-trace fit:--deploy-fit=on,--deploy-trace
SETTLE_V2 := $(BUILD_DIR)/settle-s1v2
.PHONY: settle-s1v2
settle-s1v2: native-for-check import ## Round 38 (settle, R38.11): S1 v2's series (main v fit) -> build/settle-s1v2/verdict.txt
	@rm -rf $(SETTLE_V2) && mkdir -p $(SETTLE_V2)
	@echo ">> settle-s1v2 on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | jobs $(SETTLE_V2_JOBS)" | tee $(SETTLE_V2)/header.txt
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ARMS="$(SETTLE_V2_ARMS)" ORDERS_PROBE_SEEDS="$(SETTLE_V2_SEEDS)" \
		ORDERS_PROBE_JOBS=$(SETTLE_V2_JOBS) ORDERS_PROBE_DIR=$(SETTLE_V2)/probe > $(SETTLE_V2)/probe.out 2>&1 || true
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ROUTES=click ORDERS_PROBE_SQUADS=3 ORDERS_PROBE_JOBS=$(SETTLE_V2_JOBS) \
		ORDERS_PROBE_ARMS="$(foreach a,$(SETTLE_V2_ARMS),$(a),--probe-fight=on,--probe-budget=1500)" \
		ORDERS_PROBE_SEEDS="$(SETTLE_V2_FIGHT_SEEDS)" ORDERS_PROBE_DIR=$(SETTLE_V2)/fight3 > $(SETTLE_V2)/fight3.out 2>&1 || true
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ROUTES=click ORDERS_PROBE_SQUADS=5 ORDERS_PROBE_JOBS=$(SETTLE_V2_JOBS) \
		ORDERS_PROBE_ARMS="$(foreach a,$(SETTLE_V2_ARMS),$(a),--probe-fight=on,--probe-budget=3000)" \
		ORDERS_PROBE_SEEDS="$(SETTLE_V2_FIGHT_SEEDS)" ORDERS_PROBE_DIR=$(SETTLE_V2)/fight5 > $(SETTLE_V2)/fight5.out 2>&1 || true
	@cd $(SETTLE_V2) && $(PYTHON) $(CURDIR)/tests/settle/settle_judge.py s1v2 probe fight3 fight5 main fit | tee verdict.txt || true

# R38.15: S2 v3, the same arm (main v latch) on seeds never read for S2, its first-shape guard read against the ground each
# squad stands on (ElementPlan's STAND_TRACE under --deploy-trace) -> build/settle-s2v3/verdict.txt.
# settle-s2v3-context: the R38.10 re-read's no-fight seeds again, only to print that guard's counts as the bar's context.
SETTLE_V3_SEEDS ?= $(shell seq 4001 4012)
SETTLE_V3_FIGHT_SEEDS ?= $(shell seq 4013 4024)
SETTLE_V3_CENSUS_SEEDS ?= 4001 4002 4003
SETTLE_V3_JOBS ?= 14
SETTLE_V3_ARMS ?= main:--deploy-trace latch:--deploy-latch=on,--deploy-trace
SETTLE_V3 := $(BUILD_DIR)/settle-s2v3
SETTLE_V3_CTX := $(BUILD_DIR)/settle-s2v3-context
.PHONY: settle-s2v3 settle-s2v3-context
settle-s2v3: native-for-check import ## Round 38 (settle, R38.15): S2 v3's series (main v latch, seeds 4001-4024) -> build/settle-s2v3/verdict.txt
	@rm -rf $(SETTLE_V3) && mkdir -p $(SETTLE_V3)
	@echo ">> settle-s2v3 on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | jobs $(SETTLE_V3_JOBS)" | tee $(SETTLE_V3)/header.txt
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ARMS="$(SETTLE_V3_ARMS)" ORDERS_PROBE_SEEDS="$(SETTLE_V3_SEEDS)" \
		ORDERS_PROBE_JOBS=$(SETTLE_V3_JOBS) ORDERS_PROBE_DIR=$(SETTLE_V3)/probe > $(SETTLE_V3)/probe.out 2>&1 || true
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ROUTES=click ORDERS_PROBE_SQUADS=3 ORDERS_PROBE_JOBS=$(SETTLE_V3_JOBS) \
		ORDERS_PROBE_ARMS="$(foreach a,$(SETTLE_V3_ARMS),$(a),--probe-fight=on,--probe-budget=1500)" \
		ORDERS_PROBE_SEEDS="$(SETTLE_V3_FIGHT_SEEDS)" ORDERS_PROBE_DIR=$(SETTLE_V3)/fight3 > $(SETTLE_V3)/fight3.out 2>&1 || true
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ROUTES=click ORDERS_PROBE_SQUADS=5 ORDERS_PROBE_JOBS=$(SETTLE_V3_JOBS) \
		ORDERS_PROBE_ARMS="$(foreach a,$(SETTLE_V3_ARMS),$(a),--probe-fight=on,--probe-budget=3000)" \
		ORDERS_PROBE_SEEDS="$(SETTLE_V3_FIGHT_SEEDS)" ORDERS_PROBE_DIR=$(SETTLE_V3)/fight5 > $(SETTLE_V3)/fight5.out 2>&1 || true
	@for arm in $(SETTLE_V3_ARMS); do name=$${arm%%:*}; flags=$$(echo "$${arm#*:}" | tr "," " "); \
		$(MAKE) --no-print-directory traffic-census TRAFFIC_JOBS=$(SETTLE_V3_JOBS) TRAFFIC_CENSUS_SEEDS="$(SETTLE_V3_CENSUS_SEEDS)" TRAFFIC_FLAGS="$$flags" > $(SETTLE_V3)/census-$$name.out 2>&1 || true; \
		cp $(BUILD_DIR)/traffic-census.jsonl $(SETTLE_V3)/census-$$name.jsonl || true; done
	@cd $(SETTLE_V3) && $(PYTHON) $(CURDIR)/tests/settle/settle_judge.py s2v3 probe fight3 fight5 census-main.jsonl census-latch.jsonl main latch | tee verdict.txt || true

settle-s2v3-context: native-for-check import ## Round 38 (settle, R38.15): S2 v3's guard on the re-read's seeds 3903-3914 (context, not judged) -> build/settle-s2v3-context/
	@rm -rf $(SETTLE_V3_CTX) && mkdir -p $(SETTLE_V3_CTX)
	@echo ">> settle-s2v3-context on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | jobs $(SETTLE_V3_JOBS)" | tee $(SETTLE_V3_CTX)/header.txt
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ARMS="$(SETTLE_V3_ARMS)" ORDERS_PROBE_SEEDS="$(SETTLE_RR_SEEDS)" \
		ORDERS_PROBE_JOBS=$(SETTLE_V3_JOBS) ORDERS_PROBE_DIR=$(SETTLE_V3_CTX)/probe > $(SETTLE_V3_CTX)/probe.out 2>&1 || true
	@cd $(SETTLE_V3_CTX) && for ref in anchor stand; do SETTLE_V3_REFERENCE=$$ref $(PYTHON) -c "import sys; sys.path.insert(0, '$(CURDIR)/tests/settle'); import settle_judge as sj, orders_judge as oj, os; \
		rows = oj.load('probe/rows.jsonl'); b, n = sj.keyed(rows, 'main'), sj.keyed(rows, 'latch'); c = [k for k in b if k in n]; \
		l = []; sj.shape_wrong('probe', 'main', 'latch', b, n, c, l); sj.shape_differs('probe', 'main', 'latch', b, n, c, l); print('\n'.join(l))"; done | tee context.txt || true

# R38.17: S1 v3 = S1 v2's series and lines (judge `settle_judge.py s1v2`) on the fit that keeps main's deploy unless it
# turns, seeds never read for S1: no-fight 4201-4212, fight3/fight5 4213-4224 -> build/settle-s1v3/verdict.txt.
.PHONY: settle-s1v3
settle-s1v3: ## Round 38 (settle, R38.17): S1 v3's series (main v fit, seeds 4201-4224) -> build/settle-s1v3/verdict.txt
	@$(MAKE) --no-print-directory settle-s1v2 SETTLE_V2="$(BUILD_DIR)/settle-s1v3" SETTLE_V2_SEEDS="$$(seq 4201 4212)" \
		SETTLE_V2_FIGHT_SEEDS="$$(seq 4213 4224)"
