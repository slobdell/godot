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
	if [ -n "$(QUICK_LINT)" ]; then lintset='$(QUICK_LINT)'; \
	elif git rev-parse --git-dir > /dev/null 2>&1; then lintset=$$(QUICK_BASE='$(QUICK_BASE)' QUICK_FILES='$(QUICK_FILES)' tools/quick_tests.sh --lint | paste -sd,); \
	else lintset=all; fi; \
	if [ "$$lintset" = all ]; then $(MAKE) --no-print-directory lint || { echo "quick FAILED: lint"; exit 1; }; \
	else $(MAKE) --no-print-directory quick-lint "QUICK_LINT=$${lintset:--}" || { echo "quick FAILED: lint"; exit 1; }; fi; \
	if [ -n "$$filter" ]; then $(MAKE) --no-print-directory test "FILTER=$$filter" || { echo "quick FAILED: test"; exit 1; }; \
	else echo "quick: the diff touches no test (lint and the smoke only)"; fi; \
	$(MAKE) --no-print-directory combat-smoke || { echo "quick FAILED: combat-smoke"; exit 1; }; \
	echo ">> quick passed in $$(( $$(date +%s) - started )) s (an iteration gate, not a merge gate: make check names hashes)"

# I2 on builder0 (C29.7: Godot runs there): the selection is made here, where the diff is, and passed over.
quick-remote: ## Round 29 (I2): make quick on builder0, the tests selected from this checkout's diff
	@filter=$$(QUICK_BASE='$(QUICK_BASE)' QUICK_FILES='$(QUICK_FILES)' tools/quick_tests.sh); \
	echo ">> quick-remote: $${filter:-no test touched}"; \
	lintset=$$(QUICK_BASE='$(QUICK_BASE)' QUICK_FILES='$(QUICK_FILES)' tools/quick_tests.sh --lint | paste -sd,); \
	echo ">> quick-remote: lint $$(printf '%s' "$$lintset" | tr ',' '\n' | grep -c . || true) scripts the diff touches or that name them"; \
	tools/remote.sh quick "QUICK_FILTER=$${filter:--}" "QUICK_LINT=$${lintset:--}"

# Round 30 (I2's timing: a full lint was 12 of quick's 21 min on builder0, one Godot boot per script). quick's lint: the
# scripts in QUICK_LINT (comma-separated; "-" = none; tools/quick_tests.sh --lint: the changed scripts and every script
# naming them) parse-checked as `make lint` does, its self-test included, failing on a finding not in LINT_BASELINE.
# `make check`'s full lint stays the merge gate.
.PHONY: quick-lint
quick-lint: import ## Round 30 (I2): parse-check only QUICK_LINT's scripts (the diff's and their dependents'), as make lint does
	@mkdir -p $(BUILD_DIR)/lint-selftest; selftest=$(BUILD_DIR)/lint-selftest/type_inference_probe.gd; \
	cp tests/fixtures/ternary_infer_probe.gd.txt "$$selftest"; \
	files=$$(printf '%s' '$(QUICK_LINT)' | tr ',' '\n' | grep -v '^-$$' | grep . || true); \
	count=$$(printf '%s\n' "$$files" | grep -c . || true); \
	printf '%s\n' $$files "$$selftest" | grep . | \
		xargs -P $(LINT_JOBS) -I{} sh -c \
			'raw=$$($(GODOT) --headless --path . --check-only --script "res://$$1" 2>&1); rc=$$?; \
			out=$$(printf "%s\n" "$$raw" | grep -E "Parse Error|SCRIPT ERROR" | grep -v "depended scripts" || true); \
			if [ -n "$$out" ]; then printf "%s\n" "$$out" | sed "s|^|$$1: |"; \
			elif [ -z "$$(printf "%s" "$$raw" | tr -d "[:space:]")" ]; then \
				printf "%s: CHECKER PRODUCED NO OUTPUT AT ALL (exit %s) -- not a pass\n" "$$1" "$$rc"; \
			elif [ "$$rc" -ge 128 ]; then \
				printf "%s: CHECKER KILLED BY SIGNAL %s (exit %s) -- not a pass\n" "$$1" "$$(( rc - 128 ))" "$$rc"; \
			fi' _ {} \
		| sort > $(BUILD_DIR)/quick-lint.raw; \
	grep -q "type_inference_probe.gd:" $(BUILD_DIR)/quick-lint.raw \
		|| { echo "quick-lint FAILED: the checker did not report the deliberately broken self-test file (see make lint)"; exit 1; }; \
	grep -v "type_inference_probe.gd:" $(BUILD_DIR)/quick-lint.raw > $(BUILD_DIR)/quick-lint.out || true; \
	sort $(LINT_BASELINE) 2>/dev/null | grep -v '^#' | grep -v '^$$' > $(BUILD_DIR)/quick-lint.expected || true; \
	new=$$(comm -23 $(BUILD_DIR)/quick-lint.out $(BUILD_DIR)/quick-lint.expected); \
	if [ -n "$$new" ]; then echo "quick-lint FAILED over $$count scripts -- findings NOT in $(LINT_BASELINE):"; \
		printf '%s\n' "$$new" | sed 's/^/  /'; exit 1; fi; \
	echo "quick-lint: $$count scripts parse (the diff's and those naming them; self-test seen; make check lints all)"
