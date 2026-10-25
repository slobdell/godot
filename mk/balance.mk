# Faction balance (round 40, balance stream; _agents/streams/balance.md). Included by the root Makefile.
.PHONY: balance-catalog balance-tally balance-pytest

balance-catalog: import ## The unit and weapon catalogs as JSON -> build/balance/catalog.json (read-only; the tally prices units with it)
	mkdir -p $(BUILD_DIR)/balance
	$(GODOT) --headless --path . --script res://tools/balance/catalog_dump.gd 2>&1 | sed -n 's/^CATALOG_JSON //p' \
		> $(BUILD_DIR)/balance/catalog.json
	test -s $(BUILD_DIR)/balance/catalog.json

balance-tally: balance-catalog ## B1: per-unit kills/losses/value per credit of a guard series' logs: RUNS="~/doctrine-guard-raw/773412e49-off" [TALLY_JSON=out.json]
	$(PYTHON) tools/balance/tally.py --catalog $(BUILD_DIR)/balance/catalog.json $(RUNS) $(if $(TALLY_JSON),--json $(TALLY_JSON))

balance-pytest: ## The balance tools' own tests (tally fixture)
	$(PYTHON) -m unittest discover -s tools/balance -p 'test_*.py'
