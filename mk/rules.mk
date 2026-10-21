# Round 37 (rules, C37.2): the "stop to be strong" rules. Switches: game/combat/rule_switches.gd (--rules-on=sight,spread,pin_slow).
# rules-moving: R2's first MEASURE. CPU-v-CPU fights (the scoreboard's showmatch: --skirmish --demo-match) with
# tests/rules/moving_fire_probe.gd listening: how much enemy damage came from rounds fired on the move, by range.
# RULES_FLAGS adds run flags (--rules-on=spread for the arm). Light: make remote T=rules-moving LIGHT=1.

RULES_AT ?= terminus locks sumps gorge parade
RULES_SEEDS ?= 1 2 3 4
RULES_JOBS ?= 10
RULES_SECONDS ?= 180
RULES_FLAGS ?=
RULES_DIR ?= $(BUILD_DIR)/rules-moving

.PHONY: rules-moving
rules-moving: import ## Round 37 (rules R2 measure): CPU fights (RULES_AT x RULES_SEEDS) -> the share of damage dealt by crews firing on the move, by range (RULES_FLAGS for an arm)
	@rm -rf $(RULES_DIR) && mkdir -p $(RULES_DIR)
	@echo ">> rules-moving on $$(hostname) | commit $${TANK_SQUAD_COMMIT:-$$(git rev-parse --short HEAD 2>/dev/null || echo unknown)} | flags '$(RULES_FLAGS)' | load $$(cut -d' ' -f1-3 /proc/loadavg)" | tee $(RULES_DIR)/run.txt
	@for seed in $(RULES_SEEDS); do for arena in $(RULES_AT); do echo "$$arena $$seed"; done; done | \
		xargs -P $(RULES_JOBS) -L 1 sh -c 'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . \
		--script res://tests/rules/moving_fire_probe.gd -- --skirmish --demo-match --clean --seed=$$1 --arena=$$0 --mute \
		--seconds=$(RULES_SECONDS) $(RULES_FLAGS) > $(RULES_DIR)/$$0-$$1.log 2>&1 || true; \
		grep -q "^MOVING_FIRE" $(RULES_DIR)/$$0-$$1.log || echo "  MISSING MOVING_FIRE $$0 s$$1"'
	@grep -h "^MOVING_FIRE" $(RULES_DIR)/*.log | sed 's/^MOVING_FIRE //' > $(RULES_DIR)/rows.jsonl
	@$(PYTHON) tests/rules/moving_fire_table.py $(RULES_DIR)/rows.jsonl | tee $(RULES_DIR)/table.txt
