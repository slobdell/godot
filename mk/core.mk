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
# T1 (metrics, round 9): ONE lint per checkout still, but its files now fan out. At 1.82 s of Godot start-up per
# file x 531 files this was ~16 minutes on the laptop and the single largest target in `check` -- and it is
# embarrassingly parallel. Two things were MEASURED before touching it, because the lock above reads like a ban on
# any concurrency here and it is not:
#
#   1. `--check-only` never writes `.godot`. Snapshotted all 911 files under `.godot` (mtime and size), ran five
#      --check-only passes, diffed: no change. The exclusive writer is `import`, which is a prerequisite and has
#      already finished -- and re-reading the incident above, the second `make lint` ran `import` FIRST, which is
#      what corrupted the first lint's reads. The lock guards against a concurrent IMPORT, not against concurrent
#      parse checks.
#   2. Serial and `-P6` give byte-identical findings. 24 files: 35 s serial, 11 s parallel, same (empty) output,
#      `.godot` unchanged. Then with a deliberately broken file added, both arms reported the same parse error --
#      an empty comparison proves nothing, so the arm was proven (lesson 147).
#
# The lock stays: a second `make lint` would still run `import` underneath the first.
lint: import ## Parse-check every GDScript file; prints only errors (fast way to find compile errors)
	@exec 9>$(BUILD_DIR)/.lint.lock; \
	flock -n 9 || { \
		echo "lint: another lint is already running in this checkout ($(CURDIR)) -- refusing."; \
		echo "      A second lint runs \`import\` first, and that rewrites the .godot cache the first one is reading."; \
		echo "      Wait for it, or kill it AND its Godot children (a killed wrapper leaves them)."; \
		exit 1; }; \
	: > $(BUILD_DIR)/lint.out; \
	git ls-files -co --exclude-standard '*.gd' | \
		xargs -P $(LINT_JOBS) -I{} sh -c \
			'out=$$($(GODOT) --headless --path . --check-only --script "res://$$1" 2>&1 | grep -E "Parse Error|SCRIPT ERROR" | grep -v "depended scripts" || true); \
			[ -z "$$out" ] || printf "%s: %s\n" "$$1" "$$out"' _ {} >> $(BUILD_DIR)/lint.out; \
	if [ -s $(BUILD_DIR)/lint.out ]; then sort $(BUILD_DIR)/lint.out; exit 1; fi; \
	echo "lint: all scripts parse ($$(git ls-files -co --exclude-standard '*.gd' | wc -l) files, -P$(LINT_JOBS))"

test: import ## Run the headless test suite (FILTER=substring to run a subset)
	$(GODOT) --headless --path . --script res://tests/run_tests.gd -- --filter=$(FILTER)

# ---- Verification bundles (see _agents/verification.md) ------------------------

# match-pytest is LAST and it is 3 ms: the measurement tools' own guards (what compare_arms refuses to subtract).
# Those guards sit on the hot path of every future measurement, and this round shipped two that had never been run
# end to end -- one crashed every run it was added to protect, the other exited 0 while refusing. Appended rather
# than inserted because `check` aborts at the first failing target, so anything added early hides everything after.
# T1 (metrics, round 9). ONE list, used by `check` and by `check-timed`, so a target can never be measured and
# not run (or run and not measured). Order is the serial order `check` has always used: `match-pytest` stays LAST
# for the reason above.
CHECK_TARGETS := lint test net-smoke combat-smoke broker-test relay-smoke lobby-smoke match-smoke determinism \
                 sim-baseline garage-smoke army-loop-smoke announcer-check audio-check match-pytest

# ---- T1: `check` runs its targets CONCURRENTLY -------------------------------------------------
#
# Measured at the close of round 8: a `check` on builder0 is ONE single-threaded Godot at ~7% CPU on a 12-thread
# machine for 30-50 minutes. It is latency-bound on awaiting fixed-tick physics frames, not compute-bound, so the
# machine sits idle while an entire round waits on it. More slots shortens the QUEUE; only this shortens the RUN.
#
# THE DEPENDENCY MAP, which is the whole of the design. Every target in CHECK_TARGETS is independent of every
# other EXCEPT these four constraints, each read out of the recipes rather than assumed:
#
#   .godot          `import` writes it, and among these targets it is the ONLY writer (see `lint` above). It is a
#                   shared prerequisite, so ONE make invocation with -j builds it exactly once before anything
#                   else starts -- which is why `check` hands the whole list to a single sub-make and does not loop.
#   SMOKE_NET_PORT     net-smoke, combat-smoke  -- each starts a Godot server bound to it (mk/net.mk)
#   SMOKE_BROKER_PORT  relay-smoke, lobby-smoke -- each starts a broker bound to it (mk/net.mk)
#   user://garage_scratch/my_army.json
#                      garage-smoke, army-loop-smoke -- both run --garage-scratch and both rewrite the scratch
#                      army, and garage-smoke then asserts on the army it finds (mk/garage.mk). local.mk isolates
#                      WORKTREES from each other; it does not isolate two targets inside one checkout.
#
# Deliberately NOT constraints, with the reason, because each looks like one:
#   The sim hash -- determinism, sim-baseline, announcer-record-smoke and music-smoke all run matches and compare
#      hashes. Separate processes on a fixed tick hash identically under any load, and CP3's falsifier PROVES that
#      rather than assuming it: both hashes must come out bit-identical to the serial run's.
#   build/ logs  -- every target writes its own named file; there is no shared output path among them.
#
# The wrappers exist so the chains live HERE and not on the real targets: putting `| net-smoke` on `combat-smoke`
# itself would mean `make combat-smoke` silently ran net-smoke too, for every caller, forever.
CHECK_JOBS ?= $(shell tools/slot.sh --jobs 2200)
LINT_JOBS  ?= $(shell tools/slot.sh --jobs 800)
_CHECK_WRAPPED := $(addprefix _cp-,$(CHECK_TARGETS))

check: ## Everything headless: tests + network + relay + combat + match runner + garage (no display/browser)
	@echo ">> check: $(words $(CHECK_TARGETS)) targets, up to $(CHECK_JOBS) at once (lint -P$(LINT_JOBS)) on $$(hostname)"
	@$(MAKE) --no-print-directory -j$(CHECK_JOBS) -Otarget check-parallel

.PHONY: check-parallel $(_CHECK_WRAPPED)
check-parallel: $(_CHECK_WRAPPED) ## (internal) check's targets for `make -j`; run `make check`, not this
	@echo "check passed: $(words $(CHECK_TARGETS)) targets"

$(foreach t,$(CHECK_TARGETS),$(eval _cp-$(t): $(t)))

# The three exclusion groups, as order-only prerequisites between the wrappers.
_cp-combat-smoke:    | _cp-net-smoke
_cp-lobby-smoke:     | _cp-relay-smoke
_cp-army-loop-smoke: | _cp-garage-smoke

# T1 step (a): the BEFORE. Runs exactly the same targets, in the same order, one at a time, and records each one's
# wall-clock and peak RSS -- plus the machine and the load it ran under, because a check on an idle builder0 and a
# check with six streams live are different measurements (remote_builds.md: 6 min 40 s alone, ~50 min busy).
# Without this the falsifier ("wall-clock drops by >= 50%") cannot be read at all.
#
# It keeps going after a failure and reports every target's status at the end: a measurement run that stops at the
# first red tells you nothing about the twelve targets behind it.
check-timed: import ## T1: run check's targets one at a time with per-target wall-clock and peak RSS -> build/check/timings.tsv
	@mkdir -p $(BUILD_DIR)/check
	@rm -f $(BUILD_DIR)/check/timings.tsv
	@printf '# check-timed on %s, commit %s%s\n' "$$(hostname)" \
		"$$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown})" \
		"$$([ -n "$$(git status --porcelain 2>/dev/null)" ] && echo ' (DIRTY)' || true)" \
		| tee $(BUILD_DIR)/check/timings.tsv
	@printf '# %s cores, MemAvailable %s kB, load %s, %s other godot processes\n' \
		"$$(nproc)" "$$(awk '/MemAvailable/{print $$2}' /proc/meminfo)" \
		"$$(cut -d' ' -f1-3 /proc/loadavg)" "$$(pgrep -c -f 'Godot_v' || echo 0)" \
		| tee -a $(BUILD_DIR)/check/timings.tsv
	@printf '# target\tseconds\tpeak_rss_kb\texit\n' >> $(BUILD_DIR)/check/timings.tsv
	@started=$$(date +%s); failed=""; \
	for target in $(CHECK_TARGETS); do \
		start=$$(date +%s); \
		if /usr/bin/time -v -o $(BUILD_DIR)/check/$$target.time \
				$(MAKE) --no-print-directory -o import $$target \
				> $(BUILD_DIR)/check/$$target.log 2>&1; then \
			status=0; \
		else \
			status=$$?; failed="$$failed $$target"; \
		fi; \
		seconds=$$(( $$(date +%s) - start )); \
		rss=$$(sed -n 's/.*Maximum resident set size (kbytes): //p' $(BUILD_DIR)/check/$$target.time 2>/dev/null | head -1); \
		rss=$${rss:-0}; \
		printf '%s\t%d\t%s\t%d\n' "$$target" "$$seconds" "$$rss" "$$status" >> $(BUILD_DIR)/check/timings.tsv; \
		printf '>> check-timed: %-18s %5ds  peak %6s MB  exit %d\n' "$$target" "$$seconds" "$$(( rss / 1024 ))" "$$status"; \
	done; \
	total=$$(( $$(date +%s) - started )); \
	printf '# TOTAL\t%d\t\t\n' "$$total" >> $(BUILD_DIR)/check/timings.tsv; \
	printf '>> check-timed: TOTAL %ds (%dm%02ds) over %d targets\n' \
		"$$total" "$$(( total / 60 ))" "$$(( total %% 60 ))" "$(words $(CHECK_TARGETS))"; \
	grep -v '^#' $(BUILD_DIR)/check/timings.tsv | sort -k2 -rn | head -5 \
		| awk -F"\t" '{printf ">> check-timed: slowest %-18s %5ds\n", $$1, $$2}'; \
	if [ -n "$$failed" ]; then echo ">> check-timed: FAILED:$$failed (the timings above are still valid)"; exit 1; fi

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
