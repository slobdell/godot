# Tank Squad — project Makefile
#
# This file is the single source of truth for "what does a machine need, and
# how do I do X". A fresh clone needs exactly one setup step:
#
#     make bootstrap
#
# which downloads a PINNED Godot editor plus only the export templates we use
# into ./.tools (Godot "self-contained mode" — nothing is written to ~/.local or
# ~/.config). Run `make help` for everything else. The reasoning behind each
# choice lives in _agents/bootstrap.md.

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# ---- Pinned toolchain ---------------------------------------------------------
# To upgrade Godot: change GODOT_VERSION, run `make bootstrap`, run `make test`.
GODOT_VERSION  := 4.7.2
GODOT_FLAVOR   := stable
GODOT_TAG      := $(GODOT_VERSION)-$(GODOT_FLAVOR)
GODOT_PLATFORM := linux.x86_64

TOOLS_DIR      := .tools
DOWNLOADS      := $(TOOLS_DIR)/downloads
GODOT_HOME     := $(TOOLS_DIR)/godot-$(GODOT_TAG)
GODOT          := $(GODOT_HOME)/Godot_v$(GODOT_TAG)_$(GODOT_PLATFORM)
# Self-contained mode keeps editor data (incl. export templates) beside the binary.
TEMPLATES_DIR  := $(GODOT_HOME)/editor_data/export_templates/$(GODOT_VERSION).$(GODOT_FLAVOR)
TEMPLATES_OK   := $(TEMPLATES_DIR)/.installed
RELEASE_URL    := https://github.com/godotengine/godot/releases/download/$(GODOT_TAG)

EDITOR_ZIP     := Godot_v$(GODOT_TAG)_$(GODOT_PLATFORM).zip
TEMPLATES_TPZ  := Godot_v$(GODOT_TAG)_export_templates.tpz
# The .tpz is ~1.3 GB and covers every platform. We extract only what we export
# with: single-threaded web (no COOP/COEP headers needed) + the Linux server.
TEMPLATE_FILES := web_nothreads_debug.zip web_nothreads_release.zip \
                  linux_debug.x86_64 linux_release.x86_64 version.txt

BUILD_DIR      := build
WEB_PORT       ?= 8060
WEB_HOST       ?= 127.0.0.1
NET_PORT       ?= 9080
SMOKE_PORT     ?= 8061
SMOKE_NET_PORT ?= 9181
NET_SMOKE_EXPECT ?= 2
BOTS           ?= 0
AGENT_PORT     ?= 8765
GREEN          ?= 1
RUST           ?= 1
SCORE          ?= 5
TIME           ?= 300
SEED           ?= 1
ENEMY          ?= individuals
GREEN_DOCTRINE ?= anvil_hammer
RUST_DOCTRINE  ?= individuals
N              ?= 10
JOBS           ?= 4
PYTHON         ?= python3
NODE           ?= node
NPM            ?= npm
CHROME         ?= /usr/bin/google-chrome
WEB_SMOKE_DIR  := tools/web_smoke
WEB_SMOKE_DEPS := $(WEB_SMOKE_DIR)/node_modules/.package-lock.json

.PHONY: help bootstrap doctor import lint check check-all editor run skirmish demo test screenshot \
        match matches match-smoke determinism watch-match server client net-smoke combat-smoke agent-client agent-client-windowed agent-offline \
        export-web serve-web play web-smoke web-net-smoke export-server clean distclean

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

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

# ---- Verification bundles (see _agents/verification.md) ------------------------

check: lint test net-smoke combat-smoke match-smoke determinism ## Everything headless: tests + network + combat + match runner (no display/browser)

check-all: check screenshot web-smoke web-net-smoke export-server ## check + desktop render + browser checks + server export
	timeout 20 $(BUILD_DIR)/server/tank_squad_server.x86_64 --headless --quit-after 150 -- --server=$(SMOKE_NET_PORT) --bots=2 2>&1 \
		| tee $(BUILD_DIR)/export-server-check.log | grep -E 'LISTENING|READY'
	! grep -E 'ERROR' $(BUILD_DIR)/export-server-check.log
	@echo "check-all passed. Now LOOK at build/screenshots/*.png"

# ---- Day-to-day ---------------------------------------------------------------

editor: $(GODOT) ## Open the Godot editor on this project
	$(GODOT) --path . --editor

run: import ## Play offline vs BOTS server bots (default 1): WASD/arrows drive, mouse aims, click fires
	$(GODOT) --path . -- --bots=$(or $(filter-out 0,$(BOTS)),1)

skirmish: import ## Command your squads on the tactical map vs a CPU doctrine (ENEMY=individuals|anvil_hammer|flame_rush)
	$(GODOT) --path . -- --skirmish --enemy=$(ENEMY)

demo: import ## Play with a scripted driver instead of the keyboard
	$(GODOT) --path . -- --demo

lint: import ## Parse-check every GDScript file; prints only errors (fast way to find compile errors)
	@status=0; for f in $$(git ls-files -co --exclude-standard '*.gd'); do \
		out=$$($(GODOT) --headless --path . --check-only --script "res://$$f" 2>&1 | grep -E 'Parse Error|SCRIPT ERROR' | grep -v 'depended scripts' || true); \
		if [ -n "$$out" ]; then echo "$$f: $$out"; status=1; fi; \
	done; \
	if [ $$status -eq 0 ]; then echo "lint: all scripts parse"; fi; exit $$status

test: import ## Run the headless test suite (FILTER=substring to run a subset)
	$(GODOT) --headless --path . --script res://tests/run_tests.gd -- --filter=$(FILTER)

screenshot: import ## Render the demo and save build/screenshots/demo.png (needs a display)
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --path . -- --demo --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/demo.png

# ---- Multiplayer --------------------------------------------------------------
# Browser clients: `make play` (or `make server` + `make serve-web`), then open
# http://localhost:8060/?connect in as many tabs as you like. The page's /ws path is
# proxied to the game server, so only ONE port is involved. Across the LAN:
# `make play WEB_HOST=0.0.0.0` and open http://<this-ip>:8060/?connect

server: import ## Run a headless game server on ws://0.0.0.0:9080 (NET_PORT=..., BOTS=N adds server bots)
	$(GODOT) --headless --path . -- --server=$(NET_PORT) --bots=$(BOTS)

client: import ## Play as a desktop client of ws://127.0.0.1:9080 (NET_PORT=...)
	$(GODOT) --path . -- --connect=ws://127.0.0.1:$(NET_PORT)

net-smoke: import ## Headless server + 2 headless bot clients over real WebSockets
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . -- --server=$(SMOKE_NET_PORT) > $(BUILD_DIR)/net-smoke-server.log 2>&1 & server=$$!; \
	trap 'kill $$server 2>/dev/null' EXIT; \
	pids=""; for i in 1 2; do \
		$(GODOT) --headless --path . --script res://tests/net/bot_client_check.gd -- \
			--connect=ws://127.0.0.1:$(SMOKE_NET_PORT) --demo --expect-tanks=$(NET_SMOKE_EXPECT) 2>&1 | grep -E 'NET_CHECK|ERROR|SCRIPT ERROR' & \
		pids="$$pids $$!"; \
	done; \
	status=0; for pid in $$pids; do wait $$pid || status=1; done; \
	grep -E 'ERROR' $(BUILD_DIR)/net-smoke-server.log && status=1; \
	exit $$status

# ---- Agent bridge (Claude plays a tank; see _agents/agent_bridge.md) ----------------

agent-client: import ## Headless client of the local server, commanded via tools/agent.py on port 8765 (AGENT_PORT=...)
	$(GODOT) --headless --path . -- --connect=ws://127.0.0.1:$(NET_PORT) --agent-port=$(AGENT_PORT)

agent-client-windowed: import ## Same, but in a window so /screenshot works and you can watch
	$(GODOT) --path . -- --connect=ws://127.0.0.1:$(NET_PORT) --agent-port=$(AGENT_PORT)

agent-offline: import ## Headless offline match (BOTS, default 1) with the agent commanding the player tank
	$(GODOT) --headless --path . -- --agent-port=$(AGENT_PORT) --bots=$(or $(filter-out 0,$(BOTS)),1)

combat-smoke: import ## Headless server with a bot + a stationary bot client that must take damage
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . -- --server=$(SMOKE_NET_PORT) --bots=1 > $(BUILD_DIR)/combat-smoke-server.log 2>&1 & server=$$!; \
	trap 'kill $$server 2>/dev/null' EXIT; \
	$(GODOT) --headless --path . --script res://tests/net/bot_client_check.gd -- \
		--connect=ws://127.0.0.1:$(SMOKE_NET_PORT) --expect-tanks=2 --min-travel=0 --expect-damage --timeout=60 \
		2>&1 | grep -E 'NET_CHECK|ERROR'; \
	status=$$?; grep -E 'destroyed' $(BUILD_DIR)/combat-smoke-server.log || true; \
	grep -E 'ERROR' $(BUILD_DIR)/combat-smoke-server.log && status=1; \
	exit $$status

# ---- Match runner (headless bots vs bots, faster than real time) ----------------
# --fixed-fps 60 makes every frame advance exactly 1/60 s of game time without
# waiting for the wall clock, so matches run as fast as the CPU allows.

match: import ## One headless match: GREEN=1 RUST=1 SCORE=5 TIME=300 SEED=1; prints MATCH_RESULT JSON
	$(GODOT) --headless --fixed-fps 60 --path . -- --match --green=$(GREEN) --rust=$(RUST) \
		--score-limit=$(SCORE) --time-limit=$(TIME) --seed=$(SEED) | grep MATCH_RESULT

matches: import ## N seeded matches in parallel with a win-rate summary (N=10 JOBS=4, same knobs as match)
	$(PYTHON) tools/match_series.py --godot $(GODOT) --runs $(N) --jobs $(JOBS) --green $(GREEN) \
		--rust $(RUST) --score-limit $(SCORE) --time-limit $(TIME) --json $(BUILD_DIR)/matches.json

determinism: import ## Same seed + same doctrines twice → byte-identical match results (experiment T0)
	mkdir -p $(BUILD_DIR)
	for run in 1 2; do \
		$(GODOT) --headless --fixed-fps 60 --path . -- --match --green-doctrine=res://doctrines/anvil_hammer.json \
			--rust-doctrine=res://doctrines/flame_rush.json --score-limit=8 --time-limit=150 --seed=11 2>/dev/null \
			| grep MATCH_RESULT | $(PYTHON) -c "import json,sys; r=json.loads(sys.stdin.read().split('MATCH_RESULT ')[1]); [r.pop(k) for k in ('real_seconds','speedup')]; print(json.dumps(r, sort_keys=True))" \
			> $(BUILD_DIR)/determinism_$$run.json; \
	done
	cmp $(BUILD_DIR)/determinism_1.json $(BUILD_DIR)/determinism_2.json
	@echo "determinism passed: $$(cat $(BUILD_DIR)/determinism_1.json | cut -c1-120)..."

watch-match: import ## Watch a doctrine match from above in a window (GREEN_DOCTRINE, RUST_DOCTRINE, SEED)
	$(GODOT) --path . -- --match --green-doctrine=res://doctrines/$(GREEN_DOCTRINE).json \
		--rust-doctrine=res://doctrines/$(RUST_DOCTRINE).json --score-limit=$(SCORE) --time-limit=$(TIME) --seed=$(SEED)

match-smoke: import ## A short 2v2 match must finish with a result, faster than real time
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --fixed-fps 60 --path . -- --match --green=2 --rust=2 --score-limit=3 --time-limit=120 --seed=7 \
		2>&1 | tee $(BUILD_DIR)/match-smoke.log | grep MATCH_RESULT
	! grep -E 'ERROR' $(BUILD_DIR)/match-smoke.log
	$(PYTHON) -c "import json,sys; r=json.loads(open('$(BUILD_DIR)/match-smoke.log').read().split('MATCH_RESULT ')[1].splitlines()[0]); \
		assert r['speedup'] > 2, r; assert sum(r['stats']['shots']) > 0, r; print('match-smoke passed:', r['winner'], r['score'], f\"{r['speedup']}x\")"

# ---- Exports ------------------------------------------------------------------

export-web: import $(TEMPLATES_OK) ## Export the WebAssembly build to build/web
	mkdir -p $(BUILD_DIR)/web
	$(GODOT) --headless --path . --export-release "Web" $(BUILD_DIR)/web/index.html

serve-web: export-web ## Serve the web build at http://localhost:8060 (?connect joins the local server via /ws; ?demo)
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(WEB_PORT) $(WEB_HOST) $(NET_PORT)

play: export-web ## One command: game server (BOTS=N) + web page. Open http://localhost:8060/?connect
	$(GODOT) --headless --path . -- --server=$(NET_PORT) --bots=$(BOTS) > $(BUILD_DIR)/play-server.log 2>&1 & server=$$!; \
	trap 'kill $$server 2>/dev/null' EXIT; \
	echo "game server log: $(BUILD_DIR)/play-server.log"; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(WEB_PORT) $(WEB_HOST) $(NET_PORT)

web-smoke: export-web $(WEB_SMOKE_DEPS) ## Boot the web export in headless Chrome, screenshot it, fail on errors
	mkdir -p $(BUILD_DIR)/screenshots
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 >/dev/null 2>&1 & server=$$!; \
	trap 'kill $$server' EXIT; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs "http://127.0.0.1:$(SMOKE_PORT)/?demo" $(BUILD_DIR)/screenshots/web.png

# The browser client stands still; a server bot drives over from the far base and
# attacks it, so the screenshot shows a REMOTE tank, shells, and damage rendered in
# the browser. Settle time is tuned so the bot has arrived (~8 s).
web-net-smoke: export-web $(WEB_SMOKE_DEPS) ## Browser client (via the /ws proxy) vs a server bot; screenshot mid-fight
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --headless --path . -- --server=$(SMOKE_NET_PORT) --bots=1 > $(BUILD_DIR)/web-net-smoke-server.log 2>&1 & server=$$!; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 $(SMOKE_NET_PORT) >/dev/null 2>&1 & web=$$!; \
	trap 'kill $$server $$web 2>/dev/null' EXIT; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs \
		"http://127.0.0.1:$(SMOKE_PORT)/?connect" \
		$(BUILD_DIR)/screenshots/web-net.png 8 TANK_SQUAD_SPAWNED; \
	! grep -E 'ERROR' $(BUILD_DIR)/web-net-smoke-server.log

$(WEB_SMOKE_DEPS): $(WEB_SMOKE_DIR)/package.json
	cd $(WEB_SMOKE_DIR) && $(NPM) install --no-audit --no-fund
	touch $@

export-server: import $(TEMPLATES_OK) ## Export the headless Linux server binary to build/server
	mkdir -p $(BUILD_DIR)/server
	$(GODOT) --headless --path . --export-release "Linux Server" $(BUILD_DIR)/server/tank_squad_server.x86_64

# ---- Cleanup ------------------------------------------------------------------

clean: ## Remove build outputs and Godot's import cache
	rm -rf $(BUILD_DIR) .godot

distclean: clean ## Also remove the downloaded toolchain
	rm -rf $(TOOLS_DIR)
