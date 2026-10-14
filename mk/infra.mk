# Round 29 (traffic's extension, the lead's ask: "might there be any ways to generally speed up our process so as not to
# be bottlenecked on builder0 all the time?"). builder0 throughput: the quick gate (I2) and the series cache (I3).

# I2: the quick gate for a worker's IN-BETWEEN commits: check's native stage first (incremental: free when native/ did not
# change; a bare `make test` after merging native changes runs a STALE library, and its native tests fail), lint, the tests the diff touches (tools/quick_tests.sh: changed
# test files, tests that name a changed script's class or path, tests/quick_neighbours.txt), and one smoke. Target <= 10
# min on builder0. `make check` stays the gate for any hash named for merge (verification.md). QUICK_BASE= (default the
# merge-base with main), QUICK_FILES="a.gd b.gd" (instead of the diff), QUICK_FILTER= (the selection already made:
# builder0 has no .git, so `make quick-remote` selects HERE and runs `quick` THERE with it; "-" = none touched).
.PHONY: quick quick-remote
quick: import ## Round 29 (I2): the native build (as check's stage) + lint + the tests a diff touches + combat-smoke (an iteration gate; make check stays the merge gate)
	@started=$$(date +%s); \
	if [ -n "$(QUICK_FILTER)" ]; then filter='$(QUICK_FILTER)'; [ "$$filter" != - ] || filter=""; \
	elif git rev-parse --git-dir > /dev/null 2>&1; then filter=$$(QUICK_BASE='$(QUICK_BASE)' QUICK_FILES='$(QUICK_FILES)' tools/quick_tests.sh); \
	else echo "quick: no git here (builder0's copy has none): use make quick-remote, or pass QUICK_FILTER"; exit 2; fi; \
	echo ">> quick on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | tests: $${filter:-none touched}"; \
	$(MAKE) --no-print-directory native-for-check || { echo "quick FAILED: the native build"; exit 1; }; \
	$(MAKE) --no-print-directory lint || { echo "quick FAILED: lint"; exit 1; }; \
	if [ -n "$$filter" ]; then $(MAKE) --no-print-directory test "FILTER=$$filter" || { echo "quick FAILED: test"; exit 1; }; \
	else echo "quick: the diff touches no test (lint and the smoke only)"; fi; \
	$(MAKE) --no-print-directory combat-smoke || { echo "quick FAILED: combat-smoke"; exit 1; }; \
	echo ">> quick passed in $$(( $$(date +%s) - started )) s (an iteration gate, not a merge gate: make check names hashes)"

# I2 on builder0 (C29.7: Godot runs there): the selection is made here, where the diff is, and passed over.
quick-remote: ## Round 29 (I2): make quick on builder0, the tests selected from this checkout's diff
	@filter=$$(QUICK_BASE='$(QUICK_BASE)' QUICK_FILES='$(QUICK_FILES)' tools/quick_tests.sh); \
	echo ">> quick-remote: $${filter:-no test touched}"; \
	tools/remote.sh quick "QUICK_FILTER=$${filter:--}"
