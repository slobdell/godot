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

# Targets live in mk/*.mk, one file per workstream area, so parallel branches rarely
# conflict here. Add new targets to your area's file (or a new mk/<area>.mk).
.PHONY: help bootstrap doctor import lint sim-baseline check check-all editor run skirmish demo test screenshot \
        match matches match-smoke determinism watch-match server client net-smoke combat-smoke agent-client agent-client-windowed agent-offline \
        export-web serve-web play web-smoke web-net-smoke export-server clean distclean

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

include mk/*.mk
