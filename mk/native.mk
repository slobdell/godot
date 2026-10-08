# Native code (round 23, stream native): the vehicle brain's hot loop in C++ through godot-cpp, behind
# BrainSwitches.native. How to build, the flags and why, the proof: _agents/native.md. Owner: native.
#
#   make native            build (godot-cpp once per machine under .tools/, then native/src) and switch it ON
#   make native NATIVE=off switch it OFF (the .gdextension is removed; the game runs its GDScript paths)
#   make native-info       what Godot loaded: NativeBridge.available and the library's build_info()
#   make native-proof      the equality proof on one match: plain = --brains-off=native = the 30-tick A/B (hashes)
#   make native-clean      this worktree's build and library (the machine's godot-cpp stays: make distclean)
#
# `make check` runs `native-for-check` before `import`: NATIVE=off, or a machine without cmake and a C++ compiler,
# runs the suite without the library (the web build's case); a BUILD FAILURE is a red check, never a silent OFF.

GODOTCPP_VERSION := 10.0.0-stable
GODOTCPP_SHA256  := ebbf64f0f8f8b8b66bc4bc4d3797db97f95b19cf0dfb5b3f8cf56683d9df7db4
GODOTCPP_URL     := https://github.com/godotengine/godot-cpp/archive/refs/tags/$(GODOTCPP_VERSION).tar.gz
GODOTCPP_SRC     := $(TOOLS_DIR)/godot-cpp-$(GODOTCPP_VERSION)
# The proof's flags (_agents/native.md): -O2, no FMA contraction, no fast math, no -march. Also the key of the
# machine's godot-cpp build tree, so a flag change (or a Godot upgrade) builds a fresh binding beside the old one.
NATIVE_FP_FLAGS  := -O2 -ffp-contract=off -fno-fast-math
GODOTCPP_BUILD   := $(GODOTCPP_SRC)/build-$(shell printf '%s' '$(NATIVE_FP_FLAGS) $(GODOT_TAG)' | sha256sum | cut -c1-8)
GODOTCPP_LIB     := $(GODOTCPP_BUILD)/bin/libgodot-cpp.linux.template_debug.x86_64.a
NATIVE_DIR       := native
NATIVE_BUILD     := $(NATIVE_DIR)/build
NATIVE_BIN       := $(NATIVE_DIR)/bin
NATIVE_SO        := $(NATIVE_BIN)/libtank_native.linux.x86_64.so
NATIVE_GDEXT     := $(NATIVE_BIN)/tank_squad.gdextension
NATIVE_JOBS      ?= $(shell nproc)
NATIVE_CPUS      ?=
NATIVE           ?= on
CMAKE            ?= cmake
NATIVE_TOOLCHAIN := $(shell command -v $(CMAKE) >/dev/null 2>&1 && command -v c++ >/dev/null 2>&1 && echo yes || echo no)
NATIVE_ENV := GODOT=$(GODOT) TOOLS_DIR=$(TOOLS_DIR) DOWNLOADS=$(DOWNLOADS) GODOTCPP_VERSION=$(GODOTCPP_VERSION) \
	GODOTCPP_SHA256=$(GODOTCPP_SHA256) GODOTCPP_URL=$(GODOTCPP_URL) GODOTCPP_SRC=$(GODOTCPP_SRC) \
	GODOTCPP_BUILD=$(GODOTCPP_BUILD) GODOTCPP_LIB=$(GODOTCPP_LIB) NATIVE_FP_FLAGS="$(NATIVE_FP_FLAGS)" \
	NATIVE_DIR=$(NATIVE_DIR) NATIVE_BUILD=$(NATIVE_BUILD) NATIVE_BIN=$(NATIVE_BIN) NATIVE_SO=$(NATIVE_SO) \
	NATIVE_GDEXT=$(NATIVE_GDEXT) NATIVE_JOBS=$(NATIVE_JOBS) NATIVE_CPUS=$(NATIVE_CPUS) CMAKE=$(CMAKE)

.PHONY: native native-off native-for-check native-info native-proof native-clean

native: $(GODOT) ## Build the native library (godot-cpp, once per machine, then native/src) into native/bin and switch it ON; NATIVE=off switches it OFF
	@if [ "$(NATIVE)" = off ]; then $(MAKE) --no-print-directory native-off; else $(NATIVE_ENV) $(NATIVE_DIR)/build.sh; fi

native-off: ## Switch the native library OFF: the game and the suite run the GDScript paths (the web build's case)
	@rm -f $(NATIVE_GDEXT) $(NATIVE_GDEXT).uid
	@# Godot's registry of loaded extensions is read by EVERY run before the editor's scan rewrites it, so the first
	@# run after the switch would print `ERROR: GDExtension dynamic library not found` (and the log gate is red on it).
	@if [ -e .godot/extension_list.cfg ]; then sed -i '\|native/bin/tank_squad.gdextension|d' .godot/extension_list.cfg; \
		[ -s .godot/extension_list.cfg ] || rm -f .godot/extension_list.cfg; fi
	@echo ">> native: OFF ($(NATIVE_GDEXT) removed; the GDScript paths run)"

# check's stage: OFF by choice or for want of a toolchain is fine and said; a failed build is red.
native-for-check:
	@if [ "$(NATIVE)" = off ]; then $(MAKE) --no-print-directory native-off; \
	elif [ "$(NATIVE_TOOLCHAIN)" != yes ]; then echo ">> native: no cmake + c++ on $$(hostname): OFF"; $(MAKE) --no-print-directory native-off; \
	else $(MAKE) --no-print-directory native; fi

native-info: import ## What Godot loads: NativeBridge.available, the switch, and the library's build_info()
	$(GODOT) --headless --path . --script res://tests/native/native_info.gd

# The equality on one Sumps match (ai-ab-match's workload, Law v Condemned, seed 92721, 180 s; AB_FLAGS= for leaders):
# the plain run (native ON), the whole run with --brains-off=native, and the 30-tick A/B must print one state hash.
# On the laptop this is the machine's own proof (its hashes differ from builder0's by glibc, determinism.md).
native-proof: import ## The equality proof: one match three ways (native on, off, A/B) must give one state hash
	@mkdir -p $(BUILD_DIR)/native-proof
	@for arm in on off ab; do \
		case $$arm in on) flags="";; off) flags="--brains-off=native";; ab) flags="--brains-ab-run=native";; esac; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control --green-faction=law --rust-faction=condemned \
			--budget=$(or $(PROF_BUDGET),4600) --time-limit=$(or $(PROF_TIME),180) --seed=$(or $(PROF_SEED),92721) --arena=$(or $(PROF_ARENA),sumps) \
			$$flags $(AB_FLAGS) > $(BUILD_DIR)/native-proof/$$arm.log 2>&1 || true; \
		h=$$(grep -o '"state_hash":"[0-9a-f]*"' $(BUILD_DIR)/native-proof/$$arm.log | head -1); \
		echo "native-proof $$arm: $${h:-NO HASH (see build/native-proof/$$arm.log)} on $$(hostname)"; \
	done
	@grep -h '^BRAINS_AB ' $(BUILD_DIR)/native-proof/ab.log || true
	@grep -h '^NATIVE ' $(BUILD_DIR)/native-proof/on.log | head -1 || true
	@on=$$(grep -o '"state_hash":"[0-9a-f]*"' $(BUILD_DIR)/native-proof/on.log | head -1); \
	off=$$(grep -o '"state_hash":"[0-9a-f]*"' $(BUILD_DIR)/native-proof/off.log | head -1); \
	ab=$$(grep -o '"state_hash":"[0-9a-f]*"' $(BUILD_DIR)/native-proof/ab.log | head -1); \
	if [ -n "$$on" ] && [ "$$on" = "$$off" ] && [ "$$on" = "$$ab" ]; then echo "native-proof: EQUAL ($$on) on $$(hostname)"; \
	else echo "native-proof: NOT EQUAL on $$(hostname) -- the port changed the fight"; exit 1; fi

native-clean: ## Remove this worktree's native build and library (and the .gdextension); the machine's godot-cpp stays
	rm -rf $(NATIVE_BUILD) $(NATIVE_BIN)
