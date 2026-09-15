# The arena announcer: match-event fixtures, the line library, the director, transcripts, and the audio pipeline
# Owner: announcer (_agents/streams/announcer.md). Included by the root Makefile.
# No target here calls ElevenLabs unless you run announcer-generate without DRY_RUN=1 (lead gate: text approved first).

.PHONY: announcer-fixtures announcer-validate announcer-pytest announcer-audit announcer-transcript announcer-transcripts \
        announcer-transcripts-check announcer-check

ANNOUNCER_FIXTURES := tests/announcer/fixtures
ANNOUNCER_CLI := $(GODOT) --headless --path . --script res://game/announcer/announcer_cli.gd --
## The transcripts checked in for the lead's review (lead gate 2): every fixture, these director seeds.
ANNOUNCER_REVIEW := assets/announcer/transcripts
ANNOUNCER_SEEDS ?= 1,2
FIXTURE ?= comeback
SEED ?= 1

announcer-fixtures: ## Regenerate the seeded fake-match fixtures (K5 event timelines) in tests/announcer/fixtures
	$(PYTHON) tools/announcer/fake_match.py --all --seed 1 --out $(ANNOUNCER_FIXTURES)

announcer-validate: ## Check every announcer fixture against the K5 event contract
	$(PYTHON) tools/announcer/events.py $(ANNOUNCER_FIXTURES)/*.jsonl

announcer-pytest: ## The announcer's Python tests (contract, generator, text audit, pipeline with a mock ElevenLabs client)
	$(PYTHON) -m unittest discover -s tools/announcer -p 'test_*.py'

announcer-audit: ## Audit the line library's text (symbols, slots, tags, duplicates, rejected tone)
	$(PYTHON) tools/announcer/audit_lines.py

announcer-transcript: import ## Print one match as the booth calls it: FIXTURE=comeback SEED=1 (no credits)
	@mkdir -p $(BUILD_DIR)/announcer/transcripts
	@$(ANNOUNCER_CLI) --fixture=res://$(ANNOUNCER_FIXTURES)/$(FIXTURE).jsonl --seed=$(SEED) \
		--out=$(BUILD_DIR)/announcer/transcripts/$(FIXTURE)_seed$(SEED) 2>&1 | grep -v '^Godot Engine' | grep -v ANNOUNCER_CLI_EXIT || true
	@cat $(BUILD_DIR)/announcer/transcripts/$(FIXTURE)_seed$(SEED).txt

announcer-transcripts: import ## Rewrite the review transcripts in assets/announcer/transcripts (every fixture, SEEDS 1,2)
	@rm -rf $(ANNOUNCER_REVIEW) && mkdir -p $(ANNOUNCER_REVIEW)
	$(ANNOUNCER_CLI) --all=res://$(ANNOUNCER_FIXTURES) --seeds=$(ANNOUNCER_SEEDS) --out-dir=$(ANNOUNCER_REVIEW) 2>&1 | grep -E 'wrote|ERROR|error' || true
	@rm -f $(ANNOUNCER_REVIEW)/*.json
	@ls $(ANNOUNCER_REVIEW)/*.txt | wc -l | xargs echo "review transcripts:"

announcer-transcripts-check: import ## The checked-in review transcripts match what the director says today
	@rm -rf $(BUILD_DIR)/announcer/fresh && mkdir -p $(BUILD_DIR)/announcer/fresh
	@$(ANNOUNCER_CLI) --all=res://$(ANNOUNCER_FIXTURES) --seeds=$(ANNOUNCER_SEEDS) --out-dir=$(BUILD_DIR)/announcer/fresh 2>&1 \
		| grep -E 'ANNOUNCER_CLI_EXIT=0' >/dev/null || { echo "announcer CLI failed"; exit 1; }
	@rm -f $(BUILD_DIR)/announcer/fresh/*.json
	@diff -r $(ANNOUNCER_REVIEW) $(BUILD_DIR)/announcer/fresh >/dev/null \
		|| { echo "review transcripts are stale: run make announcer-transcripts and commit"; diff -r $(ANNOUNCER_REVIEW) $(BUILD_DIR)/announcer/fresh | head -20; exit 1; }
	@echo "announcer transcripts current"

announcer-check: announcer-validate announcer-pytest announcer-audit announcer-transcripts-check ## Everything the announcer verifies headless (in make check)
