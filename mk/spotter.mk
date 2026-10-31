# Round 47 (spotter, R47.40): find the moments our units look dumb, so he doesn't have to play to find them. Dev tooling only:
# nothing here ships in the game. Brief: _agents/streams/spotter.md. Python bits: tools/spotter/ (stdlib; S6's torch in
# ~/tools/spotter-venv on builder3, never in the repo).
#
# spotter-fights   S1: SPOT_MAPS x SPOT_SEEDS CPU-v-CPU showmatch fights (the shipped default game, native) headless, each with
#                  tests/spotter/feature_probe.gd listening -> SPOT_DIR/<arena>-<seed>.jsonl (+ .log)
# spotter-rank     S1+S2: the feature table and the ranked moments of SPOT_DIR -> SPOT_DIR/{features.csv,moments.json,moments.md}
# spotter-batch    both, in one run (what the night shift runs)
# spotter-test     the Python tests (tests/spotter/test_*.py; stdlib unittest) and test_night.sh: no Godot, seconds

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
		[ -s $(SPOT_DIR)/$$arena-$$seed.jsonl ] || [ -s $(SPOT_DIR)/$$arena-$$seed.jsonl.gz ] && continue; \
		echo "$$arena $$seed"; done; done | \
		xargs -r -P $(SPOT_JOBS) -L 1 sh -c 'timeout 900 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . \
		--script res://tests/spotter/feature_probe.gd -- --skirmish --demo-match --clean --seed=$$1 --arena=$$0 --mute \
		--seconds=$(SPOT_SECONDS) --spot-out=$(abspath $(SPOT_DIR))/$$0-$$1.jsonl.part $(SPOT_FLAGS) > $(SPOT_DIR)/$$0-$$1.log 2>&1; \
		if grep -q "^SPOT_DONE" $(SPOT_DIR)/$$0-$$1.log; then mv $(SPOT_DIR)/$$0-$$1.jsonl.part $(SPOT_DIR)/$$0-$$1.jsonl; \
		else echo "  MISSING SPOT_DONE $$0 s$$1"; fi'
	@echo "spotter-fights: $$(find $(SPOT_DIR) -maxdepth 1 \( -name '*.jsonl' -o -name '*.jsonl.gz' \) | wc -l) fights in $(SPOT_DIR)"

.PHONY: spotter-rank
SPOT_CONTROLS ?= 0
spotter-rank: ## spotter S2: the feature table + ranked moments of SPOT_DIR (SPOT_TOP of them, + SPOT_CONTROLS hidden random controls) -> SPOT_DIR/moments.md
	$(PYTHON) tools/spotter/rank.py $(SPOT_DIR) --top $(SPOT_TOP) --controls $(SPOT_CONTROLS)

.PHONY: spotter-batch
SPOT_BATCH_CLIPS ?= 0
spotter-batch: ## spotter: spotter-fights, spotter-rank, then (SPOT_BATCH_CLIPS > 0) that many clips: the night shift's batch
	@$(MAKE) --no-print-directory spotter-fights
	@$(MAKE) --no-print-directory spotter-rank
	@if [ "$(SPOT_BATCH_CLIPS)" -gt 0 ]; then $(MAKE) --no-print-directory spotter-clips SPOT_CLIPS=$(SPOT_BATCH_CLIPS); fi

.PHONY: spotter-test
spotter-test: ## spotter: the Python tests (tests/spotter/test_*.py) and the night shift's frame (tests/spotter/test_night.sh)
	$(PYTHON) -m unittest discover -s tests/spotter -p 'test_*.py' -v
	tests/spotter/test_night.sh

# ---- S0: the night shift (tools/spotter/night.sh on builder3; cron every 5 min; yields to every check / series / run) ----------
# spotter-night-install    the kit + runner to builder3 ~/spotter-night/, the bare repo (cloned from GitHub once), the cron line
# spotter-night-push SHA=  name the green commit it runs (pushes only that commit's missing objects to builder3's bare repo)
# spotter-night-status     what it is doing and what holds the box;  spotter-night-stop / -start;  spotter-night-uninstall
# spotter-night-pull       today's (NIGHT_DAY=) SUMMARY.md and moments to ~/spotter-work/night/<date>/ on this machine
SPOT_HOST ?= devia@builder3
NIGHT_DAY ?= $(shell date +%F)

.PHONY: spotter-night-install spotter-night-push spotter-night-status spotter-night-stop spotter-night-start spotter-night-uninstall spotter-night-pull
spotter-night-install: ## spotter S0: install the night shift on SPOT_HOST (kit, runner, bare repo, cron every 5 min)
	ssh -o BatchMode=yes $(SPOT_HOST) 'mkdir -p ~/spotter-night/bin ~/spotter-night/kit/mk ~/spotter-night/kit/tools ~/spotter-night/kit/tests ~/spotter-night/state'
	rsync -az --delete --exclude=__pycache__ tools/spotter/ $(SPOT_HOST):spotter-night/kit/tools/spotter/
	rsync -az --delete --exclude=__pycache__ tests/spotter/ $(SPOT_HOST):spotter-night/kit/tests/spotter/
	rsync -az mk/spotter.mk $(SPOT_HOST):spotter-night/kit/mk/spotter.mk
	rsync -az tools/spotter/night.sh $(SPOT_HOST):spotter-night/bin/night.sh
	kit=$$(git rev-parse --short HEAD)$$(git diff --quiet HEAD -- tools/spotter tests/spotter mk/spotter.mk || echo -dirty); \
		ssh -o BatchMode=yes $(SPOT_HOST) "echo $$kit > ~/spotter-night/kit/.kit-commit; chmod +x ~/spotter-night/bin/night.sh; \
		[ -d ~/spotter-night/repo.git ] || git clone -q --bare https://github.com/slobdell/godot.git ~/spotter-night/repo.git; \
		~/spotter-night/bin/night.sh cron-install"
	@echo ">> spotter-night: installed on $(SPOT_HOST) (kit $$(git rev-parse --short HEAD)); name its commit: make spotter-night-push SHA=<green hash>"

spotter-night-push: ## spotter S0: SHA=<green hash> becomes the commit the night shift runs (refs/heads/green on SPOT_HOST)
	@[ -n "$(SHA)" ] || { echo "spotter-night-push: name the green commit: SHA=<hash> (the one whose make check went green)"; exit 2; }
	git push -q $(SPOT_HOST):spotter-night/repo.git $$(git rev-parse $(SHA)):refs/heads/green
	@echo ">> spotter-night: green = $$(git rev-parse --short $(SHA)) on $(SPOT_HOST)"

spotter-night-status: ## spotter S0: the night shift's state on SPOT_HOST
	@ssh -o BatchMode=yes $(SPOT_HOST) '~/spotter-night/bin/night.sh status'

spotter-night-stop: ## spotter S0: stop the night shift now and keep it stopped
	@ssh -o BatchMode=yes $(SPOT_HOST) '~/spotter-night/bin/night.sh stop'

spotter-night-start: ## spotter S0: clear a stop
	@ssh -o BatchMode=yes $(SPOT_HOST) '~/spotter-night/bin/night.sh start'

spotter-night-uninstall: ## spotter S0: stop it and remove the cron line (results stay in ~/spotter-night; rm -rf it to free the disk)
	ssh -o BatchMode=yes $(SPOT_HOST) '~/spotter-night/bin/night.sh stop; ~/spotter-night/bin/night.sh cron-remove'

spotter-night-pull: ## spotter S0: NIGHT_DAY's SUMMARY.md + moments (no fights) to ~/spotter-work/night/<date>/
	mkdir -p $(HOME)/spotter-work/night/$(NIGHT_DAY)
	rsync -az --include='*/' --include='SUMMARY.md' --include='moments.*' --include='yields.txt' --include='run.txt' --exclude='*' \
		$(SPOT_HOST):spotter-night/$(NIGHT_DAY)/ $(HOME)/spotter-work/night/$(NIGHT_DAY)/
	@cat $(HOME)/spotter-work/night/$(NIGHT_DAY)/SUMMARY.md 2>/dev/null | head -40

# ---- S3: clips (offscreen: its own Xvfb on builder3, Mesa llvmpipe = his gl_compatibility renderer; the GPU encodes) ------------
SPOT_CLIPS ?= 30
.PHONY: spotter-clips spotter-clip
SPOT_RANKS ?=
spotter-clips: native-fresh import ## spotter S3: the top SPOT_CLIPS moments of SPOT_DIR (or SPOT_RANKS=31-100 + the controls) as clips -> SPOT_DIR/clips/*.mp4 + clips.json (one Godot at a time; LIGHT=1 is fine)
	$(PYTHON) tools/spotter/clips.py $(SPOT_DIR) --top $(SPOT_CLIPS) --godot $(GODOT) $(if $(SPOT_RANKS),--ranks $(SPOT_RANKS))

spotter-clip: native-fresh import ## spotter S3: one clip from a moment's reproduction line (SPOT_SEED SPOT_ARENA SPOT_CREW SPOT_FROM SPOT_TO) -> SPOT_DIR/clips/
	$(PYTHON) tools/spotter/clips.py $(SPOT_DIR) --godot $(GODOT) --one $(SPOT_SEED) $(SPOT_ARENA) "$(SPOT_CREW)" $(SPOT_FROM) $(SPOT_TO)
