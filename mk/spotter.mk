# Round 47 (spotter, R47.40): find the moments our units look dumb, so he doesn't have to play to find them. Dev tooling only:
# nothing here ships in the game. Brief: _agents/streams/spotter.md. Python bits: tools/spotter/ (stdlib; S6's torch in
# ~/tools/spotter-venv on builder3, never in the repo).
#
# spotter-fights   S1: SPOT_MAPS x SPOT_SEEDS CPU-v-CPU showmatch fights (the shipped default game, native) headless, each with
#                  tests/spotter/feature_probe.gd listening -> SPOT_DIR/<arena>-<seed>.jsonl (+ .log)
# spotter-rank     S1+S2: the feature table and the ranked moments of SPOT_DIR -> SPOT_DIR/{features.csv,moments.json,moments.md}
# spotter-batch    both, in one run (what the night shift runs)
# spotter-test     the Python tests (tests/spotter/test_*.py; stdlib unittest, no Godot)

SPOT_MAPS ?= terminus crossing locks sumps gorge parade
SPOT_SEEDS ?= 13121 13122
SPOT_SECONDS ?= 240
SPOT_JOBS ?= 6
SPOT_FLAGS ?=
SPOT_DIR ?= $(BUILD_DIR)/spotter/fights
SPOT_TOP ?= 50

.PHONY: spotter-fights
spotter-fights: native-fresh import ## spotter S1: SPOT_MAPS x SPOT_SEEDS CPU-v-CPU fights with the feature probe -> SPOT_DIR/<arena>-<seed>.jsonl
	@mkdir -p $(SPOT_DIR)
	@echo ">> spotter-fights on $$(hostname) | commit $${TANK_SQUAD_COMMIT:-$$(git rev-parse --short HEAD 2>/dev/null || echo unknown)} | maps '$(SPOT_MAPS)' seeds '$(SPOT_SEEDS)' | flags '$(SPOT_FLAGS)' | load $$(cut -d' ' -f1-3 /proc/loadavg)" | tee -a $(SPOT_DIR)/run.txt
	@for seed in $(SPOT_SEEDS); do for arena in $(SPOT_MAPS); do \
		[ -s $(SPOT_DIR)/$$arena-$$seed.jsonl ] && grep -q '"t":"end"' $(SPOT_DIR)/$$arena-$$seed.jsonl && continue; \
		echo "$$arena $$seed"; done; done | \
		xargs -r -P $(SPOT_JOBS) -L 1 sh -c 'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . \
		--script res://tests/spotter/feature_probe.gd -- --skirmish --demo-match --clean --seed=$$1 --arena=$$0 --mute \
		--seconds=$(SPOT_SECONDS) --spot-out=$(abspath $(SPOT_DIR))/$$0-$$1.jsonl.part $(SPOT_FLAGS) > $(SPOT_DIR)/$$0-$$1.log 2>&1; \
		if grep -q "^SPOT_DONE" $(SPOT_DIR)/$$0-$$1.log; then mv $(SPOT_DIR)/$$0-$$1.jsonl.part $(SPOT_DIR)/$$0-$$1.jsonl; \
		else echo "  MISSING SPOT_DONE $$0 s$$1"; fi'
	@ls $(SPOT_DIR)/*.jsonl 2>/dev/null | wc -l | xargs -I{} echo "spotter-fights: {} fights in $(SPOT_DIR)"

.PHONY: spotter-rank
spotter-rank: ## spotter S2: the feature table + ranked moments of SPOT_DIR (SPOT_TOP of them) -> SPOT_DIR/moments.md
	$(PYTHON) tools/spotter/rank.py $(SPOT_DIR) --top $(SPOT_TOP)

.PHONY: spotter-batch
spotter-batch: ## spotter: spotter-fights then spotter-rank (the night shift's batch)
	@$(MAKE) --no-print-directory spotter-fights
	@$(MAKE) --no-print-directory spotter-rank

.PHONY: spotter-test
spotter-test: ## spotter: the Python tests (tests/spotter/test_*.py)
	$(PYTHON) -m unittest discover -s tests/spotter -p 'test_*.py' -v
