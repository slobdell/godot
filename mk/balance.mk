# Faction balance (round 40, balance stream; _agents/streams/archive/round42/balance.md). Included by the root Makefile.
.PHONY: balance-catalog balance-tally balance-pytest balance-tuned

balance-catalog: import ## The unit and weapon catalogs as JSON -> build/balance/catalog.json (read-only; the tally prices units with it)
	mkdir -p $(BUILD_DIR)/balance
	$(GODOT) --headless --path . --script res://tools/balance/catalog_dump.gd 2>&1 | sed -n 's/^CATALOG_JSON //p' \
		> $(BUILD_DIR)/balance/catalog.json
	test -s $(BUILD_DIR)/balance/catalog.json

balance-tally: balance-catalog ## B1: per-unit kills/losses/value per credit of a guard series' logs: RUNS="~/doctrine-guard-raw/773412e49-off" [TALLY_JSON=out.json]
	$(PYTHON) tools/balance/tally.py --catalog $(BUILD_DIR)/balance/catalog.json $(RUNS) $(if $(TALLY_JSON),--json $(TALLY_JSON))

balance-pytest: ## The balance tools' own tests (tally fixture)
	$(PYTHON) -m unittest discover -s tools/balance -p 'test_*.py'

balance-tuned: import ## B4: the stats as the simulation reads them under a candidate's tune: TUNE_SPEC="gang_tank.max_health=483,..." -> build/balance/tuned.json
	mkdir -p $(BUILD_DIR)/balance
	$(GODOT) --headless --path . --script res://tools/balance/catalog_dump.gd -- --tune=$(TUNE_SPEC) 2>&1 \
		| sed -n 's/^TUNED_JSON //p' > $(BUILD_DIR)/balance/tuned.json
	test -s $(BUILD_DIR)/balance/tuned.json

# Round 41 (B5, C41.5): guard-run (mk/scoreboard.mk) played by tests/tactics/face_probe.gd: the same fights, folders, stamp
# and resume (GUARD_* are scoreboard.mk's), plus a FACE line a fight (where the rounds land on tanks). Driven on builder2 by
# tools/balance/guard_probe.sh (guard.sh with this target's name); read by tools/balance/search.py faces.
.PHONY: balance-guard-run
balance-guard-run: import ## B5: guard-run through the face probe (FACE lines) -> build/guards/ (tools/balance/guard_probe.sh drives it)
	@stamp="$(GUARD_STAMP) | probe face"; if [ -n "$(GUARD_RESUME)" ] && [ "$$(cat $(GUARD_DIR)/stamp 2>/dev/null)" = "$$stamp" ]; then \
		echo ">> balance-guard-run: resuming, $$(grep -l '^GUARD_RESULT' $(GUARD_DIR)/*/*.log 2>/dev/null | wc -l) fights already read"; \
	else rm -rf $(GUARD_DIR) && mkdir -p $(GUARD_DIR) && echo "$$stamp" > $(GUARD_DIR)/stamp; fi
	@echo ">> guard-run on $$(hostname) | commit $${TANK_SQUAD_COMMIT:-$$(git rev-parse --short HEAD 2>/dev/null || echo unknown)} | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | kinds '$(GUARD_KINDS)' | args '$(GUARD_ARGS)' | seeds $(firstword $(GUARD_SEEDS))+ | probe face | load $$(cut -d' ' -f1-3 /proc/loadavg)" | tee -a $(GUARD_DIR)/run.txt
	@for kind in $(GUARD_KINDS); do mkdir -p $(GUARD_DIR)/$$kind; for seed in $(GUARD_SEEDS); do for arena in $(GUARD_AT); do \
		for side in $(GUARD_SIDES); do echo "$$kind $$arena $$seed $$side"; done; done; done; done | \
		while read -r kind arena seed side; do grep -qs "^FACE" $(GUARD_DIR)/$$kind/$$arena-$$seed-$$side.log \
			|| echo "$$kind $$arena $$seed $$side"; done | \
		xargs -r -P $(GUARD_JOBS) -L 1 sh -c 'timeout 1800 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . \
		--script res://tests/tactics/face_probe.gd -- --skirmish --demo-match --clean --seed=$$2 --arena=$$1 --mute \
		--guard=$$0 --guard-side=$$3 --seconds=$(GUARD_SECONDS) $(GUARD_ARGS) > $(GUARD_DIR)/$$0/$$1-$$2-$$3.log 2>&1 || true; \
		grep -q "^FACE" $(GUARD_DIR)/$$0/$$1-$$2-$$3.log || echo "  MISSING FACE $$0 $$1 s$$2 $$3"'
	@echo ">> guard-run done: $$(grep -l '^GUARD_RESULT' $(GUARD_DIR)/*/*.log 2>/dev/null | wc -l) of $$(ls $(GUARD_DIR)/*/*.log | wc -l) fights" | tee -a $(GUARD_DIR)/run.txt

balance-faces: ## B5: the mixed army's damage to tanks by face from a face-probed mono series: ROOT=~/balance-guard-raw/b5 MATCH=-mono-base- [BASE_MATCH=...]
	$(PYTHON) tools/balance/search.py faces $(ROOT) --match "$(MATCH)" $(if $(BASE_MATCH),--base-match "$(BASE_MATCH)")

# Round 42 (B7, balance): a fight LIST, one remote call. guard-run plays every seed on every GUARD_AT arena with one GUARD_ARGS;
# Bar B7 plays ONE arena a seed and several arms (faction, team, switch), which through guard.sh is ~80 calls. FIGHTS is a file
# in the tree (tools/balance/fights.sh lays it in before the sync), one fight a line: `<folder> <arena> <seed> <switches...>`,
# played as the none line's green side (guard_line.gd, GUARD_SECONDS) -> build/guards/fights/<folder>/<arena>-<seed>-green.log.
# Resume as guard-run (GUARD_RESUME=1 and the same stamp: commit, list, seconds; a fight with its GUARD_RESULT is not replayed).
FIGHTS ?= fights/fights.txt
.PHONY: balance-fights-run
balance-fights-run: import ## B7: play a fight list (FIGHTS=<file>: folder arena seed switches...) -> build/guards/fights/ (tools/balance/fights.sh drives it)
	@test -s $(FIGHTS) || { echo ">> balance-fights-run: no fight list at $(FIGHTS)"; exit 2; }
	@stamp="$${TANK_SQUAD_COMMIT:-$$(git rev-parse --short HEAD 2>/dev/null || echo unknown)} | fights $$(sha256sum $(FIGHTS) | cut -c1-12) | seconds $(GUARD_SECONDS)"; \
	if [ -n "$(GUARD_RESUME)" ] && [ "$$(cat $(GUARD_DIR)/stamp 2>/dev/null)" = "$$stamp" ]; then \
		echo ">> balance-fights-run: resuming, $$(grep -l '^GUARD_RESULT' $(GUARD_DIR)/fights/*/*.log 2>/dev/null | wc -l) fights already read"; \
	else rm -rf $(GUARD_DIR) && mkdir -p $(GUARD_DIR) && echo "$$stamp" > $(GUARD_DIR)/stamp; fi
	@echo ">> guard-run on $$(hostname) | commit $${TANK_SQUAD_COMMIT:-$$(git rev-parse --short HEAD 2>/dev/null || echo unknown)} | native $$([ -e $(NATIVE_GDEXT) ] && echo on || echo off) | fights $$(grep -cv '^\s*\(#\|$$\)' $(FIGHTS)) from $(FIGHTS) | load $$(cut -d' ' -f1-3 /proc/loadavg)" | tee -a $(GUARD_DIR)/run.txt
	@grep -v '^\s*\(#\|$$\)' $(FIGHTS) | while read -r folder arena seed rest; do mkdir -p $(GUARD_DIR)/fights/$$folder; \
		grep -qs "^GUARD_RESULT" $(GUARD_DIR)/fights/$$folder/$$arena-$$seed-green.log || echo "$$folder $$arena $$seed $$rest"; done | \
		xargs -r -P $(GUARD_JOBS) -L 1 sh -c 'f=$$0 a=$$1 s=$$2; shift 2; timeout 1800 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . \
		--script res://tests/ai_scenarios/guard_line.gd -- --skirmish --demo-match --clean --seed=$$s --arena=$$a --mute \
		--guard=none --guard-side=green --seconds=$(GUARD_SECONDS) "$$@" > $(GUARD_DIR)/fights/$$f/$$a-$$s-green.log 2>&1 || true; \
		grep -q "^GUARD_RESULT" $(GUARD_DIR)/fights/$$f/$$a-$$s-green.log || echo "  MISSING GUARD_RESULT $$f $$a s$$s"'
	@echo ">> guard-run done: $$(grep -l '^GUARD_RESULT' $(GUARD_DIR)/fights/*/*.log 2>/dev/null | wc -l) of $$(grep -cv '^\s*\(#\|$$\)' $(FIGHTS)) fights" | tee -a $(GUARD_DIR)/run.txt
