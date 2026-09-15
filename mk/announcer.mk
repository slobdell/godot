# The arena announcer: match-event fixtures, the line library, the director, transcripts, and the audio pipeline
# Owner: announcer (_agents/streams/announcer.md). Included by the root Makefile.
# No target here calls ElevenLabs unless you run announcer-generate without DRY_RUN=1 (lead gate: text approved first).

.PHONY: announcer-fixtures announcer-validate announcer-pytest announcer-check

ANNOUNCER_FIXTURES := tests/announcer/fixtures

announcer-fixtures: ## Regenerate the seeded fake-match fixtures (K5 event timelines) in tests/announcer/fixtures
	$(PYTHON) tools/announcer/fake_match.py --all --seed 1 --out $(ANNOUNCER_FIXTURES)

announcer-validate: ## Check every announcer fixture against the K5 event contract
	$(PYTHON) tools/announcer/events.py $(ANNOUNCER_FIXTURES)/*.jsonl

announcer-pytest: ## The announcer's Python tests (contract, generator, pipeline with a mock ElevenLabs client)
	$(PYTHON) -m unittest discover -s tools/announcer -p 'test_*.py'

announcer-check: announcer-validate announcer-pytest ## Everything the announcer verifies headless (in make check)
