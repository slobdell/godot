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

# rules-shots: the smoke a player sees. A skirmish from the player's seat (--scripted: no planning pause, a fixed order
# sequence) (fog of war on: the fog edge is the
# team's sight) with the rules OFF and ON, at his window and the phone, RULES_SHOT_DELAYS seconds in. Needs a display:
# make remote T=rules-shots.
RULES_SHOT_ARENA ?= terminus
RULES_SHOT_DELAYS ?= 40 70
RULES_SHOT_DIR ?= $(BUILD_DIR)/rules-shots

.PHONY: rules-shots
rules-shots: import ## Round 37 (rules): skirmish frames with the rules OFF and ON (--rules-on=sight,spread,pin_slow), his window and the phone -> build/rules-shots/*.png (needs a display)
	rm -rf $(RULES_SHOT_DIR) && mkdir -p $(RULES_SHOT_DIR)
	for arm in off on; do for delay in $(RULES_SHOT_DELAYS); do for size in 1854x1011 1200x540; do \
		flags=""; if [ $$arm = on ]; then flags="--rules-on=sight,spread,pin_slow"; fi; \
		timeout 300 $(GODOT) --path . --resolution $$size -- --skirmish --scripted --enemy=cpu --seed=3 --arena=$(RULES_SHOT_ARENA) \
			--no-pick-faction --announcer=text --announcer-history=off --music-history=off --render-preset=desktop $$flags \
			--screenshot-delay=$$delay --screenshot=$(CURDIR)/$(RULES_SHOT_DIR)/$${arm}_$${delay}s_$$size.png \
			> $(RULES_SHOT_DIR)/$${arm}_$${delay}s_$$size.log 2>&1 || echo "rules-shots: $$arm $$delay $$size exited $$?"; \
	done; done; done
	@ls $(RULES_SHOT_DIR)/*.png 2>/dev/null | wc -l | xargs -I{} echo "rules-shots: {} frames in $(RULES_SHOT_DIR)"
	@errors=$$(cat $(RULES_SHOT_DIR)/*.log | grep -cE '^(ERROR|SCRIPT ERROR)' || true); echo "rules-shots: $$errors engine error lines"; \
		[ "$$errors" -eq 0 ] || { cat $(RULES_SHOT_DIR)/*.log | grep -E '^(ERROR|SCRIPT ERROR)' | sort | uniq -c | sort -rn | head -5; exit 1; }
