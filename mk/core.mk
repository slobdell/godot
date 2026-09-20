# Toolchain, lint, tests, verification bundles, cleanup
# Owner: shared (changes need a heads-up to every stream) (see _agents/workstreams.md). Included by the root Makefile.

# ---- Bootstrap ----------------------------------------------------------------

bootstrap: $(GODOT) $(TEMPLATES_OK) import doctor ## Install pinned Godot + templates into ./.tools, import the project

$(DOWNLOADS)/SHA512-SUMS.txt:
	mkdir -p $(DOWNLOADS)
	curl -fsSL --retry 3 -o $@ $(RELEASE_URL)/SHA512-SUMS.txt

$(GODOT): $(DOWNLOADS)/SHA512-SUMS.txt
	@echo ">> Downloading Godot $(GODOT_TAG) editor"
	curl -fL --retry 3 -C - -o $(DOWNLOADS)/$(EDITOR_ZIP) $(RELEASE_URL)/$(EDITOR_ZIP)
	cd $(DOWNLOADS) && grep " $(EDITOR_ZIP)$$" SHA512-SUMS.txt | sha512sum -c -
	mkdir -p $(GODOT_HOME)
	unzip -o -q $(DOWNLOADS)/$(EDITOR_ZIP) -d $(GODOT_HOME)
	touch $(GODOT_HOME)/._sc_
	rm -f $(DOWNLOADS)/$(EDITOR_ZIP)
	touch $@

$(TEMPLATES_OK): $(DOWNLOADS)/SHA512-SUMS.txt
	@echo ">> Downloading Godot $(GODOT_TAG) export templates (~1.3 GB, trimmed after extraction)"
	curl -fL --retry 3 -C - -o $(DOWNLOADS)/$(TEMPLATES_TPZ) $(RELEASE_URL)/$(TEMPLATES_TPZ)
	cd $(DOWNLOADS) && grep " $(TEMPLATES_TPZ)$$" SHA512-SUMS.txt | sha512sum -c -
	mkdir -p $(TEMPLATES_DIR)
	unzip -j -o -q $(DOWNLOADS)/$(TEMPLATES_TPZ) $(addprefix templates/,$(TEMPLATE_FILES)) -d $(TEMPLATES_DIR)
	chmod +x $(TEMPLATES_DIR)/linux_*.x86_64
	rm -f $(DOWNLOADS)/$(TEMPLATES_TPZ)
	touch $@

doctor: ## Report toolchain health (versions, templates, display)
	@echo "godot:     $$($(GODOT) --version 2>/dev/null || echo MISSING — run make bootstrap)"
	@echo "templates: $$(ls $(TEMPLATES_DIR) 2>/dev/null | grep -v '^\.' | tr '\n' ' ' || echo MISSING)"
	@echo "python:    $$($(PYTHON) --version 2>&1)"
	@echo "node:      $$($(NODE) --version 2>/dev/null || echo 'MISSING (only needed for make web-smoke)')"
	@echo "chrome:    $$($(CHROME) --version 2>/dev/null || echo 'MISSING (only needed for make web-smoke; set CHROME=...)')"
	@echo "display:   $${DISPLAY:-none (make run/screenshot need a display; tests/exports/web-smoke do not)}"

# Import rebuilds .godot/ (asset imports + the global class_name cache). Headless
# script runs do NOT see a newly added `class_name` until this has run, so every
# target that runs project code depends on it. It takes a few seconds.
import: $(GODOT)
	@mkdir -p $(BUILD_DIR) && touch $(BUILD_DIR)/.gdignore  # screenshots and exports are never project resources
	$(GODOT) --headless --path . --import

# ONE LINT PER CHECKOUT, ENFORCED (2026-09-19). Two `make lint` runs in one checkout share one
# `.godot` import cache, and the second corrupts what the first is reading: the symptom is a
# `Parse Error: [ext_resource] referenced non-existent resource` for a file that is TRACKED AND
# PRESENT, followed by cascading `SCRIPT ERROR: Nonexistent function` for methods that plainly
# exist. It reads exactly like a broken tree, and it cost this project an evening of believing
# `main` was red when `Units.roster` was defined the whole time.
#
# How it happened, because the mechanism matters more than the rule: a foreground `make lint` was
# killed by a 300 s timeout, which reaped the WRAPPER and left its Godot children running -- the
# same failure `_agents/remote_builds.md` records for `make remote`. A second run was then launched
# against the still-live first one. **A timeout that kills the parent does not stop the work**, so
# "I killed it" is not a reason to believe nothing is running.
#
# `flock -n` fails fast rather than queueing: a second lint is always a mistake, never a wait.
# Found by control, 2026-09-19, by filtering `pgrep` on cwd after the orchestrator wrongly asked
# whether a worktree was to blame.
lint: import ## Parse-check every GDScript file; prints only errors (fast way to find compile errors)
	@exec 9>$(BUILD_DIR)/.lint.lock; \
	flock -n 9 || { \
		echo "lint: another lint is already running in this checkout ($(CURDIR)) -- refusing."; \
		echo "      Two lints share one .godot cache and the second corrupts the first's reads."; \
		echo "      Wait for it, or kill it AND its Godot children (a killed wrapper leaves them)."; \
		exit 1; }; \
	status=0; for f in $$(git ls-files -co --exclude-standard '*.gd'); do \
		out=$$($(GODOT) --headless --path . --check-only --script "res://$$f" 2>&1 | grep -E 'Parse Error|SCRIPT ERROR' | grep -v 'depended scripts' || true); \
		if [ -n "$$out" ]; then echo "$$f: $$out"; status=1; fi; \
	done; \
	if [ $$status -eq 0 ]; then echo "lint: all scripts parse"; fi; exit $$status

test: import ## Run the headless test suite (FILTER=substring to run a subset)
	$(GODOT) --headless --path . --script res://tests/run_tests.gd -- --filter=$(FILTER)

# ---- Verification bundles (see _agents/verification.md) ------------------------

# match-pytest is LAST and it is 3 ms: the measurement tools' own guards (what compare_arms refuses to subtract).
# Those guards sit on the hot path of every future measurement, and this round shipped two that had never been run
# end to end -- one crashed every run it was added to protect, the other exited 0 while refusing. Appended rather
# than inserted because `check` aborts at the first failing target, so anything added early hides everything after.
check: lint test net-smoke combat-smoke broker-test relay-smoke lobby-smoke match-smoke determinism sim-baseline garage-smoke army-loop-smoke announcer-check audio-check match-pytest ## Everything headless: tests + network + relay + combat + match runner + garage (no display/browser)

check-all: check relay-drop-smoke relay-latency-smoke relay-rejoin-smoke screenshot web-smoke web-net-smoke web-relay-smoke web-host-smoke export-server ## check + desktop render + browser checks + server export
	timeout 20 $(BUILD_DIR)/server/tank_squad_server.x86_64 --headless --quit-after 150 -- --server=$(SMOKE_NET_PORT) --bots=2 2>&1 \
		| tee $(BUILD_DIR)/export-server-check.log | grep -E 'LISTENING|READY'
	! grep -E 'ERROR' $(BUILD_DIR)/export-server-check.log
	@echo "check-all passed. Now LOOK at build/screenshots/*.png"

# ---- Cleanup ------------------------------------------------------------------

clean: ## Remove build outputs and Godot's import cache
	rm -rf $(BUILD_DIR) .godot

distclean: clean ## Also remove the downloaded toolchain
	rm -rf $(TOOLS_DIR)

# The doctrines are sim_baseline_{green,rust}, NOT anvil_hammer/individuals, and the difference is the whole point:
# those two field five `tank` hulls and nothing else -- one unit of twenty-one, one of the four locomotion x mount
# combinations. "sim-baseline passed" therefore meant "a tank-vs-tank match on foundry is unchanged" while everyone
# read it as "gameplay is unchanged", and four predictions that a change would move it failed for that one reason:
# a 14 m wheeled rig, a wheeled-turret facing fix, an arena bound and a facing contract all touched hulls the match
# never spawned. Most seriously, feel proved its art inert by passing this twice -- a proof that held for TANKS.
# The replacement fields every locomotion x mount combination on both sides at the same 40 seconds and one map.
sim-baseline: import ## The simulation matches the recorded baseline hash for this machine's libm (art must never change gameplay)
	@key="glibc-$$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)"; \
	expected=$$(awk -v k="$$key" '$$1 == k {print $$2}' tests/baselines/sim_state_hash.txt); \
	actual=$$($(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination \
		--green-doctrine=res://doctrines/sim_baseline_green.json --rust-doctrine=res://doctrines/sim_baseline_rust.json \
		--time-limit=40 --seed=3 2>/dev/null | grep MATCH_RESULT | $(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"); \
	if [ -z "$$expected" ]; then echo "sim-baseline SKIPPED: no baseline for $$key (got $$actual). The canonical one is builder0's (make remote T=check); see _agents/determinism.md"; \
	elif [ "$$actual" = "$$expected" ]; then echo "sim-baseline passed: $$actual ($$key)"; \
	else echo "sim-baseline FAILED: expected $$expected for $$key, got $$actual. If gameplay changed on purpose, run make remote T=sim-baseline-record, copy build/sim_state_hash.txt over tests/baselines/, and commit"; exit 1; fi

sim-baseline-record: import ## Write this machine's sim baseline line to build/sim_state_hash.txt (copy it over tests/baselines/ when gameplay changed on purpose)
	@key="glibc-$$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)"; \
	actual=$$($(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination \
		--green-doctrine=res://doctrines/sim_baseline_green.json --rust-doctrine=res://doctrines/sim_baseline_rust.json \
		--time-limit=40 --seed=3 2>/dev/null | grep MATCH_RESULT | $(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"); \
	test -n "$$actual" || { echo "no MATCH_RESULT"; exit 1; }; \
	mkdir -p $(BUILD_DIR); printf '%s %s\n' "$$key" "$$actual" > $(BUILD_DIR)/sim_state_hash.txt; \
	echo "recorded $$key $$actual in $(BUILD_DIR)/sim_state_hash.txt: cp it to tests/baselines/sim_state_hash.txt (other machines' lines go stale)"

# ---- Backups of generated assets (tools/backup_assets.sh; _agents/backups.md) -----------------------------
backup: ## Back up the generated assets that aren't in git (Meshy downloads, announcer masters) to builder0 now
	tools/backup_assets.sh

backup-status: ## When the backup last ran, what's on builder0, and how much room is left there
	@tools/backup_assets.sh --status

backup-install: ## Install and start the 30-minute systemd user timer that runs the backup
	mkdir -p $(HOME)/.config/systemd/user
	cp tools/systemd/tank-squad-backup.service tools/systemd/tank-squad-backup.timer $(HOME)/.config/systemd/user/
	systemctl --user daemon-reload
	systemctl --user enable --now tank-squad-backup.timer
	@systemctl --user list-timers tank-squad-backup.timer --no-pager

# ---- Remote builds on builder0 (tools/remote.sh; _agents/remote_builds.md) --------------------------------
remote: ## Run a make target on builder0 and copy build/ back: T="check" or T="test FILTER=combat"
	@test -n "$(T)" || { echo 'usage: make remote T="check"'; exit 2; }
	tools/remote.sh $(T)

# ---- Parallel workstreams (git worktrees; see _agents/workstreams.md) ---------------

worktree: ## Create ../godot-STREAM on branch stream/STREAM with isolated ports (STREAM=name OFFSET=1-9)
	tools/worktree.sh add $(STREAM) $(OFFSET)

worktrees: ## List worktrees: branch, port offset, uncommitted changes, commits behind/ahead of main
	@tools/worktree.sh list

worktree-remove: ## Remove ../godot-STREAM (refuses with uncommitted changes; keeps the branch)
	tools/worktree.sh remove $(STREAM)
