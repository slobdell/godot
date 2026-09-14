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
	$(GODOT) --headless --path . --import

lint: import ## Parse-check every GDScript file; prints only errors (fast way to find compile errors)
	@status=0; for f in $$(git ls-files -co --exclude-standard '*.gd'); do \
		out=$$($(GODOT) --headless --path . --check-only --script "res://$$f" 2>&1 | grep -E 'Parse Error|SCRIPT ERROR' | grep -v 'depended scripts' || true); \
		if [ -n "$$out" ]; then echo "$$f: $$out"; status=1; fi; \
	done; \
	if [ $$status -eq 0 ]; then echo "lint: all scripts parse"; fi; exit $$status

test: import ## Run the headless test suite (FILTER=substring to run a subset)
	$(GODOT) --headless --path . --script res://tests/run_tests.gd -- --filter=$(FILTER)

# ---- Verification bundles (see _agents/verification.md) ------------------------

check: lint test net-smoke combat-smoke match-smoke determinism sim-baseline ## Everything headless: tests + network + combat + match runner (no display/browser)

check-all: check screenshot web-smoke web-net-smoke export-server ## check + desktop render + browser checks + server export
	timeout 20 $(BUILD_DIR)/server/tank_squad_server.x86_64 --headless --quit-after 150 -- --server=$(SMOKE_NET_PORT) --bots=2 2>&1 \
		| tee $(BUILD_DIR)/export-server-check.log | grep -E 'LISTENING|READY'
	! grep -E 'ERROR' $(BUILD_DIR)/export-server-check.log
	@echo "check-all passed. Now LOOK at build/screenshots/*.png"

# ---- Cleanup ------------------------------------------------------------------

clean: ## Remove build outputs and Godot's import cache
	rm -rf $(BUILD_DIR) .godot

distclean: clean ## Also remove the downloaded toolchain
	rm -rf $(TOOLS_DIR)

sim-baseline: import ## The simulation matches the recorded baseline hash (art must never change gameplay)
	@expected=$$(head -1 tests/baselines/sim_state_hash.txt); \
	actual=$$($(GODOT) --headless --fixed-fps 60 --path . -- --match --elimination \
		--green-doctrine=res://doctrines/anvil_hammer.json --rust-doctrine=res://doctrines/individuals.json \
		--time-limit=40 --seed=3 2>/dev/null | grep MATCH_RESULT | $(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"); \
	if [ "$$actual" = "$$expected" ]; then echo "sim-baseline passed: $$actual"; \
	else echo "sim-baseline FAILED: expected $$expected, got $$actual. If gameplay changed on purpose, update tests/baselines/sim_state_hash.txt"; exit 1; fi
