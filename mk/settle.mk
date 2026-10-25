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
# SETTLE_S3_SEEDS), arms latch (S2 v4, the shipped anchor latch, R38.33: the base), held (+ --deploy-hold=on), o2 (+ --parked-hold=on), then
# tests/settle/settle_judge.py s3 -> build/settle-s3/verdict.txt. Runs after S2's verdict (the latch arm is its base).
SETTLE_S3_SEEDS ?= $(shell seq 3891 3902)
SETTLE_S3_ARMS ?= latch:--deploy-latch=anchor,--probe-fight=on,--probe-budget=1500 held:--deploy-latch=anchor,--deploy-hold=on,--probe-fight=on,--probe-budget=1500 o2:--deploy-latch=anchor,--deploy-hold=on,--parked-hold=on,--probe-fight=on,--probe-budget=1500
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
SETTLE_V2_JUDGE ?= s1v2
SETTLE_V2_PAIR ?= main fit
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
	@cd $(SETTLE_V2) && $(PYTHON) $(CURDIR)/tests/settle/settle_judge.py $(SETTLE_V2_JUDGE) probe fight3 fight5 $(SETTLE_V2_PAIR) | tee verdict.txt || true

# R38.15: S2 v3, the same arm (main v latch) on seeds never read for S2, its first-shape guard read against the ground each
# squad stands on (ElementPlan's STAND_TRACE under --deploy-trace) -> build/settle-s2v3/verdict.txt.
# settle-s2v3-context: the R38.10 re-read's no-fight seeds again, only to print that guard's counts as the bar's context.
SETTLE_V3_SEEDS ?= $(shell seq 4001 4012)
SETTLE_V3_FIGHT_SEEDS ?= $(shell seq 4013 4024)
SETTLE_V3_CENSUS_SEEDS ?= 4001 4002 4003
SETTLE_V3_JOBS ?= 14
SETTLE_V3_ARMS ?= main:--deploy-trace latch:--deploy-latch=on,--deploy-trace
SETTLE_V3 := $(BUILD_DIR)/settle-s2v3
SETTLE_V3_NEW ?= latch
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
	@cd $(SETTLE_V3) && $(PYTHON) $(CURDIR)/tests/settle/settle_judge.py s2v3 probe fight3 fight5 census-main.jsonl census-$(SETTLE_V3_NEW).jsonl main $(SETTLE_V3_NEW) | tee verdict.txt || true

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
	@$(MAKE) --no-print-directory settle-s1v2 SETTLE_V2="$(BUILD_DIR)/settle-s1v3" SETTLE_V2_SEEDS="$$(seq -s " " 4201 4212)" \
		SETTLE_V2_FIGHT_SEEDS="$$(seq -s " " 4213 4224)"

# R38.34: S1 v4 = the fit stacked on the shipped latch (both arms latch-ON: the default since b3ad7baa4), S1 v2's series,
# guards JUDGED as filed, the deciding line REPORTED; seeds never read: no-fight 4401-4412, fights 4413-4424.
.PHONY: settle-s1v4
settle-s1v4: ## Round 38 (settle, R38.34): the fit on the latch-ON main (seeds 4401-4424) -> build/settle-s1v4/verdict.txt
	@SETTLE_S1_DECIDING_JUDGED=0 $(MAKE) --no-print-directory settle-s1v2 SETTLE_V2="$(BUILD_DIR)/settle-s1v4" \
		SETTLE_V2_SEEDS="$$(seq -s " " 4401 4412)" SETTLE_V2_FIGHT_SEEDS="$$(seq -s " " 4413 4424)"

# R38.37: S1 v5 = the fit with the street cap (--deploy-fit=street) on the latch-ON main, S1 v4's lines (guards judged,
# deciding reported) plus the street axis reported per cell; seeds never read: no-fight 4501-4512, fights 4513-4524.
# builder0's light lane at J<=4 (R38.37): `make remote LIGHT=1 T="native settle-s1v5"`.
.PHONY: settle-s1v5
settle-s1v5: ## Round 38 (settle, R38.37): the street-capped fit (seeds 4501-4524) -> build/settle-s1v5/verdict.txt
	@SETTLE_S1_DECIDING_JUDGED=0 $(MAKE) --no-print-directory settle-s1v2 SETTLE_V2="$(BUILD_DIR)/settle-s1v5" \
		SETTLE_V2_SEEDS="$$(seq -s " " 4501 4512)" SETTLE_V2_FIGHT_SEEDS="$$(seq -s " " 4513 4524)" SETTLE_V2_JOBS=4 \
		SETTLE_V2_ARMS="main:--deploy-trace fit:--deploy-fit=street,--deploy-trace"

# R38.19: S2 v4 = S2 v3's series, lines and judge (anchor guard) on the latch that holds the terrain at the halt's anchor
# (`--deploy-latch=anchor`), seeds never read for S2: no-fight 4301-4312, fight3/fight5 4313-4324, census 4301-4303.
.PHONY: settle-s2v4
settle-s2v4: ## Round 38 (settle, R38.19): S2 v4's series (main v anchor, seeds 4301-4324) -> build/settle-s2v4/verdict.txt
	@SETTLE_SHAPE_JUDGED=0 $(MAKE) --no-print-directory settle-s2v3 SETTLE_V3="$(BUILD_DIR)/settle-s2v4" SETTLE_V3_NEW=anchor \
		SETTLE_V3_ARMS="main:--deploy-trace anchor:--deploy-latch=anchor,--deploy-trace" \
		SETTLE_V3_SEEDS="$$(seq -s " " 4301 4312)" SETTLE_V3_FIGHT_SEEDS="$$(seq -s " " 4313 4324)" \
		SETTLE_V3_CENSUS_SEEDS="4301 4302 4303"

# Round 39 (settle S1, route-clear halt seats): the lab on the traced cases. SETTLE_LAB_CASES entries "map:squads:route:seed",
# every SETTLE_LAB_ARMS entry "name:flag,flag" (orders' probe, --deploy-trace added) -> build/settle-lab/<case>-<arm>.log and
# lab.txt: per run, each squad's arrived_s (-1 = never in) and the seats the deploys cleared. Builder0 light: J <= 4.
SETTLE_LAB_CASES ?= terminus:5:route:4505 crossing:5:route:3958 crossing:5:route:3806
SETTLE_LAB_ARMS ?= main: clear:--seat-route-clear fit:--deploy-fit=street fitclear:--deploy-fit=street,--seat-route-clear
SETTLE_LAB_JOBS ?= 4
SETTLE_LAB_FLAGS ?=
.PHONY: settle-lab
settle-lab: native-for-check import ## Round 39 (settle S1): orders' probe on SETTLE_LAB_CASES x SETTLE_LAB_ARMS -> build/settle-lab/lab.txt
	@rm -rf $(BUILD_DIR)/settle-lab && mkdir -p $(BUILD_DIR)/settle-lab
	@echo ">> settle-lab on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | flags '$(SETTLE_LAB_FLAGS)'" | tee $(BUILD_DIR)/settle-lab/lab.txt
	@for c in $(SETTLE_LAB_CASES); do for a in $(SETTLE_LAB_ARMS); do echo "$$c $$a"; done; done | xargs -P $(SETTLE_LAB_JOBS) -L 1 sh -c \
		'map=$$(echo $$0 | cut -d: -f1); n=$$(echo $$0 | cut -d: -f2); route=$$(echo $$0 | cut -d: -f3); seed=$$(echo $$0 | cut -d: -f4); \
		name=$${1%%:*}; flags=$$(echo "$${1#*:}" | tr "," " "); \
		timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/orders_probe.gd -- --arena=$$map --seed=$$seed \
			--probe-squads=$$n --probe-route=$$route --probe-arm=$$name --deploy-trace $$flags $(SETTLE_LAB_FLAGS) \
			> $(BUILD_DIR)/settle-lab/$$map-$$n-$$route-s$$seed-$$name.log 2>&1 || true'
	@$(PYTHON) tests/settle/settle_lab.py $(BUILD_DIR)/settle-lab | tee -a $(BUILD_DIR)/settle-lab/lab.txt

# Round 39 Bar S1 route-clear (settle.md Status, filed before any number): main v --seat-route-clear on the latch-ON main,
# S1 v5's workloads on fresh seeds: no-fight 12 cells x 6001-6012, fights 3-squad (budget 1500) and 5-squad (budget 3000)
# click cells x 6013-6024; judge `settle_judge.py s1c`. builder0 light, J 4, TANK_SQUAD_SLOT_TIMEOUT=14400:
#   tools/remote.sh --light native settle-s1c TANK_SQUAD_SLOT_TIMEOUT=14400
.PHONY: settle-s1c
settle-s1c: ## Round 39 (settle S1): the route-clear bar's series (main v clear, seeds 6001-6024) -> build/settle-s1c/verdict.txt
	@$(MAKE) --no-print-directory settle-s1v2 SETTLE_V2="$(BUILD_DIR)/settle-s1c" SETTLE_V2_SEEDS="$$(seq -s " " 6001 6012)" \
		SETTLE_V2_FIGHT_SEEDS="$$(seq -s " " 6013 6024)" SETTLE_V2_JOBS=4 SETTLE_V2_JUDGE=s1c SETTLE_V2_PAIR="main clear" \
		SETTLE_V2_ARMS="main:--deploy-trace clear:--seat-route-clear,--deploy-trace"

# Round 39 (settle S1): the player's look at the lab cases. Orders' probe in a window (needs a display: builder0 via
# tools/remote.sh --light), top-down desktop + phone shots when every squad is in (or the window ends), per
# SETTLE_LAB_CASES x SETTLE_SHOT_ARMS -> build/settle-shots/<case>-<arm>/*.png
SETTLE_SHOT_ARMS ?= main: clear:--seat-route-clear
.PHONY: settle-shots
settle-shots: native-for-check import ## Round 39 (settle S1): top-down shots of the lab cases, main v clear (needs a display) -> build/settle-shots/
	@rm -rf $(BUILD_DIR)/settle-shots && mkdir -p $(BUILD_DIR)/settle-shots
	@for c in $(SETTLE_LAB_CASES); do for a in $(SETTLE_SHOT_ARMS); do \
		map=$$(echo $$c | cut -d: -f1); n=$$(echo $$c | cut -d: -f2); route=$$(echo $$c | cut -d: -f3); seed=$$(echo $$c | cut -d: -f4); \
		name=$${a%%:*}; flags=$$(echo "$${a#*:}" | tr "," " "); out=$(BUILD_DIR)/settle-shots/$$map-$$n-$$route-s$$seed-$$name; mkdir -p $$out; \
		timeout 900 $(GODOT) --fixed-fps $(SIM_HZ) --path . --script res://tests/orders_probe.gd -- --arena=$$map --seed=$$seed \
			--probe-squads=$$n --probe-route=$$route --probe-arm=$$name --mute --probe-shots=$$out $$flags > $$out/run.log 2>&1 || true; \
		echo "$$c $$name: $$(ls $$out/*.png 2>/dev/null | wc -l) shots, $$(grep -c '^ORDERS_PROBE {' $$out/run.log) run line"; done; done

# Round 39 Bar H v2 (settle.md Status, filed before any number): main v --deploy-hold=on, both --deploy-trace, the fight probe
# (locks/crossing/terminus x 3 squads x click x 6025-6048); judge `settle_judge.py h2` on the REDEAL_TRACE lines (the hold is ON
# since that bar: main carries --deploy-hold=off to re-run it). builder0 light, J 4:
#   tools/remote.sh --light native settle-h2 TANK_SQUAD_SLOT_TIMEOUT=14400
SETTLE_H2_SEEDS ?= $(shell seq 6025 6048)
SETTLE_H2_ARMS ?= main:--deploy-trace,--deploy-hold=off,--probe-fight=on,--probe-budget=1500 held:--deploy-trace,--deploy-hold=on,--probe-fight=on,--probe-budget=1500
.PHONY: settle-h2
settle-h2: native-for-check import ## Round 39 (settle stretch): Bar H v2's series (main v held, seeds 6025-6048) -> build/settle-h2/verdict.txt
	@rm -rf $(BUILD_DIR)/settle-h2 && mkdir -p $(BUILD_DIR)/settle-h2
	@echo ">> settle-h2 on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | arms '$(SETTLE_H2_ARMS)'" | tee $(BUILD_DIR)/settle-h2/header.txt
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_ROUTES=click ORDERS_PROBE_SQUADS=3 ORDERS_PROBE_ARMS="$(SETTLE_H2_ARMS)" \
		ORDERS_PROBE_SEEDS="$(SETTLE_H2_SEEDS)" ORDERS_PROBE_JOBS=4 ORDERS_PROBE_DIR=$(BUILD_DIR)/settle-h2/fight > $(BUILD_DIR)/settle-h2/fight.out 2>&1 || true
	@cd $(BUILD_DIR)/settle-h2 && $(PYTHON) $(CURDIR)/tests/settle/settle_judge.py h2 fight main held | tee verdict.txt || true

# Round 40 Bar T1 (settle.md Status, filed before any number): main v the deploy trigger arm on S1 v2's workloads, seeds
# 8001-8012 (main pinned --deploy-arrive=off since T1 shipped ON; no-fight 12 cells; fights 3-squad budget 1500 and 5-squad budget 3000 click cells); judge `settle_judge.py t1`.
# builder0 light, J 4:  tools/remote.sh --light native settle-t1 TANK_SQUAD_SLOT_TIMEOUT=14400
SETTLE_T1_ARM ?= settled:--deploy-arrive=settled,--deploy-trace
.PHONY: settle-t1
settle-t1: ## Round 40 (settle T1): the deploy trigger's bar series (main v SETTLE_T1_ARM, seeds 8001-8012) -> build/settle-t1/verdict.txt
	@$(MAKE) --no-print-directory settle-s1v2 SETTLE_V2="$(BUILD_DIR)/settle-t1" SETTLE_V2_SEEDS="$$(seq -s " " 8001 8012)" \
		SETTLE_V2_FIGHT_SEEDS="$$(seq -s " " 8001 8012)" SETTLE_V2_JOBS=4 SETTLE_V2_JUDGE=t1 \
		SETTLE_V2_PAIR="main $(firstword $(subst :, ,$(SETTLE_T1_ARM)))" SETTLE_V2_ARMS="main:--deploy-arrive=off,--deploy-trace $(SETTLE_T1_ARM)"

# Round 40 Bar S1 v3 (settle.md Status, filed before any number): main v --seat-route-clear=v3 on round 39's S1 workloads,
# seeds 8013-8024 (no-fight 12 cells; fights 3-squad b1500 / 5-squad b3000 click cells); judge `settle_judge.py s1c` (round 39's
# lines, unamended). Filed with T1 OFF in both arms: --deploy-arrive=off pins it since T1 shipped ON. builder0 light, J 4:  tools/remote.sh --light native settle-s1v3r40 TANK_SQUAD_SLOT_TIMEOUT=14400
.PHONY: settle-s1v3r40
settle-s1v3r40: ## Round 40 (settle S1 v3): the per-crew route-clear's bar series (main v v3, seeds 8013-8024) -> build/settle-s1v3r40/verdict.txt
	@$(MAKE) --no-print-directory settle-s1v2 SETTLE_V2="$(BUILD_DIR)/settle-s1v3r40" SETTLE_V2_SEEDS="$$(seq -s " " 8013 8024)" \
		SETTLE_V2_FIGHT_SEEDS="$$(seq -s " " 8013 8024)" SETTLE_V2_JOBS=4 SETTLE_V2_JUDGE=s1c SETTLE_V2_PAIR="main v3" \
		SETTLE_V2_ARMS="main:--deploy-arrive=off,--deploy-trace v3:--deploy-arrive=off,--seat-route-clear=v3,--deploy-trace"

# Round 40 (settle stretch, orchestrator after Bar S1 v3's FAIL): dev reads on main with T1 ON. (1) v3 v main on the cells
# that carried v3's extra twitch (crossing + terminus, 3 and 5 squads, click and route), dev seeds 6301-6306; (2) the dry
# deal read (DEPLOY_TRACE `deals`) on terminus 5 route, orders' flagged seeds 8203 8205 8206 8208. builder2:
#   make gcp-remote T="native settle-dev-v3t1"
.PHONY: settle-dev-v3t1
settle-dev-v3t1: native-for-check import ## Round 40 (settle stretch): dev v3 v main with T1 ON + the dry deal read -> build/settle-dev-v3t1/
	@rm -rf $(BUILD_DIR)/settle-dev-v3t1 && mkdir -p $(BUILD_DIR)/settle-dev-v3t1
	@echo ">> settle-dev-v3t1 on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | jobs 12" | tee $(BUILD_DIR)/settle-dev-v3t1/header.txt
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_MAPS="crossing terminus" ORDERS_PROBE_JOBS=12 \
		ORDERS_PROBE_ARMS="main:--deploy-trace v3:--seat-route-clear=v3,--deploy-trace" ORDERS_PROBE_SEEDS="$$(seq -s " " 6301 6306)" \
		ORDERS_PROBE_DIR=$(BUILD_DIR)/settle-dev-v3t1/pair > $(BUILD_DIR)/settle-dev-v3t1/pair.out 2>&1 || true
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_MAPS=terminus ORDERS_PROBE_SQUADS=5 ORDERS_PROBE_ROUTES=route ORDERS_PROBE_JOBS=12 \
		ORDERS_PROBE_ARMS="main:--deploy-trace" ORDERS_PROBE_SEEDS="8203 8205 8206 8208" \
		ORDERS_PROBE_DIR=$(BUILD_DIR)/settle-dev-v3t1/deals > $(BUILD_DIR)/settle-dev-v3t1/deals.out 2>&1 || true
	@$(PYTHON) tests/settle/settle_t1.py $(BUILD_DIR)/settle-dev-v3t1/pair | tee $(BUILD_DIR)/settle-dev-v3t1/pair.txt || true
	@$(PYTHON) tests/settle/settle_deals.py $(BUILD_DIR)/settle-dev-v3t1/deals | tee $(BUILD_DIR)/settle-dev-v3t1/deals.txt || true

# Round 40 (R40.14 (1)): the dev never-in under v3 with T1 ON (terminus 5 click s6306, Alpha), squad 1's crews every second
# (orders' --probe-trace=1), both arms. builder2 light:  make gcp-remote LIGHT=1 T="native settle-dev-s6306"
.PHONY: settle-dev-s6306
settle-dev-s6306: native-for-check import ## Round 40 (settle): trace the dev never-in (terminus 5 click s6306) -> build/settle-dev-s6306/
	@rm -rf $(BUILD_DIR)/settle-dev-s6306 && mkdir -p $(BUILD_DIR)/settle-dev-s6306
	@$(MAKE) --no-print-directory orders-probe ORDERS_PROBE_MAPS=terminus ORDERS_PROBE_SQUADS=5 ORDERS_PROBE_ROUTES=click ORDERS_PROBE_JOBS=2 \
		ORDERS_PROBE_ARMS="main:--deploy-trace,--probe-trace=1 v3:--seat-route-clear=v3,--deploy-trace,--probe-trace=1" ORDERS_PROBE_SEEDS=6306 \
		ORDERS_PROBE_DIR=$(BUILD_DIR)/settle-dev-s6306 > $(BUILD_DIR)/settle-dev-s6306/probe.out 2>&1 || true
