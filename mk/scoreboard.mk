# ---- Round 35 extension (X5 (a), native): the round scoreboard ----------------------------------------------------------
# His concern (2026-10-20): "ensure that we're also generally making concrete progress". ONE fixed workload, the same on every
# main, so a row per main reads against the others: the player-facing numbers, not the mechanisms. Raw logs only; the
# numbers are read on the laptop by tools/scoreboard/score.py with TODAY's readers, so an older main is read the same way.
#   fights  SCORE_FIGHT_AT x SCORE_FIGHT_SEEDS, 180 s showmatch (tests/traffic/jam_census.gd): deaths by cause (open / stuck /
#           jam, and jammed while under fire), kills, hit rate
#   moves   hull-rest's drawn faced attack-move and move (foundry, quiet enemy, every faction): crews left behind, crews
#           that never settle, crews still moving at the judge (brains' mover kinds: closing / wander / jitter)
#   orders  the orders probe's click / route cells (locks, crossing, terminus x 3 and 5 squads): all-in time, never in,
#           far bank, twitch
# tools/scoreboard/run.sh runs it against any commit (an older main gets this file and the two probes laid over it).
# Pinned at --fixed-fps $(SIM_HZ); native (the shipped path). Seeds fixed across mains, chosen fresh in round 35.
SCORE_DIR ?= $(BUILD_DIR)/scoreboard
SCORE_FIGHT_AT ?= terminus locks sumps gorge parade
SCORE_FIGHT_SEEDS ?= 2601 2602 2603 2604 2605 2606 2607 2608
SCORE_MOVE_TASKS ?= faced_attack_move faced_move
SCORE_MOVE_SEEDS ?= 2601 2602 2603 2604 2605 2606
SCORE_ORDER_MAPS ?= locks crossing terminus
SCORE_ORDER_SEEDS ?= 2601 2602 2603
SCORE_JOBS ?= 10
SCORE_PARTS ?= fights moves orders
.PHONY: scoreboard-run
scoreboard-run: import ## X5: the round scoreboard's fixed workload on this tree (fights, moves, orders) -> build/scoreboard/ (read by tools/scoreboard/score.py)
	@rm -rf $(SCORE_DIR) && mkdir -p $(SCORE_DIR)/fights $(SCORE_DIR)/moves $(SCORE_DIR)/orders
	@echo ">> scoreboard-run on $$(hostname) | commit $${TANK_SQUAD_COMMIT:-$$(git rev-parse --short HEAD 2>/dev/null || echo unknown)} | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | parts '$(SCORE_PARTS)' | load $$(cut -d' ' -f1-3 /proc/loadavg)" | tee $(SCORE_DIR)/run.txt
	@if echo " $(SCORE_PARTS) " | grep -q " fights "; then \
	for seed in $(SCORE_FIGHT_SEEDS); do for arena in $(SCORE_FIGHT_AT); do echo "$$arena $$seed"; done; done | \
		xargs -P $(SCORE_JOBS) -L 1 sh -c 'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . \
		--script res://tests/traffic/jam_census.gd -- --skirmish --demo-match --clean --seed=$$1 --arena=$$0 --mute \
		--seconds=180 > $(SCORE_DIR)/fights/$$0-$$1.log 2>&1 || true; \
		grep -q "^JAM_CENSUS" $(SCORE_DIR)/fights/$$0-$$1.log || echo "  MISSING JAM_CENSUS fights $$0 s$$1"'; fi
	@if echo " $(SCORE_PARTS) " | grep -q " moves "; then \
	for faction in $(HULL_FACTIONS); do for seed in $(SCORE_MOVE_SEEDS); do for task in $(SCORE_MOVE_TASKS); do \
		echo "$$faction $$seed $$task"; done; done; done | xargs -P $(SCORE_JOBS) -L 1 sh -c '\
		d=$(SCORE_DIR)/moves/$$0/$$2-$$1; mkdir -p $$d; enemy=law; [ $$0 = law ] && enemy=gangs; \
		timeout 300 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --skirmish --seed=$$1 --no-pick-faction --mute \
			--arena=$(FACING_ARENA) --player-faction=$$0 --enemy-faction=$$enemy --tune=match.no_damage=1 \
			--enemy=$(FACING_QUIET_ENEMY) --no-element-cpu --turn-states --element-trace=all $(call _hull_jitter,$$1) $(_hull_shift) \
			--screen-test=$(CURDIR)/$$d --screen-only=$$2 > $$d/run.log 2>&1 || true; \
		grep -q SCREEN_DONE $$d/run.log || echo "  MISSING SCREEN_DONE moves $$0 $$2-$$1"'; fi
	@if echo " $(SCORE_PARTS) " | grep -q " orders "; then \
	for seed in $(SCORE_ORDER_SEEDS); do for map in $(SCORE_ORDER_MAPS); do for n in 3 5; do for route in click route; do \
		echo "$$map $$n $$route $$seed"; done; done; done; done | xargs -P $(SCORE_JOBS) -L 1 sh -c \
		'timeout 600 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/orders_probe.gd -- --arena=$$0 \
			--seed=$$3 --probe-squads=$$1 --probe-route=$$2 --probe-arm=main > $(SCORE_DIR)/orders/$$0-$$1-$$2-main-s$$3.log 2>&1 || true; \
		grep -q "^ORDERS_PROBE {" $(SCORE_DIR)/orders/$$0-$$1-$$2-main-s$$3.log || echo "  MISSING ORDERS_PROBE orders $$0-$$1-$$2 s$$3"'; fi
	@echo ">> scoreboard-run done: $$(ls $(SCORE_DIR)/fights | wc -l) fights, $$(find $(SCORE_DIR)/moves -name run.log | wc -l) moves, $$(ls $(SCORE_DIR)/orders | wc -l) orders runs" | tee -a $(SCORE_DIR)/run.txt
