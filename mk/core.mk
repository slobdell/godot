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
LINT_BASELINE := tests/baselines/lint_expected.txt

# ---- lint proves it can still SEE an error, every run (2026-09-20) ----------------------------
# `make lint` reported "all scripts parse" on a tree whose runtime could not compile `movement.gd`
# (`Cannot infer the type of "my_map"`, cascading through every dependent script), while the SAME tree
# failed lint in another worktree. So the checker is not reliably able to SEE an error, and a gate that
# cannot be shown to fail is not a gate -- lesson 147, from the other end: there it was an empty comparison
# proving nothing, here it is an empty RESULT proving nothing.
#
# TWO liveness probes, because they fail in different ways.
#
#   * The eight baselined artefacts cost nothing: they are real parse errors that real project files produce
#     every run. If the whole run yields ZERO findings while the baseline expects eight, the checker did not
#     look, and the run says so instead of saying "all scripts parse".
#   * A SYNTHETIC file with a type-inference error is checked alongside, and its finding is REQUIRED. This
#     is the stronger one: it proves the checker can still see a NEW error rather than reproduce known ones,
#     and it is deliberately the same construct that escaped lint on `f1128ef5` (a ternary whose inferred
#     type cannot be resolved). **Measured on builder0 before being relied on** (`b839495c`): the file
#     resolves at `res://build/...` and `--check-only` reports it, with and without the class-name cache.
#     That experiment also settled the bug itself -- the checker sees this class fine, so the run that went
#     green never checked `movement.gd` at all, which is the hole closed above and NOT a per-file blind spot.
#
# And two silent passes are closed. Per file the checker's raw output and exit status are both kept, so:
#   * no output AT ALL (Godot always prints its banner) means the process never ran -- OOM on a loaded box,
#     a bad path -- and is reported, not counted clean;
#   * an exit of 128+ means it was killed by a signal, likewise.
# Both used to produce an empty `out` and read exactly like a file that parses.
#
# WHAT THIS DOES NOT FIX, and it is the bigger half: a per-file `--check-only` cannot see an error that only
# appears when the project is compiled TOGETHER. `movement.gd` may be exactly that class. Deciding whether
# `check` also needs a whole-project compile pass is the orchestrator's; it cannot be settled from a laptop
# that must not run Godot.
lint: import ## Parse-check every GDScript file; fails on any finding NOT in tests/baselines/lint_expected.txt
	@mkdir -p $(BUILD_DIR)
	@exec 9>$(BUILD_DIR)/.lint.lock; \
	flock -n 9 || { \
		echo "lint: another lint is already running in this checkout ($(CURDIR)) -- refusing."; \
		echo "      A second lint runs \`import\` first, and that rewrites the .godot cache the first is reading."; \
		echo "      Wait for it, or kill it AND its Godot children (a killed wrapper leaves them)."; \
		exit 1; }; \
	files=$$(git ls-files -co --exclude-standard '*.gd' 2>/dev/null || true); \
	if [ -z "$$files" ]; then \
		files=$$(find . -name '*.gd' -not -path './.git/*' -not -path './.godot/*' -not -path './.tools/*' \
			-not -path './build/*' -not -path './node_modules/*' | sed 's|^\./||' | sort); \
	fi; \
	count=$$(printf '%s\n' "$$files" | grep -c . || true); \
	[ "$$count" -gt 0 ] || { echo "lint FAILED: found no .gd files to check. That is not a clean tree, it is a"; \
		echo "            broken file list -- see the note above this recipe."; exit 1; }; \
	selftest=$(BUILD_DIR)/lint-selftest/type_inference_probe.gd; \
	mkdir -p $(BUILD_DIR)/lint-selftest; \
	cp tests/fixtures/ternary_infer_probe.gd.txt "$$selftest"; \
	printf '%s\n' "$$files" "$$selftest" | \
		xargs -P $(LINT_JOBS) -I{} sh -c \
			'raw=$$($(GODOT) --headless --path . --check-only --script "res://$$1" 2>&1); rc=$$?; \
			out=$$(printf "%s\n" "$$raw" | grep -E "Parse Error|SCRIPT ERROR" | grep -v "depended scripts" || true); \
			if [ -n "$$out" ]; then printf "%s\n" "$$out" | sed "s|^|$$1: |"; \
			elif [ -z "$$(printf "%s" "$$raw" | tr -d "[:space:]")" ]; then \
				printf "%s: CHECKER PRODUCED NO OUTPUT AT ALL (exit %s) -- not a pass\n" "$$1" "$$rc"; \
			elif [ "$$rc" -ge 128 ]; then \
				printf "%s: CHECKER KILLED BY SIGNAL %s (exit %s) -- not a pass\n" "$$1" "$$(( rc - 128 ))" "$$rc"; \
			fi' _ {} \
		| sort > $(BUILD_DIR)/lint.raw; \
	seen=$$(grep -c "type_inference_probe.gd:" $(BUILD_DIR)/lint.raw || true); \
	grep -v "type_inference_probe.gd:" $(BUILD_DIR)/lint.raw > $(BUILD_DIR)/lint.out || true; \
	if [ "$$seen" -eq 0 ]; then \
		echo "lint FAILED: the checker did not report the deliberately broken file it was handed."; \
		echo "  That file has a type-inference error of exactly the kind that escaped lint on f1128ef5, and"; \
		echo "  builder0 was measured reporting it. A checker that cannot see an error it was pointed at"; \
		echo "  cannot be trusted to have seen a real one, so this run says NOTHING about the tree."; \
		exit 1; \
	fi; \
	sort $(LINT_BASELINE) 2>/dev/null | grep -v '^#' | grep -v '^$$' > $(BUILD_DIR)/lint.expected || true; \
	expected_n=$$(grep -c . $(BUILD_DIR)/lint.expected || true); \
	found_n=$$(grep -c . $(BUILD_DIR)/lint.out || true); \
	if [ "$$expected_n" -gt 0 ] && [ "$$found_n" -eq 0 ]; then \
		echo "lint FAILED: the checker reported NOTHING over $$count files, while $(LINT_BASELINE) says"; \
		echo "  $$expected_n findings are expected from files that are in the tree right now. A checker that"; \
		echo "  cannot see the errors it saw yesterday cannot be trusted to have seen a new one, so this run"; \
		echo "  says nothing about the tree. Look at the checker: a killed Godot, an exhausted box, a bad"; \
		echo "  file list. (If the artefacts were genuinely fixed, re-record the baseline and say why.)"; \
		exit 1; \
	fi; \
	new=$$(comm -23 $(BUILD_DIR)/lint.out $(BUILD_DIR)/lint.expected); \
	gone=$$(comm -13 $(BUILD_DIR)/lint.out $(BUILD_DIR)/lint.expected); \
	if [ -n "$$new" ]; then \
		echo "lint FAILED over $$count files -- findings that are NOT in $(LINT_BASELINE):"; \
		printf '%s\n' "$$new" | sed 's/^/  /'; \
		echo "  (if these are --check-only isolation artefacts too, add them to the baseline WITH THE REASON;"; \
		echo "   if they are real, fix them. Do not widen the grep.)"; \
		exit 1; \
	fi; \
	if [ -n "$$gone" ]; then \
		echo "lint: $$(printf '%s\n' "$$gone" | grep -c .) baselined finding(s) no longer occur -- tighten $(LINT_BASELINE):"; \
		printf '%s\n' "$$gone" | sed 's/^/  /'; \
	fi; \
	echo "lint: all $$count scripts parse (-P$(LINT_JOBS), $$(grep -c . $(BUILD_DIR)/lint.expected || echo 0) known artefacts baselined, $$found_n findings seen, self-test seen)"

# T1 (metrics, round 9). MEASURED on builder0 at c21d0256, serially, per target:
#
#     test 2388 s | announcer-check 80 s | army-loop-smoke 24 s | combat-smoke 19 s | determinism 11 s
#     relay-smoke 11 s | garage-smoke 7 s | net-smoke 4 s | sim-baseline 4 s | broker-test 2 s
#     lobby-smoke 2 s | match-smoke 2 s | the pytest suites ~1 s
#
# **`test` is 2388 s of a 2554 s check: 93% of it.** Everything else in `check` put together is under three
# minutes. So the round-8 framing -- "the targets in check are largely independent, run them concurrently" -- was
# aimed at the wrong thing: running all twelve of the others perfectly in parallel saves under 3 minutes out of
# 42, and the >= 50% bar is unreachable while the suite is one process. The suite is where the check IS.
#
# So the suite shards: N processes, each running every Nth file of the SORTED discovery order (round-robin, so a
# shard gets a mix of cheap and expensive files rather than all of tests/ai_scenarios/). The shard flag lives in
# tests/run_tests.gd -- a shared file, in merge notes -- and an unsharded run is byte-identical to before,
# including its final line.
#
# **One `N passed, M failed` line, always.** A shard prints `SHARD i/n: ...` and never the bare line; this recipe
# sums them and prints the bare line once. The orchestrator reads that line and nothing else (lesson 28), and
# several of them would be worse than none.
#
# **FILTER forces the serial path**: a filtered run is short, and sharding it would make `make test FILTER=x`
# report a total assembled from N processes for no gain.
#
# **What was CHECKED before sharding, because a shard race is the worst kind of flake** (it depends on which
# files land together, so it moves when you add a test and reads as "flaky under load" -- lesson 4):
#   * `user://` -- 17 references across 10 test files, and NO path is touched by more than one file. Sharding
#     assigns whole FILES, so two shards can never write the same scratch save. (Verified by listing every
#     `user://` literal in tests/ and grouping by path; the intersection is empty.)
#   * ports -- no test under tests/ binds one. The network smokes that do are separate `check` targets, and they
#     are in the port exclusion groups above.
# A test that still turns out to depend on which shard it lands in is a TEST bug to report (lesson 36), not a
# shard assignment to reshuffle around.
#
# **The partition is verified, not merely argued.** `index % N` partitions the indices -- that is arithmetic --
# but "by construction" is exactly what round 8 said about a commitment term that was never in the code path. So
# it was checked directly and cheaply: the runner prints its file count BEFORE any filtering, so
# `--shard=i/N --filter=__no_such_test__` reports each shard's share in about five seconds without running a
# single test (it now exits 1, by design -- read the counts it printed, not its status).
# At N = 2, 3, 5 and 6 the shard file counts sum to **187** -- exactly the unsharded discovery count.
# Nothing is dropped and nothing is run twice, at any shard count. (metrics, 2026-09-20, laptop.)
# `:=`, NOT `?=`. `?=` creates a RECURSIVELY EXPANDED variable, so `$(shell ...)` re-runs on every reference --
# and this one is referenced three times in the recipe below (the `seq` that launches the shards, the `xargs -P`,
# and the count the guard verifies against). `slot.sh --jobs` reads free memory, so on a shared box the three
# answers differ: scale's CP2 check launched TWO shards, both reported, 1395 passed, and then verified against
# THREE -- so my own guard fired on a run in which every test had passed. Found by scale, 2026-09-20; trip-up
# 67's family, where make evaluates a variable differently from how the author read it.
# The `$(if ...)` keeps `?=`'s "leave an existing value alone" while running the shell exactly once per make.
TEST_SHARDS := $(if $(TEST_SHARDS),$(TEST_SHARDS),$(shell tools/slot.sh --jobs 500 $$(( $$(nproc) / 2 ))))

# FILTER reaches the runner INSIDE SINGLE QUOTES. Unquoted, `make test FILTER="a|b"` handed the pipe to a
# shell and exited 127 without running either suite (it bit combat twice on 2026-09-20). Quoting alone would
# have been worse than the crash -- the filter is a substring, so "a|b" would have matched nothing and
# reported success -- so the runner also takes `|` as ALTERNATION and fails a filter that matches no tests.
# TWO characters cannot get through, and both are refused BY NAME rather than silently becoming a different
# filter: `'`, which single-quoting cannot carry, and `$`, which MAKE expands before any shell sees it --
# `FILTER=$HOME` arrives at the runner as `OME`. That second one was found by the test below, not by
# reading: the fix was quoting against the SHELL and make had already eaten it.
_FILTER_BAD := $(findstring ',$(value FILTER))$(findstring $$,$(value FILTER))
.PHONY: _filter-ok
_filter-ok:
	@test -z "$(_FILTER_BAD)" || { \
		echo "make test: FILTER may not contain a single quote or a dollar sign."; \
		echo "  ' cannot survive: the filter reaches the runner inside single quotes."; \
		echo "  \$$ never reaches the shell at all -- MAKE expands it first, so FILTER=\$$HOME arrives as"; \
		echo "  OME. Both are refused by name rather than silently becoming a different filter, which is"; \
		echo "  the worst of the three outcomes. Spaces, |, backticks and brackets are all fine."; exit 2; }

test: _filter-ok import ## Run the headless test suite (FILTER=substring, | for alternatives, fails if it matches nothing; TEST_SHARDS=1 forces one process)
	@if [ -n "$(FILTER)" ] || [ "$(TEST_SHARDS)" -le 1 ]; then \
		$(GODOT) --headless --path . --script res://tests/run_tests.gd -- '--filter=$(FILTER)'; \
		exit $$?; \
	fi; \
	rm -rf $(BUILD_DIR)/test-shards && mkdir -p $(BUILD_DIR)/test-shards; \
	seq 0 $$(( $(TEST_SHARDS) - 1 )) | xargs -P $(TEST_SHARDS) -I{} sh -c \
		'$(GODOT) --headless --path . --script res://tests/run_tests.gd -- --shard={}/$(TEST_SHARDS) \
			> $(BUILD_DIR)/test-shards/{}.log 2>&1; echo $$? > $(BUILD_DIR)/test-shards/{}.status'; \
	cat $(BUILD_DIR)/test-shards/*.log; \
	shards=$$(grep -h '^SHARD ' $(BUILD_DIR)/test-shards/*.log | wc -l); \
	if [ "$$shards" -ne "$(TEST_SHARDS)" ]; then \
		echo "test FAILED: $$shards of $(TEST_SHARDS) shards reported a summary line. A shard that died without"; \
		echo "             printing one would otherwise vanish from the total, which is the worst way to pass."; \
		exit 1; \
	fi; \
	files=$$(grep -h '^SHARD ' $(BUILD_DIR)/test-shards/*.log | sed 's/.*: \([0-9]*\) files.*/\1/' | paste -sd+ | bc); \
	passed=$$(grep -h '^SHARD ' $(BUILD_DIR)/test-shards/*.log | sed 's/.* \([0-9]*\) passed.*/\1/' | paste -sd+ | bc); \
	failed=$$(grep -h '^SHARD ' $(BUILD_DIR)/test-shards/*.log | sed 's/.* \([0-9]*\) failed.*/\1/' | paste -sd+ | bc); \
	eerr=$$(grep -h '^SHARD-ENGINE ' $(BUILD_DIR)/test-shards/*.log | sed 's/.* \([0-9]*\) errors.*/\1/' | paste -sd+ | bc 2>/dev/null); \
	ewarn=$$(grep -h '^SHARD-ENGINE ' $(BUILD_DIR)/test-shards/*.log | sed 's/.* \([0-9]*\) warnings.*/\1/' | paste -sd+ | bc 2>/dev/null); \
	echo ""; \
	echo "$(TEST_SHARDS) shards over $$files files"; \
	echo "engine: $${eerr:-0} errors, $${ewarn:-0} warnings"; \
	echo "$$passed passed, $$failed failed"; \
	[ "$$failed" -eq 0 ] || exit 1

# ---- Verification bundles (see _agents/verification.md) ------------------------

# match-pytest is LAST and it is 3 ms: the measurement tools' own guards (what compare_arms refuses to subtract).
# Those guards sit on the hot path of every future measurement, and this round shipped two that had never been run
# end to end -- one crashed every run it was added to protect, the other exited 0 while refusing. Appended rather
# than inserted because `check` aborts at the first failing target, so anything added early hides everything after.
# T1 (metrics, round 9). ONE list, used by `check` and by `check-timed`, so a target can never be measured and
# not run (or run and not measured). Order is the serial order `check` has always used: `match-pytest` stays LAST
# for the reason above.
# `metrics-pytest` is here for `match-pytest`'s reason and not arena's. arena keeps `arena-pytest` OUT of `check`
# because it guards an instrument only arena reads. A12 is the opposite case: contract S3 makes EVERY stream's
# falsifier this round read from `tools/metrics/` and no other tool, so its guards sit on the hot path of every
# measurement anyone publishes -- and it costs 0.6 s.
# `ai-scenarios-check` joins for lesson 159's reason: nav found squad's leash commit errors in a scenario that
# `check` never ran. It is gated on a CHANGE in the passed/failed/pending counts rather than on outcome, so the
# one laptop-speed-sensitive perf case cannot redden the gate while a new script error still does (mk/metrics.mk).
# **It needs no exclusion edge, and that was checked rather than assumed:** `run_scenarios.gd` binds no port and
# touches no `user://` path, and the target writes only `build/ai-scenarios.log`.
CHECK_TARGETS := lint test net-smoke combat-smoke broker-test relay-smoke lobby-smoke match-smoke determinism \
                 sim-baseline garage-smoke army-loop-smoke announcer-check audio-check match-pytest metrics-pytest \
                 ai-scenarios-check remote-guard-test

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
# Both DERIVED from the machine, never hard-coded (lesson 148), and both from a MEASURED footprint:
#   CHECK_JOBS  1000 MB, from the MEASURED per-target peak RSS on builder0: audio-check 919, test 427, the
#               smokes 250-273, broker-test 84. `/usr/bin/time -v` reports the largest single PROCESS, not the
#               sum, and `net-smoke` and `relay-smoke` each hold three at once -- so ~250 x 3 is a target's real
#               worst case and audio-check's single 919 is the ceiling. 1000 covers both. The earlier 2200 was
#               a guess from round 8's "~735 MB a Godot run" and was more than twice too pessimistic.
#   LINT_JOBS   a `--check-only` process peaks at 200-205 MB, measured twice on the laptop (not the ~735 MB a
#               RUNNING match costs -- it parses and exits without ever building a world). 250 MB with a
#               half-the-cores cap, because lint runs CONCURRENTLY with up to CHECK_JOBS other targets and the
#               two budgets share one machine.
# ⚠ All three are `$(shell ...)`, so they are RE-DERIVED in every make invocation -- and `check` runs a sub-make.
# MemAvailable moves between the two evaluations, so the header printed `test x3` while the run did `2 shards`
# (seen on builder0, 2026-09-20). The guard was never wrong -- it compares against the value its own loop used --
# but a header that disagrees with its run is exactly the kind of thing that costs an hour later, so `check`
# passes its OWN values down to the sub-make and the whole check uses one evaluation.
# `:=` for the same reason as TEST_SHARDS above -- see that note. Each is referenced more than once (the header
# line, the -j, the value handed to the sub-make), and a header that disagrees with the run it describes is how
# an hour goes missing later.
CHECK_JOBS := $(if $(CHECK_JOBS),$(CHECK_JOBS),$(shell tools/slot.sh --jobs 1000))
LINT_JOBS  := $(if $(LINT_JOBS),$(LINT_JOBS),$(shell tools/slot.sh --jobs 250 $$(( $$(nproc) / 2 ))))
_CHECK_WRAPPED := $(addprefix _cp-,$(CHECK_TARGETS))

# The heartbeat (lesson 48). `-Otarget` holds each target's output until that target finishes, which is what
# keeps a parallel run readable -- and it also means a 30-minute check can print NOTHING for 30 minutes. A wait
# with no heartbeat is indistinguishable from a hang, and this project has already spent an hour misdiagnosing a
# starved queue as "builder0 is slow" for exactly that reason (tools/slot.sh's own note). So a side process
# reports every minute, on stderr, unbuffered: how long, how many done, and WHICH targets are still outstanding.
# It reads marker files the wrappers touch, so it cannot disagree with what make actually finished.
# ---- `check` KEEPS GOING, and reports every target's verdict (2026-09-20) ----------------------
# It used to hand its list to one `make -j` without `-k`, so the first failure stopped the rest from
# starting. Two combat checks in a row therefore produced **no `sim-baseline` reading at all**: the one
# number that gates every merge went missing behind an unrelated shard failure, and nothing in the log said
# so -- a target that never ran looked exactly like one that passed.
#
# The cost is real and deliberate: a check with a failure now takes its full wall-clock instead of stopping
# early. That is the right trade, because the reason to run a check is to learn what is wrong, and stopping
# at the first thing means learning one thing per forty minutes.
#
# `lint` is the exception and stays FIRST (an order-only edge from every other wrapper): a parse error makes
# every Godot target below fail describing the symptom rather than the cause. Its dependents then come back
# NOT RUN, which `check_verdict.sh` reports as its own state -- not as a pass, and not as a failure.
check: ## Everything headless: tests + network + relay + combat + match runner + garage (no display/browser)
	@printf '>> check: %s targets, up to %s at once (lint -P%s, test x%s) on %s | commit %s | load %s | MemAvailable %s MB | %s other godot\n' \
		"$(words $(CHECK_TARGETS))" "$(CHECK_JOBS)" "$(LINT_JOBS)" "$(TEST_SHARDS)" "$$(hostname)" \
		"$$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown})" \
		"$$(cut -d' ' -f1-3 /proc/loadavg)" "$$(awk '/MemAvailable/{print int($$2/1024)}' /proc/meminfo)" \
		"$$(pgrep -c -f 'Godot_v' || echo 0)"
	@rm -rf $(BUILD_DIR)/check/done $(BUILD_DIR)/check/started $(BUILD_DIR)/check/running && mkdir -p $(BUILD_DIR)/check/done $(BUILD_DIR)/check/started $(BUILD_DIR)/check/running
	@$(MAKE) --no-print-directory import
	@started=$$(date +%s); \
	( while sleep 60; do \
		left=""; failed=""; count=0; \
		for target in $(CHECK_TARGETS); do \
			if [ -e $(BUILD_DIR)/check/done/$$target ]; then count=$$(( count + 1 )); \
			elif [ -e $(BUILD_DIR)/check/started/$$target ] && [ ! -e $(BUILD_DIR)/check/running/$$target ]; then \
				failed="$$failed $$target"; \
			else left="$$left $$target"; fi; \
		done; \
		[ -z "$$left" ] && break; \
		elapsed=$$(( $$(date +%s) - started )); \
		printf '>> check: %dm%02ds, %d/%d done, waiting on:%s%s\n' \
			"$$(( elapsed / 60 ))" "$$(( elapsed % 60 ))" "$$count" "$(words $(CHECK_TARGETS))" "$$left" \
			"$$([ -n "$$failed" ] && printf ' | already FAILED:%s' "$$failed")" >&2; \
	done ) & heartbeat=$$!; \
	trap 'kill $$heartbeat 2>/dev/null' EXIT INT TERM; \
	$(MAKE) --no-print-directory -k -j$(CHECK_JOBS) -Otarget \
		TEST_SHARDS=$(TEST_SHARDS) LINT_JOBS=$(LINT_JOBS) check-parallel || true; \
	printf '>> check: %ds total on %s\n' "$$(( $$(date +%s) - started ))" "$$(hostname)" >&2; \
	$(MAKE) --no-print-directory check-hashes >&2 || true; \
	if tools/check_verdict.sh $(BUILD_DIR)/check $(CHECK_TARGETS) >&2; then status=0; else status=1; fi; \
	exit $$status

# The hash verdict, in ONE comparable line. It exists because `determinism`'s own line truncates its JSON at 120
# characters, so its state_hash never reached a log -- and `build/determinism_1.json`, the only carrier, is
# overwritten by the next run. CP3 could therefore show `sim-baseline` bit-identical between the serial and the
# parallel check but could only INFER it for `determinism`. A verdict you cannot compare after the fact is not
# much of a verdict.
#
# It also answers the other half: when gameplay moves the baseline on purpose, recording it is two hand-run
# commands and this prints them, with the machine, rather than leaving it to memory (Invariant 2).
.PHONY: check-hashes
check-hashes: ## The sim hashes from the last run, in one comparable line (both hashes, the machine, what moved)
	@# ⚠ NOT-RUN is tested FIRST below. Written the other way round, absent data ("-" equals "-") reads as
	@# "baseline unmoved" -- a zero that means "no data", in the very line added to stop a verdict being
	@# uncomparable. It printed exactly that on its first run. Same family as `lint` reporting "all scripts
	@# parse" over zero files, and as `arc_live=0.0s` for an unpublished field.
	@det=$$($(PYTHON) -c "import json;print(json.load(open('$(BUILD_DIR)/determinism_1.json'))['state_hash'])" 2>/dev/null || echo "-"); \
	if [ -r $(BUILD_DIR)/sim_baseline.txt ]; then \
		set -- $$(cat $(BUILD_DIR)/sim_baseline.txt); key=$$1; actual=$$2; expected=$$3; \
	else key="-"; actual="-"; expected="-"; fi; \
	if [ "$$actual" = "-" ]; then verdict="NOT RUN"; \
	elif [ "$$expected" = "none" ]; then verdict="NO BASELINE for $$key on this machine"; \
	elif [ "$$actual" = "$$expected" ]; then verdict="baseline unmoved"; \
	else verdict="MOVED: $$expected -> $$actual"; fi; \
	printf '>> check: hashes on %s | sim-baseline %s (%s) | determinism %s\n' \
		"$$(hostname)" "$$actual" "$$verdict" "$$det"; \
	if [ "$$verdict" != "$${verdict#MOVED}" ]; then \
		echo "   to adopt the move (only if gameplay changed ON PURPOSE -- the orchestrator records it, Invariant 2):"; \
		echo "     make sim-baseline-adopt      # reads twice on builder0, refuses a disagreement, merges, prints the message"; \
	fi

.PHONY: check-parallel $(_CHECK_WRAPPED)
check-parallel: $(_CHECK_WRAPPED) ## (internal) check's targets for `make -j`; run `make check`, not this
	@echo "check passed: $(words $(CHECK_TARGETS)) targets"

# ⚠ THE WRAPPER RUNS THE TARGET; IT DOES NOT DEPEND ON IT. That distinction is the whole exclusion mechanism,
# and getting it wrong made the groups INERT -- found by CP3's own flake criterion on 2026-09-20, which is the
# best argument for that criterion I can offer.
#
# The wrappers used to read `_cp-lobby-smoke: lobby-smoke | _cp-relay-smoke`. An order-only prerequisite orders
# `_cp-relay-smoke` before **the wrapper** -- but `lobby-smoke` is a NORMAL prerequisite of that same wrapper,
# and make is free to build both prerequisites CONCURRENTLY. So the real work raced anyway: both targets started
# a broker on $(SMOKE_BROKER_PORT) and lobby-smoke died. It only showed at CHECK_JOBS=3; two runs of the same
# series at CHECK_JOBS=2 passed without ever exercising it.
#
# Now each wrapper has NO normal prerequisite and invokes its target from its own recipe, so the order-only edge
# constrains the work itself. `-o import` because `check` has already built it and 16 sub-makes must not each
# redo it (that would also put 16 writers on the .godot cache, which is the one thing lint's lock is about).
$(foreach t,$(CHECK_TARGETS),$(eval _cp-$(t): ; @mkdir -p $$(BUILD_DIR)/check/started $$(BUILD_DIR)/check/done $$(BUILD_DIR)/check/running && touch $$(BUILD_DIR)/check/started/$(t) $$(BUILD_DIR)/check/running/$(t) && { $$(MAKE) --no-print-directory -o import $(t); s=$$$$?; rm -f $$(BUILD_DIR)/check/running/$(t); [ $$$$s -eq 0 ] && touch $$(BUILD_DIR)/check/done/$(t); exit $$$$s; }))

# LINT GATES EVERY OTHER TARGET. A file that does not parse makes every Godot target below fail in a way
# that describes the symptom and not the cause, and reading sixteen of those to find one parse error is
# how an hour goes. Ordered, not merged into the batch, so `-k` skips the rest rather than running them
# into the same wall -- and they come back NOT RUN, which is not the same as passing.
$(foreach t,$(filter-out lint,$(CHECK_TARGETS)),$(eval _cp-$(t): | _cp-lint))

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
		"$$total" "$$(( total / 60 ))" "$$(( total % 60 ))" "$(words $(CHECK_TARGETS))"; \
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
# ONE definition of the read, used by the check, the recorder and the adopter alike. Three copies of a
# forty-second match with eight flags is three chances for the number we ADOPT to come from a slightly
# different run than the number we VERIFY -- and the resulting failure would read as a gameplay change on
# every machine at once, with nothing in the output pointing at the flags.
SIM_HASH_READ = $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --green-doctrine=res://doctrines/sim_baseline_green.json --rust-doctrine=res://doctrines/sim_baseline_rust.json --time-limit=40 --seed=3 2>/dev/null | grep MATCH_RESULT | $(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"

sim-baseline: import ## The simulation matches the recorded baseline hash for this machine's libm (art must never change gameplay)
	@key="glibc-$$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)"; \
	expected=$$(awk -v k="$$key" '$$1 == k {print $$2}' tests/baselines/sim_state_hash.txt); \
	actual=$$($(SIM_HASH_READ)); \
	mkdir -p $(BUILD_DIR); printf '%s %s %s\n' "$$key" "$$actual" "$${expected:-none}" > $(BUILD_DIR)/sim_baseline.txt; \
	if [ -z "$$expected" ]; then echo "sim-baseline SKIPPED: no baseline for $$key (got $$actual). The canonical one is builder0's (make remote T=check); see _agents/determinism.md"; \
	elif [ "$$actual" = "$$expected" ]; then echo "sim-baseline passed: $$actual ($$key)"; \
	else echo "sim-baseline FAILED: expected $$expected for $$key, got $$actual. If gameplay changed ON PURPOSE: make sim-baseline-adopt (reads twice on builder0, refuses a disagreement, merges the line, prints the commit message)"; exit 1; fi

sim-baseline-record: import ## Write this machine's sim baseline line to build/sim_state_hash.txt (copy it over tests/baselines/ when gameplay changed on purpose)
	@key="glibc-$$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)"; \
	actual=$$($(SIM_HASH_READ)); \
	test -n "$$actual" || { echo "no MATCH_RESULT"; exit 1; }; \
	mkdir -p $(BUILD_DIR); printf '%s %s\n' "$$key" "$$actual" > $(BUILD_DIR)/sim_state_hash.txt; \
	echo "recorded $$key $$actual in $(BUILD_DIR)/sim_state_hash.txt"; \
	echo "  prefer 'make sim-baseline-adopt': it reads TWICE, refuses a disagreement, and merges the line"; \
	echo "  instead of copying the file over (a cp DELETES every other machine's baseline -- one line in)"

# ---- Adopting a moved baseline, in one command instead of four by hand -------------------------
# The hand procedure was: run the recorder on builder0, run it AGAIN, compare the two by eye, copy the file
# over the baseline, write the commit message. It was done twice by hand this morning. Each step is a place
# to be interrupted, and the comparison by eye is the step that matters: **a hash that does not reproduce on
# its own machine is not a baseline, it is a coin** -- which is the mistake `ai_scenarios_count.txt` had
# already made this round in a different file.
sim-baseline-adopt-read: import ## (on the build box) read the sim hash TWICE and refuse if the two disagree
	@key="glibc-$$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)"; \
	echo ">> sim-baseline-adopt: first read on $$(hostname)..."; \
	first=$$($(SIM_HASH_READ)); \
	test -n "$$first" || { echo "sim-baseline-adopt FAILED: no MATCH_RESULT on the first read"; exit 1; }; \
	echo ">> sim-baseline-adopt: first read $$first; second read..."; \
	second=$$($(SIM_HASH_READ)); \
	test -n "$$second" || { echo "sim-baseline-adopt FAILED: no MATCH_RESULT on the second read"; exit 1; }; \
	if [ "$$first" != "$$second" ]; then \
		echo "sim-baseline-adopt REFUSED: the two reads DISAGREE on this machine."; \
		echo "  first:  $$first"; \
		echo "  second: $$second"; \
		echo "  A hash that does not reproduce on its own machine is not a baseline. Something in the"; \
		echo "  simulation is not deterministic; adopting either number would bless it and every later"; \
		echo "  check would compare against a coin. Find the non-determinism first."; \
		exit 1; \
	fi; \
	mkdir -p $(BUILD_DIR); \
	printf '%s %s\n' "$$key" "$$second" > $(BUILD_DIR)/sim_state_hash.txt; \
	printf 'key=%s\nhash=%s\ncommit=%s\nmachine=%s\ndate=%s\n' \
		"$$key" "$$second" "$${TANK_SQUAD_COMMIT:-$$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}" \
		"$$(hostname)" "$$(date +%F)" > $(BUILD_DIR)/sim_baseline_adopt.env; \
	echo ">> sim-baseline-adopt: $$key $$second, read twice, agreeing"

sim-baseline-adopt: ## Read the sim hash TWICE on builder0, refuse a disagreement, adopt it here, print the commit message
	@rm -f $(BUILD_DIR)/sim_baseline_adopt.env $(BUILD_DIR)/sim_state_hash.txt
	tools/remote.sh sim-baseline-adopt-read
	@# Refuse to adopt from files that did not come back: an absent result must never read as a measurement.
	@test -s $(BUILD_DIR)/sim_baseline_adopt.env || { \
		echo "sim-baseline-adopt FAILED: no $(BUILD_DIR)/sim_baseline_adopt.env came back from the box."; \
		echo "  The run may have passed there, but nothing local proves what it read. Nothing was adopted."; \
		exit 1; }
	@set -a; . ./$(BUILD_DIR)/sim_baseline_adopt.env; set +a; \
	$(PYTHON) tools/baseline_merge.py tests/baselines/sim_state_hash.txt "$$key" "$$hash" "$$commit" "$$machine" "$$date"; \
	echo ""; \
	echo "Now commit it, and say WHY the baseline moved (Invariant 2 -- a moved baseline with no named cause"; \
	echo "is a regression nobody noticed):"; \
	echo ""; \
	echo "    git add tests/baselines/sim_state_hash.txt"; \
	echo "    git commit -m \"baselines: sim hash $$key -> $$hash on $$machine (<the change that moved it>)"; \
	echo ""; \
	echo "    Read twice at $$commit on $$machine, agreeing. <Why gameplay changed on purpose.>\""

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

remote-status: ## What is running in THIS worktree's folder on builder0 (read-only; ask before REMOTE_FORCE=1)
	@tools/remote.sh --status

round-status: ## One screen: every worktree vs main, builder0's load and live runs by stream, the baselines in force
	@tools/round_status.sh

remote-quiet: ## A TIMING run on builder0 that holds the whole box and says whether the window held: T="perf-trailer-ab"
	@test -n "$(T)" || { echo 'usage: make remote-quiet T="perf-trailer-ab"'; exit 2; }
	tools/remote.sh --quiet $(T)

# The guard that stops `make remote` rsyncing --delete over a run of your own that is still going. It is in
# `check` because it is a guard, and every defect round 9 found -- in the exclusion groups, in the shard count,
# in `lint`'s file list, in `check-hashes` -- was a guard nobody had ever exercised. This one costs ~1 s and
# needs no Godot, no ports and no `user://` path, so it joins with no exclusion edge.
remote-guard-test: shell-tools-test ## Alias kept for the name that shipped in CHECK_TARGETS

shell-tools-test: ## Every tools/test_*.sh known-answer suite (no Godot, ~20 s), and it FAILS if it finds none
	@suites=$$(ls tools/test_*.sh 2>/dev/null); \
	test -n "$$suites" || { echo "shell-tools-test FAILED: no tools/test_*.sh found. A suite that runs"; \
		echo "  nothing reports success, which is how \`lint\` passed over zero files for three rounds."; exit 1; }; \
	echo "shell-tools-test: $$(echo "$$suites" | wc -l) suites"; \
	rc=0; for s in $$suites; do echo "-- $$s"; bash $$s || rc=1; done; exit $$rc

# ---- Parallel workstreams (git worktrees; see _agents/workstreams.md) ---------------

worktree: ## Create ../godot-STREAM on branch stream/STREAM with isolated ports (STREAM=name OFFSET=1-9)
	tools/worktree.sh add $(STREAM) $(OFFSET)

worktrees: ## List worktrees: branch, port offset, uncommitted changes, commits behind/ahead of main
	@tools/worktree.sh list

worktree-remove: ## Remove ../godot-STREAM (refuses with uncommitted changes; keeps the branch)
	tools/worktree.sh remove $(STREAM)
