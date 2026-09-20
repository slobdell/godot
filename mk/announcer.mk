# The arena announcer: match-event fixtures, the line library, the director, transcripts, and the audio pipeline
# Owner: announcer (_agents/streams/archive/round3/announcer.md). Included by the root Makefile.
# No target here calls ElevenLabs except announcer-generate APPROVED=1 (lead gate 2: the text is approved first).

.PHONY: announcer-fixtures announcer-validate announcer-pytest announcer-audit announcer-variance announcer-transcript announcer-transcripts announcer-demo announcer-demo-audio announcer-generate \
        announcer-transcripts-check announcer-record-smoke announcer-shots announcer-check

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

## X1: the lead heard the PA open the same way in several matches. This replays every fixture as MATCHES
## consecutive broadcasts and fails when the booth repeats itself too much across them.
## Short names override on the command line: make announcer-variance MATCHES=200 WINDOW=5 HISTORY=off.
## WINDOW must come from `origin`: GNU make defines WINDOW = 2 itself, so $(or $(WINDOW),5) is silently 2 and the
## audit compares each match only with the one before it (orientation trip-up 67).
ANNOUNCER_MATCHES ?= $(or $(MATCHES),50)
ANNOUNCER_WINDOW ?= $(if $(filter command line,$(origin WINDOW)),$(WINDOW),5)
ANNOUNCER_HISTORY ?= $(or $(HISTORY),on)
## Ceilings (fractions): a line said twice in one match is always a bug; an opener heard again within five
## matches should be rare (the brief's "~10%"); some carryover is unavoidable (the result and sign-off).
ANNOUNCER_MAX_OPENER ?= 0.10
ANNOUNCER_MAX_WELCOME ?= 0.10
ANNOUNCER_MAX_CARRYOVER ?= 0.30

announcer-variance: import ## How much the booth repeats itself across matches: MATCHES=50 WINDOW=5 HISTORY=on HOT=15
	@mkdir -p $(BUILD_DIR)/announcer
	@$(ANNOUNCER_CLI) --variance=res://$(ANNOUNCER_FIXTURES) --matches=$(ANNOUNCER_MATCHES) \
		--window=$(ANNOUNCER_WINDOW) --history=$(ANNOUNCER_HISTORY) --hot=$(or $(HOT),15) 2>&1 \
		| grep -vE '^(Godot Engine|--- Debug|OpenGL|Vulkan)' | tee $(BUILD_DIR)/announcer/variance.txt
	@grep -q 'ANNOUNCER_CLI_EXIT=0' $(BUILD_DIR)/announcer/variance.txt || { echo "announcer-variance FAILED"; exit 1; }
	@$(PYTHON) tools/announcer/check_variance.py $(BUILD_DIR)/announcer/variance.txt \
		--max-opener $(ANNOUNCER_MAX_OPENER) --max-welcome $(ANNOUNCER_MAX_WELCOME) \
		--max-carryover $(ANNOUNCER_MAX_CARRYOVER)

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

announcer-demo: import ## Build the Arena Booth Monitor page (every fixture, seeds 1-3; FIXTURE=name for one): build/announcer/demo/index.html
	@rm -rf $(BUILD_DIR)/announcer/demo/data && mkdir -p $(BUILD_DIR)/announcer/demo/data
	@$(ANNOUNCER_CLI) --all=res://$(ANNOUNCER_FIXTURES) --seeds=1,2,3 --out-dir=$(BUILD_DIR)/announcer/demo/data 2>&1 \
		| grep -E 'ANNOUNCER_CLI_EXIT=0' >/dev/null || { echo "announcer CLI failed"; exit 1; }
	@rm -f $(BUILD_DIR)/announcer/demo/data/*.txt
	$(PYTHON) tools/announcer/demo_page.py --data $(BUILD_DIR)/announcer/demo/data --out $(BUILD_DIR)/announcer/demo/index.html \
		$(if $(filter command line,$(origin FIXTURE)),--fixture $(FIXTURE))

## Real generation needs APPROVED=1 (lead gate 2: the lead has approved the text). The default is the dry run.
announcer-generate: ## Voice clips from lines.json: DRY_RUN=1 (default) prints requests and credits; APPROVED=1 calls ElevenLabs (key: ELEVENLABS_KEY_ID)
	@if [ "$(APPROVED)" = "1" ]; then \
		$(PYTHON) -c "import elevenlabs" 2>/dev/null || { echo "pip install elevenlabs==2.24.0 first (tools/announcer/requirements.txt)"; exit 1; }; \
		$(PYTHON) tools/announcer/generate.py --lead-approved $(if $(SPEAKERS),--speakers $(SPEAKERS)) $(if $(ONLY),--only $(ONLY)); \
	else \
		$(PYTHON) tools/announcer/generate.py --dry-run $(if $(SPEAKERS),--speakers $(SPEAKERS)) $(if $(ONLY),--only $(ONLY)); \
		echo; echo "(dry run: nothing was sent. The lead approves the text before APPROVED=1.)"; \
	fi

# Seed 1 of each fixture is re-called with the recorded clip durations, so voicing the lines it picks can change
# what it picks: loop until every line it uses has clips (a few passes).
ANNOUNCER_MOCK := $(BUILD_DIR)/announcer/mock
## Which clips the page plays. The default mock-voices whatever is missing (free, tone bursts); point it at the
## real pack to hear the actual broadcast: make announcer-demo-audio CLIPS=assets/announcer/clips
ANNOUNCER_DEMO_CLIPS ?= $(or $(CLIPS),$(ANNOUNCER_MOCK))

announcer-demo-audio: announcer-demo ## The Booth Monitor with audio: CLIPS=assets/announcer/clips for the real voices (default: free mock tones)
	@for pass in 1 2 3 4 5; do \
		$(ANNOUNCER_CLI) --all=res://$(ANNOUNCER_FIXTURES) --seeds=1 --manifest=$(CURDIR)/$(ANNOUNCER_DEMO_CLIPS)/manifest.json \
			--out-dir=$(BUILD_DIR)/announcer/demo/data 2>&1 | grep -q 'ANNOUNCER_CLI_EXIT=0' || { echo "announcer CLI failed"; exit 1; }; \
		missing=$$($(PYTHON) tools/announcer/mixdown.py --missing-lines $(ANNOUNCER_DEMO_CLIPS)/manifest.json $(BUILD_DIR)/announcer/demo/data/*_seed1.json); \
		[ -z "$$missing" ] && break; \
		if [ "$(ANNOUNCER_DEMO_CLIPS)" != "$(ANNOUNCER_MOCK)" ]; then \
			echo "the real pack is missing $$(echo $$missing | tr ',' '\n' | wc -l) lines the director wants; run make announcer-generate APPROVED=1"; exit 1; \
		fi; \
		echo "pass $$pass: mock-voicing $$(echo $$missing | tr ',' '\n' | wc -l) lines"; \
		$(PYTHON) tools/announcer/generate.py --mock --out $(ANNOUNCER_MOCK) --only "$$missing" | tail -1; \
	done
	@rm -f $(BUILD_DIR)/announcer/demo/data/*.txt
	$(PYTHON) tools/announcer/mixdown.py --manifest $(ANNOUNCER_DEMO_CLIPS)/manifest.json --match $(BUILD_DIR)/announcer/demo/data/*_seed1.json
	$(PYTHON) tools/announcer/demo_page.py --data $(BUILD_DIR)/announcer/demo/data --out $(BUILD_DIR)/announcer/demo/index.html

# The sim-baseline match (mk/core.mk) again, with the booth recording K5 events: the hash must not move (the announcer
# never touches gameplay) and the recorded real-match timeline must pass both validators and read as a broadcast.
## Round 6 (combat's report): the "did the booth change the simulation" question is differential, so it is answered
## against a control run of the same match without the booth, not against the shared baseline file, which moves on
## purpose whenever the simulation changes and then accused the booth of breaking it.
## **VERIFIED BY EXPERIMENT, round 9 (feel), because a lesson said otherwise for two rounds.** orchestration lesson
## 65 and feel's round-9 brief both still described this target as asking the ABSOLUTE question against the shared
## baseline file. It does not, and has not since round 6. Proved both ways on the laptop, 2026-09-20:
##   * with a DELIBERATELY STALE baseline line for this machine's glibc, `sim-baseline` goes red (so the file is
##     live here) and this target still PASSES -- it never opens the file;
##   * with the instrumented run's seed skewed so the two hashes must differ, this target FAILS and names the
##     subsystem -- so the comparison is live and can go red, not merely silent.
## A guard nobody has seen fail is not known to work (Invariant 0), which is why both halves were run.
announcer-record-smoke: import ## A real headless match with the announcer recording: same sim hash, valid K5 events, a transcript
	@mkdir -p $(BUILD_DIR)/announcer
	@expected=$$($(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination \
		--green-doctrine=res://doctrines/anvil_hammer.json --rust-doctrine=res://doctrines/individuals.json \
		--time-limit=40 --seed=3 2>/dev/null | grep MATCH_RESULT | $(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"); \
	$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination \
		--green-doctrine=res://doctrines/anvil_hammer.json --rust-doctrine=res://doctrines/individuals.json \
		--time-limit=40 --seed=3 --announcer-record=$(CURDIR)/$(BUILD_DIR)/announcer/recorded.jsonl 2>/dev/null \
		> $(BUILD_DIR)/announcer/record-smoke.log; \
	grep -q 'ANNOUNCER_RECORDED .* problems=0' $(BUILD_DIR)/announcer/record-smoke.log || { grep ANNOUNCER $(BUILD_DIR)/announcer/record-smoke.log; echo "announcer-record-smoke FAILED: no valid recording"; exit 1; }; \
	actual=$$(grep MATCH_RESULT $(BUILD_DIR)/announcer/record-smoke.log | $(PYTHON) -c "import json,sys; print(json.loads(sys.stdin.read().split('MATCH_RESULT ')[1])['state_hash'])"); \
	if [ -z "$$expected" ] || [ "$$actual" != "$$expected" ]; then echo "announcer-record-smoke FAILED: the booth changed the simulation ($$actual, without it $$expected)"; exit 1; fi; \
	$(PYTHON) tools/announcer/events.py $(BUILD_DIR)/announcer/recorded.jsonl; \
	$(ANNOUNCER_CLI) --fixture=$(CURDIR)/$(BUILD_DIR)/announcer/recorded.jsonl --seed=1 --out=$(BUILD_DIR)/announcer/recorded 2>&1 | grep -q 'ANNOUNCER_CLI_EXIT=0'; \
	echo "announcer-record-smoke passed: hash $$actual ($${expected:+matches the same match without the booth}), $$(wc -l < $(BUILD_DIR)/announcer/recorded.jsonl) events, $$(grep -c '^[0-9]:[0-9.]*   [A-Z]' $(BUILD_DIR)/announcer/recorded.txt) lines in build/announcer/recorded.txt"

announcer-shots: import ## A scripted skirmish with the announcer's subtitles, desktop and phone aspect (needs a display): build/screenshots/announcer_*.png
	mkdir -p $(BUILD_DIR)/screenshots $(BUILD_DIR)/announcer
	$(GODOT) --path . --resolution 1920x1080 -- --skirmish --scripted --enemy=$(ENEMY) --announcer=text --announcer-seed=2 \
		--screenshot-delay=$(or $(DELAY),24) --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/announcer_desktop.png 2>&1 \
		| tee $(BUILD_DIR)/announcer/shots.log | grep -E 'HUD_MESSAGE \[info\] (CALLER|VETERAN|PA):' || true
	$(GODOT) --path . --resolution 1200x540 -- --skirmish --scripted --enemy=$(ENEMY) --announcer=text --announcer-seed=2 \
		--screenshot-delay=$(or $(DELAY),24) --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/announcer_phone.png >/dev/null 2>&1

announcer-check: announcer-validate announcer-pytest announcer-audit announcer-variance announcer-transcripts-check announcer-record-smoke ## Everything the announcer verifies headless (in make check)
