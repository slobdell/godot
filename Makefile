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
PYTHON         ?= python3
NODE           ?= node
NPM            ?= npm
CHROME         ?= /usr/bin/google-chrome
WEB_SMOKE_DIR  := tools/web_smoke
WEB_SMOKE_DEPS := $(WEB_SMOKE_DIR)/node_modules/.package-lock.json

.PHONY: help bootstrap doctor import editor run demo test screenshot \
        server client net-smoke \
        export-web serve-web web-smoke web-net-smoke export-server clean distclean

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

# ---- Day-to-day ---------------------------------------------------------------

editor: $(GODOT) ## Open the Godot editor on this project
	$(GODOT) --path . --editor

run: import ## Play the game (WASD/arrows drive, mouse aims)
	$(GODOT) --path .

demo: import ## Play with a scripted driver instead of the keyboard
	$(GODOT) --path . -- --demo

test: import ## Run the headless test suite
	$(GODOT) --headless --path . --script res://tests/run_tests.gd

screenshot: import ## Render the demo and save build/screenshots/demo.png (needs a display)
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --path . -- --demo --screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/demo.png

# ---- Multiplayer --------------------------------------------------------------
# Browser clients: `make server` in one terminal, `make serve-web` in another, then
# open http://localhost:8060/?connect in as many tabs as you like. To play across
# the LAN: `make serve-web WEB_HOST=0.0.0.0` and open http://<this-ip>:8060/?connect

server: import ## Run a headless game server on ws://0.0.0.0:$(NET_PORT)
	$(GODOT) --headless --path . -- --server=$(NET_PORT)

client: import ## Play as a desktop client of ws://127.0.0.1:$(NET_PORT)
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

# ---- Exports ------------------------------------------------------------------

export-web: import $(TEMPLATES_OK) ## Export the WebAssembly build to build/web
	mkdir -p $(BUILD_DIR)/web
	$(GODOT) --headless --path . --export-release "Web" $(BUILD_DIR)/web/index.html

serve-web: export-web ## Export, then serve build/web at http://localhost:8060 (add ?connect or ?demo)
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(WEB_PORT) $(WEB_HOST)

web-smoke: export-web $(WEB_SMOKE_DEPS) ## Boot the web export in headless Chrome, screenshot it, fail on errors
	mkdir -p $(BUILD_DIR)/screenshots
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) >/dev/null 2>&1 & server=$$!; \
	trap 'kill $$server' EXIT; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs "http://127.0.0.1:$(SMOKE_PORT)/?demo" $(BUILD_DIR)/screenshots/web.png

# Both tanks stand still so both are in frame: this checks that a REMOTE tank
# renders on a browser client. Movement over the network is net-smoke's job.
web-net-smoke: export-web $(WEB_SMOKE_DEPS) ## Browser client + bot client vs headless server; screenshot
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --headless --path . -- --server=$(SMOKE_NET_PORT) > $(BUILD_DIR)/web-net-smoke-server.log 2>&1 & server=$$!; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) >/dev/null 2>&1 & web=$$!; \
	$(GODOT) --headless --path . -- --connect=ws://127.0.0.1:$(SMOKE_NET_PORT) >/dev/null 2>&1 & bot=$$!; \
	trap 'kill $$server $$web $$bot 2>/dev/null' EXIT; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs \
		"http://127.0.0.1:$(SMOKE_PORT)/?connect=ws://127.0.0.1:$(SMOKE_NET_PORT)" \
		$(BUILD_DIR)/screenshots/web-net.png 5 TANK_SQUAD_SPAWNED

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
