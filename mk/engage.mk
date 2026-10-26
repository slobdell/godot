# ---- engage (round 42): "in range" means a clear shot ---------------------------------------------------------------
# Owner: the engage stream (_agents/streams/engage.md). The rule is `--attack-shot=on|off` (env ATTACK_SHOT).

# E1: his crew behind the container, rebuilt (Locks, seed 49326, the census's places), one ENGAGE_TRACE row per sample tick
# (and on every change): the element's order, the brain's choice and move, the mover's phase, the gun, both sight reads, the HUD's
# words. ENGAGE_ARM=on|off selects the rule; ENGAGE_SECONDS the window.
ENGAGE_ARM ?= off
ENGAGE_SECONDS ?= 40
.PHONY: engage-far-trace
engage-far-trace: import ## engage R42.10: the far_ambush drill's stage with one FAR_TRACE line per crew per sample (ENGAGE_ARM=on|off) -> build/engage/far_trace_<arm>.log
	@mkdir -p $(BUILD_DIR)/engage
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/engage/far_ambush_trace.gd -- \
		--seconds=26 --every=30 --attack-shot=$(ENGAGE_ARM) > $(BUILD_DIR)/engage/far_trace_$(ENGAGE_ARM).log 2>&1 || true
	@grep -E "FAR_HP|FAR_TRACE_FLAG|FAR_TRACE_DONE|ERROR" $(BUILD_DIR)/engage/far_trace_$(ENGAGE_ARM).log || true

.PHONY: engage-replay
engage-replay: import ## engage E1: replay his crew behind the container (ENGAGE_ARM=on|off, ENGAGE_SECONDS) -> build/engage/replay_<arm>.log
	@mkdir -p $(BUILD_DIR)/engage
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/engage/replay_probe.gd -- \
		--seconds=$(ENGAGE_SECONDS) --every=30 --attack-shot=$(ENGAGE_ARM) > $(BUILD_DIR)/engage/replay_$(ENGAGE_ARM).log 2>&1 || true
	@grep -E "ENGAGE_REPLAY|SCRIPT ERROR" $(BUILD_DIR)/engage/replay_$(ENGAGE_ARM).log

# E4 (Bar E1's deciding workload): his case as a probe. ENGAGE_SEEDS x the arena cycle (locks / terminus / crossing by seed), 2-5
# crews ordered to attack a target behind cover, crews on both sides of it; one ENGAGE_PROBE json line per run. ENGAGE_ARM as above.
ENGAGE_SEEDS ?= 7001 7002 7003
ENGAGE_PROBE_SECONDS ?= 60
ENGAGE_JOBS ?= 4
.PHONY: engage-probe
engage-probe: import ## engage E4: the attack-shot probe over ENGAGE_SEEDS (ENGAGE_ARM=on|off, ENGAGE_PROBE_SECONDS, ENGAGE_JOBS) -> build/engage/probe/<arm>/<seed>.log + the table
	@mkdir -p $(BUILD_DIR)/engage/probe/$(ENGAGE_ARM)
	@echo ">> engage-probe on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | arm $(ENGAGE_ARM) | seeds $(firstword $(ENGAGE_SEEDS))+ | load $$(cut -d' ' -f1-3 /proc/loadavg)"
	@for seed in $(ENGAGE_SEEDS); do echo $$seed; done | xargs -r -P $(ENGAGE_JOBS) -I{} sh -c \
		'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/engage/attack_shot_probe.gd -- \
		--seed={} --seconds=$(ENGAGE_PROBE_SECONDS) --attack-shot=$(ENGAGE_ARM) $(ENGAGE_FLAGS) > $(BUILD_DIR)/engage/probe/$(ENGAGE_ARM)/{}.log 2>&1 || true; \
		grep -q "^ENGAGE_PROBE " $(BUILD_DIR)/engage/probe/$(ENGAGE_ARM)/{}.log || echo "  MISSING ENGAGE_PROBE seed {}"'
	$(PYTHON) tests/engage/attack_shot_table.py $(BUILD_DIR)/engage/probe/$(ENGAGE_ARM)

# Both arms on the same seeds, then the paired table (Bar E1's lines read from it).
.PHONY: engage-bar
engage-bar: import ## engage E4: engage-probe in both arms on ENGAGE_SEEDS, then the paired table (tests/engage/attack_shot_table.py --pair)
	@$(MAKE) --no-print-directory engage-probe ENGAGE_ARM=off
	@$(MAKE) --no-print-directory engage-probe ENGAGE_ARM=on
	$(PYTHON) tests/engage/attack_shot_table.py --pair $(BUILD_DIR)/engage/probe/off $(BUILD_DIR)/engage/probe/on

# A quick parse check of the stream's own scripts.
ENGAGE_PARSE ?= game/tactics/firing_position.gd game/tactics/element_situation.gd game/tactics/element_plan.gd game/ai/tank_brain.gd \
	game/control/rts_controls.gd tests/tactics/test_engage_shot.gd tests/engage/replay_probe.gd tests/engage/attack_shot_probe.gd \
	tests/engage/test_engage_hud_words.gd
.PHONY: engage-parse
engage-parse: import ## engage: --check-only on the stream's scripts (ENGAGE_PARSE), the real messages printed
	@for f in $(ENGAGE_PARSE); do out=$$($(GODOT) --headless --path . --check-only --script res://$$f 2>&1 | grep -E "Parse Error|SCRIPT ERROR|ERROR" | grep -v "depended scripts" || true); \
		if [ -n "$$out" ]; then echo "== $$f"; echo "$$out" | head -8; else echo "ok $$f"; fi; done
