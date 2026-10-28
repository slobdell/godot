# Native code (round 23, stream native): the vehicle brain's hot loop in C++ through godot-cpp, behind
# BrainSwitches.native. How to build, the flags and why, the proof: _agents/native.md. Owner: native.
#
#   make native            build (godot-cpp once per machine under .tools/, then native/src) and switch it ON
#   make native NATIVE=off switch it OFF (the .gdextension is removed; the game runs its GDScript paths)
#   make native-info       what Godot loaded: NativeBridge.available and the library's build_info()
#   make native-bench      the price of one call across the seam, each way of calling it (usec/call)
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

# ---- C34.8 (a) (round 34, native): every judged stage pinned ----------------------------------------------------
# A stage whose numbers decide a ship runs Godot at one physics step a frame (--fixed-fps SIM_HZ), as `make test` has
# since round 33: a free clock lets a loaded machine change how many physics steps fall in a frame, and with them
# which tick an await or a nav sync lands on (pace-determinism's bridge: deck_jam_s 12.6 v 21.0 by load alone).
# PIN_FPS is the one token each pinned recipe carries; `PIN_FPS=` is the free arm (the moves list, native's Status).
# Pinned (C34.8 (a)): command.mk five-squads-series, interleaved-probe, control-timing (x2), facing-probe,
# hull-rest-probe, flank-probe; nav.mk gate-test; pace.mk pace-p0-tests, pace-leak-tests (x2); planner.mk planner-twin,
# planner-trace-hull-rest; tactics.mk converge-probe, scenario-times; traffic.mk traffic-far-hull.
# Free ON PURPOSE, with the reason:
#   the clock is the parameter: pace-div, pace-repro, pace-determinism.
#   real sockets and a wall clock are the point: net-smoke, combat-smoke, relay-*, lobby-smoke, broker-smoke,
#     web-*-smoke, server, play, agent-*, replay, det-spike.
#   a CPU bench measures cost per frame, not outcomes: hud-profile, spawn-cost, native-bench, audio-bench.
#   UI playtests read screenshots and response ticks against the camera's frame pacing (a smoke, not a judged
#     number): control-playtest, picker-playtest, two-squads-playtest, command-playtest, repath-test, screen-probe,
#     garage-smoke, garage-e2e, army-loop-smoke.
#   no physics step decides anything (geometry, assets, exports, the parser): arena-cover, roster-boxes, spawn-probe,
#     tactics-terrain, traffic-islands, traffic-navgap, native-info, native-live-guard's load probe, lint, import,
#     manoeuvre-parse, assets-*, fx-textures, sfx, export-*.
PIN_FPS ?= --fixed-fps $(SIM_HZ)
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
NATIVE_TRIG      ?= cr
CMAKE            ?= cmake
NATIVE_TOOLCHAIN := $(shell command -v $(CMAKE) >/dev/null 2>&1 && command -v c++ >/dev/null 2>&1 && echo yes || echo no)
# Round 34 (N4): every Godot that make starts knows whether a library is expected here, so a twin that finds none FAILS
# (tests/native/native_expect.gd) instead of passing with "native: absent". NATIVE=off, or no toolchain: not expected.
export TANK_NATIVE_EXPECTED := $(if $(filter-out off,$(NATIVE)),$(if $(filter yes,$(NATIVE_TOOLCHAIN)),1))

# ---- Round 39 (N4): one float trig on every machine ---------------------------------------------------------------
# glibc >= 2.41 (the builders) made atan2f acosf asinf atanf tanf correctly rounded (CORE-MATH); 2.39 (the laptop) is
# 1-2 ulp off on 0.1-19 % of inputs, enough to make a jam a different fight (R38.25). The native library defines the five
# itself (native/src/trig, hidden), so it is the same everywhere. The ENGINE takes them from libm, so on a glibc older
# than 2.41 every process make starts gets LD_PRELOAD=libtank_trig (the same CORE-MATH sources, exported), built here
# once per source/flag set into .tools/trig (never uploaded, never cleaned by native-clean). Its sims then hash like the
# builders', so it reads the builders' sim-baseline lines (SIM_BASELINE_KEY). TRIG=system: this machine's own libm (a
# pre-N4 laptop read). Proof: `make trig-check` (exhaustive v libm) and `make trig-digest` (one line per function to
# compare across machines); _agents/native.md "Machine-independent trig".
TRIG             ?= cr
TRIG_SRCS        := native/src/trig/tank_trig.c $(addprefix native/src/trig/core-math/,atan2f.c acosf.c asinf.c atanf.c tanf.c)
TRIG_GLIBC       := $(shell getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $$2}')
TRIG_OLD_LIBM    := $(shell v='$(TRIG_GLIBC)'; [ -n "$$v" ] && [ "$$(printf '%s\n2.41\n' "$$v" | sort -V | head -1)" != 2.41 ] && echo yes)
TRIG_SHA         := $(shell cat $(TRIG_SRCS) 2>/dev/null | { cat; printf '%s' '$(NATIVE_FP_FLAGS)'; } | sha256sum | cut -c1-10)
TRIG_PRELOAD     := $(abspath $(TOOLS_DIR))/trig/libtank_trig-$(TRIG_SHA).so
ifeq ($(TRIG_OLD_LIBM)$(filter cr,$(TRIG)),yescr)
ifeq ($(wildcard $(TRIG_PRELOAD)),)
$(shell mkdir -p $(dir $(TRIG_PRELOAD)) && flock $(dir $(TRIG_PRELOAD)).lock sh -c '[ -e $(TRIG_PRELOAD) ] || { \
	cc $(NATIVE_FP_FLAGS) -fPIC -shared -fvisibility=hidden -w -o $(TRIG_PRELOAD).tmp $(TRIG_SRCS) -lm && mv $(TRIG_PRELOAD).tmp $(TRIG_PRELOAD); }' >&2)
endif
ifneq ($(wildcard $(TRIG_PRELOAD)),)
export LD_PRELOAD := $(TRIG_PRELOAD)$(if $(filter-out $(TRIG_PRELOAD),$(LD_PRELOAD)), $(filter-out $(TRIG_PRELOAD),$(LD_PRELOAD)))
export SIM_BASELINE_KEY ?= glibc-2.43
else
$(info >> trig: glibc $(TRIG_GLIBC) and no $(TRIG_PRELOAD) (no C compiler?): this machine's sims are NOT the builders')
endif
endif
NATIVE_ENV := GODOT=$(GODOT) TOOLS_DIR=$(TOOLS_DIR) DOWNLOADS=$(DOWNLOADS) GODOTCPP_VERSION=$(GODOTCPP_VERSION) \
	GODOTCPP_SHA256=$(GODOTCPP_SHA256) GODOTCPP_URL=$(GODOTCPP_URL) GODOTCPP_SRC=$(GODOTCPP_SRC) \
	GODOTCPP_BUILD=$(GODOTCPP_BUILD) GODOTCPP_LIB=$(GODOTCPP_LIB) NATIVE_FP_FLAGS="$(NATIVE_FP_FLAGS)" \
	NATIVE_DIR=$(NATIVE_DIR) NATIVE_BUILD=$(NATIVE_BUILD) NATIVE_BIN=$(NATIVE_BIN) NATIVE_SO=$(NATIVE_SO) \
	NATIVE_GDEXT=$(NATIVE_GDEXT) NATIVE_JOBS=$(NATIVE_JOBS) NATIVE_CPUS=$(NATIVE_CPUS) CMAKE=$(CMAKE) NATIVE_TRIG=$(NATIVE_TRIG)

.PHONY: native-first-tick-sync
.PHONY: native native-off native-for-check native-info native-bench native-proof native-sizing native-price native-clean native-tp-headless

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

# Round 38 (N3): perf-judge's machine-relative line on a machine that does not judge (builder2): every attempt runs with
# scenario_perf's nominal refusal off and records both lines (PERF_JUDGE_RELATIVE, with the cpu model); exits 3 (NOT JUDGED)
# by design, so read the file, not the exit. Tabulate with tools/judge/perf_relative.py build/perf-relative/.
.PHONY: perf-relative-trial
perf-relative-trial: import ## N3: perf-judge's two lines recorded on a non-judging box (PERF_JUDGE_TRIES=5) -> build/perf-relative/perf-judge.txt
	-PERF_JUDGE_TRIAL=1 PERF_JUDGE_TRIES=$${PERF_JUDGE_TRIES:-5} tools/perf_judge.sh $(GODOT) $(SIM_HZ) $(BUILD_DIR)/perf-relative
	@$(PYTHON) tools/judge/perf_relative.py $(BUILD_DIR)/perf-relative

# The price of one call across the seam (NATIVE_BENCH lines, usec per call): pin it (NATIVE_BENCH_CPUS=0-3 on builder0).
native-bench: import ## The price of ONE GDScript->native call, each way of calling it (usec/call; pin with NATIVE_BENCH_CPUS=0-3)
	$(if $(NATIVE_BENCH_CPUS),taskset -c $(NATIVE_BENCH_CPUS)) $(GODOT) --headless --path . --script res://tests/native/native_bench.gd

# The equality on one Sumps match (ai-ab-match's workload, Law v Condemned, seed 92721, 180 s; AB_FLAGS= for leaders):
# the plain run (native ON), the whole run with --brains-off=native, and the 30-tick A/B must print one state hash.
# On the laptop this is the machine's own proof (its hashes differ from builder0's by glibc, determinism.md).
# NATIVE_PROOF_ARMS adds arms: `mirror` (round 27, stage 1 E1) runs --native-exec-mirror, every crew's execute state
# pulled, scrambled and pushed back by the C++ every tick (game/ai/native/native_exec.gd): push must be lossless;
# `owned` (E1c) runs --native-exec-owned, the native drive on the C++-owned state (NativeDrive.owned); `exec` (E5) turns
# native_exec on (compute_command as one native call), `exec_owned` the same on the owned state.
NATIVE_PROOF_ARMS ?= on off ab
native-proof: import ## The equality proof: one match three ways (native on, off, A/B; NATIVE_PROOF_ARMS adds mirror) must give one state hash
	@mkdir -p $(BUILD_DIR)/native-proof
	@for arm in $(NATIVE_PROOF_ARMS); do \
		case $$arm in on) flags="";; off) flags="--brains-off=native";; ab) flags="--brains-ab-run=native";; \
			mirror) flags="--native-exec-mirror";; owned) flags="--native-exec-owned";; \
			exec) flags="--brains-on=native_exec";; exec_owned) flags="--brains-on=native_exec --native-exec-owned";; \
			exec_verify) flags="--brains-on=native_exec --native-exec-owned --native-exec-verify";; \
			stage1) flags="--brains-on=native_exec,native_cb,native_owned";; \
			motion) flags="--brains-on=native_motion";; \
			tank) flags="--brains-on=native_tank";; \
			combat) flags="--brains-on=native_combat";; \
			pathing) flags="--brains-on=native_pathing";; \
			perception) flags="--brains-on=native_perception";; \
			incoming) flags="--brains-on=native_incoming";; \
			shell) flags="--brains-on=native_shell";; \
			threat) flags="--brains-on=native_threat";; \
			controller) flags="--brains-on=native_controller";; \
			wall) flags="--brains-on=native_wall";; \
			feed) flags="--brains-on=native_feed";; nofeed) flags="--brains-off=native_feed";; \
			stage1_profile) flags="--brains-on=native_exec,native_cb,native_owned --native-exec-profile --native-drive-profile";; \
			stage1_ab) flags="--brains-on=native_cb,native_owned --brains-ab-run=native_exec";; *) echo "native-proof: unknown arm $$arm"; exit 2;; esac; \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control --green-faction=law --rust-faction=condemned \
			--budget=$(or $(PROF_BUDGET),4600) --time-limit=$(or $(PROF_TIME),180) --seed=$(or $(PROF_SEED),92721) --arena=$(or $(PROF_ARENA),sumps) \
			$$flags $(AB_FLAGS) > $(BUILD_DIR)/native-proof/$$arm.log 2>&1 || true; \
		h=$$(grep -o '"state_hash":"[0-9a-f]*"' $(BUILD_DIR)/native-proof/$$arm.log | head -1); \
		echo "native-proof $$arm: $${h:-NO HASH (see build/native-proof/$$arm.log)} on $$(hostname)"; \
	done
	@grep -h '^BRAINS_AB ' $(BUILD_DIR)/native-proof/ab.log 2>/dev/null || true
	@grep -h '^NATIVE_EXEC_MIRROR ' $(BUILD_DIR)/native-proof/mirror.log 2>/dev/null | tail -1 || true
	@grep -h '^NATIVE ' $(BUILD_DIR)/native-proof/on.log 2>/dev/null | head -1 || true
	@first=""; same=1; for arm in $(NATIVE_PROOF_ARMS); do \
		h=$$(grep -o '"state_hash":"[0-9a-f]*"' $(BUILD_DIR)/native-proof/$$arm.log | head -1); \
		if [ -z "$$h" ]; then same=0; elif [ -z "$$first" ]; then first=$$h; elif [ "$$h" != "$$first" ]; then same=0; fi; \
	done; \
	if [ $$same = 1 ] && [ -n "$$first" ]; then echo "native-proof: EQUAL ($$first) on $$(hostname)"; \
	else echo "native-proof: NOT EQUAL on $$(hostname) -- the port changed the fight"; exit 1; fi

# Round 27 (stage 1 E5b): every owned execute verified against a fresh pull of the members, through the whole suite and
# the AI scenarios (TANK_NATIVE_EXEC_VERIFY=1 -> NativeExec.verify; a mismatch is an engine ERROR, which fails the test or
# scenario that reached it). Finds a GDScript writer of mover/gunnery/lay members that does not mark native_stale.
native-verify-suite: import ## Stage 1's doors audit: the suite + AI scenarios with every owned native execute verified (a missed native_stale fails)
	@t=0; s=0; TANK_NATIVE_EXEC_VERIFY=1 $(MAKE) --no-print-directory test || t=$$?; \
	TANK_NATIVE_EXEC_VERIFY=1 $(MAKE) --no-print-directory ai-scenarios || s=$$?; \
	echo "native-verify-suite: test exited $$t, ai-scenarios exited $$s"; [ $$t = 0 ] && [ $$s = 0 ]

# The check's guard (round 27: the whole suite under verification takes ~26 min on builder0; the AI scenarios alone ~4):
# the brain-driven scenarios with every owned execute verified, so a GDScript writer of the owned state that does not
# mark native_stale fails the check that first reaches it.
# The scenarios' own output goes to a file and this target judges it, as ai-scenarios-check does (the runner prints two
# "Unicode parsing error ... NUL" lines on hybrid CPUs, scenario_perf's sysfs read: brains', reported; check's engine
# gate fails any target whose log shows them): FAIL on a verify mismatch (NativeExec verify), a failing scenario, or a crash.
native-verify-scenarios: import ## Stage 1's doors guard for check: the AI scenarios with every owned native execute verified (~4 min builder0)
	@mkdir -p $(BUILD_DIR)
	@s=0; TANK_NATIVE_EXEC_VERIFY=1 $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/ai_scenarios/run_scenarios.gd -- \
		> $(BUILD_DIR)/native-verify-scenarios.log 2>&1 || s=$$?; \
	v=$$(grep -c "NativeExec verify" $(BUILD_DIR)/native-verify-scenarios.log || true); \
	grep -h "^scenarios: " $(BUILD_DIR)/native-verify-scenarios.log || true; \
	echo "native-verify-scenarios: runner exited $$s, $$v verify mismatches (build/native-verify-scenarios.log)"; \
	if [ "$$v" != 0 ]; then grep -m3 "NativeExec verify" $(BUILD_DIR)/native-verify-scenarios.log | cut -c1-300; exit 1; fi; \
	grep -q "^scenarios: .* 0 failed" $(BUILD_DIR)/native-verify-scenarios.log || { echo "native-verify-scenarios: a scenario failed or the runner did not finish"; exit 1; }; \
	[ $$s = 0 ] || [ $$s = 1 ] || { echo "native-verify-scenarios: the runner crashed (exit $$s)"; exit 1; }

# The band sized for the lead (round 23, the orchestrator's ask): N a side with leaders both sides (perf's army files),
# NATIVE_SIZE_RUNS matches each with --brains-parts (the shares: execute v think v engine calls) and with --sim-profile
# (the uninflated band), pinned (NATIVE_SIZE_CPUS=0-3 on builder0); tests/native/sizing_table.py prints the table.
# NATIVE_SIZE_N=50 NATIVE_SIZE_RUNS=3 NATIVE_SIZE_TIME=120 NATIVE_SIZE_FLAGS= (e.g. --brains-off=native for the GDScript band).
native-sizing: import ## The controller band at N a side with leaders: execute v think v engine-call shares and the band's ms (n runs, pinned) -> build/native-sizing/
	@mkdir -p $(BUILD_DIR)/native-sizing $(BUILD_DIR)/perf-armies && rm -f $(BUILD_DIR)/native-sizing/*.log
	$(PYTHON) tools/perf_armies.py size $(or $(NATIVE_SIZE_N),50) $(BUILD_DIR)/perf-armies
	@for i in $$(seq 1 $(or $(NATIVE_SIZE_RUNS),3)); do for mode in parts profile; do \
		case $$mode in parts) flag="--brains-parts --sim-profile";; profile) flag=--sim-profile;; esac; \
		echo ">> native-sizing: run $$i $$mode ($$(date '+%H:%M:%S'), load $$(cut -d' ' -f1 /proc/loadavg))"; \
		$(if $(NATIVE_SIZE_CPUS),taskset -c $(NATIVE_SIZE_CPUS)) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control \
			--green-doctrine=res://$(BUILD_DIR)/perf-armies/green_$(or $(NATIVE_SIZE_N),50).json \
			--rust-doctrine=res://$(BUILD_DIR)/perf-armies/rust_$(or $(NATIVE_SIZE_N),50).json --budget=100000 \
			--time-limit=$(or $(NATIVE_SIZE_TIME),120) --seed=$(or $(PROF_SEED),92721) --arena=$(or $(PROF_ARENA),sumps) \
			--green-elements --rust-elements $$flag $(NATIVE_SIZE_FLAGS) > $(BUILD_DIR)/native-sizing/run$$i-$$mode.log 2>&1 || true; \
		grep -h '^MATCH_RESULT' $(BUILD_DIR)/native-sizing/run$$i-$$mode.log | cut -c1-160 || echo "   (no MATCH_RESULT: see the log)"; \
	done; done
	$(PYTHON) tests/native/sizing_table.py $(BUILD_DIR)/native-sizing/*.log

# The price of one switch (or every port: native) the brief's way: ai-ab-match's in-run A/B (30-tick blocks, the
# controller band charged per arm) on his Sumps, 25 v 25 and 50 v 50 with leaders both sides, NATIVE_PRICE_RUNS runs
# each, pinned (NATIVE_PRICE_CPUS=0-3 on builder0), one plain run per workload for the hash. NATIVE_PRICE_SWITCH=native_nav
# NATIVE_PRICE_SIZES="his 25 50" NATIVE_PRICE_RUNS=3 NATIVE_PRICE_TIME=120 (his Sumps keeps ai-ab-match's 180 s).
native-price: import ## The price of a native switch: BRAINS_AB on his Sumps / 25 v 25 / 50 v 50 with leaders, n runs pinned, hashes equal -> build/native-price/
	@mkdir -p $(BUILD_DIR)/native-price $(BUILD_DIR)/perf-armies && rm -f $(BUILD_DIR)/native-price/*.log
	@for size in $(or $(NATIVE_PRICE_SIZES),his 25 50); do [ $$size = his ] || $(PYTHON) tools/perf_armies.py size $$size $(BUILD_DIR)/perf-armies; done
	@sw=$(or $(NATIVE_PRICE_SWITCH),native); for size in $(or $(NATIVE_PRICE_SIZES),his 25 50); do \
		if [ $$size = his ]; then army="--green-faction=law --rust-faction=condemned --budget=4600"; secs=180; \
		else army="--green-doctrine=res://$(BUILD_DIR)/perf-armies/green_$$size.json --rust-doctrine=res://$(BUILD_DIR)/perf-armies/rust_$$size.json --budget=100000"; secs=$(or $(NATIVE_PRICE_TIME),120); fi; \
		for i in $$(seq 0 $(or $(NATIVE_PRICE_RUNS),3)); do \
			if [ $$i = 0 ]; then ab=""; tag=plain; else ab="--brains-ab-run=$$sw"; tag=ab$$i; fi; \
			log=$(BUILD_DIR)/native-price/$$sw-$$size-$$tag.log; \
			echo ">> native-price: $$sw $$size $$tag ($$(date '+%H:%M:%S'), load $$(cut -d' ' -f1 /proc/loadavg))"; \
			$(if $(NATIVE_PRICE_CPUS),taskset -c $(NATIVE_PRICE_CPUS)) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control \
				$$army --time-limit=$$secs --seed=$(or $(PROF_SEED),92721) --arena=$(or $(PROF_ARENA),sumps) \
				--green-elements --rust-elements $$ab $(NATIVE_PRICE_FLAGS) > $$log 2>&1 || true; \
			h=$$( { grep -o '"state_hash":"[0-9a-f]*"' $$log || true; } | head -1); \
			line=$$( { grep -h '^BRAINS_AB ' $$log || true; } | sed 's/; whole tick.*//' | cut -c1-160); \
			echo "NATIVE_PRICE $$sw $$size $$tag $$(hostname) $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-?}) $${h:-NO_HASH} $${line:-}"; \
		done; \
	done | tee $(BUILD_DIR)/native-price/summary.txt
	@awk '/^NATIVE_PRICE/ { key = $$2 " " $$3; h = $$7; if (!(key in first)) first[key] = h; else if (first[key] != h) bad = bad " " key "/" $$4 } END { if (bad != "") { print "native-price: hashes DIFFER:" bad; exit 1 } else print "native-price: every run of a workload gave one hash" }' $(BUILD_DIR)/native-price/summary.txt

native-clean: ## Remove this worktree's native build and library (and the .gdextension); the machine's godot-cpp stays
	rm -rf $(NATIVE_BUILD) $(NATIVE_BIN)

# Round 24: the laptop's windowed, in-contact table that rules the THINK ports (the orchestrator's rule, native.md *The
# rules for a seam*): perf-fight at NATIVE_TP_SIZE a side, his preset, foundry + parade x three seeds, each arm with
# `--native-tick-profile=NATIVE_TP_WINDOW` (TickProfile: SimProfile split over that window of match time) and the arm's
# own flags; then the table (tests/native/tick_profile_table.py). Needs a display: run it on the laptop, quiet, one
# Godot at a time. NATIVE_TP_ARMS is "name=flags" words, flags comma-free per word (use --brains-on=a,b as ONE flag).
NATIVE_TP_SIZE ?= 25
# C25.6: every arm pins --squad-cap=<size / 5>, so 25 a side means 25 on the laptop preset too (whose own cap is 4
# squads); an arm whose flags name --squad-cap (`--squad-cap=machine`: this machine's cap, as he plays) keeps its own.
NATIVE_TP_WINDOW ?= 8,20
NATIVE_TP_CYCLES ?= 3
NATIVE_TP_ARMS ?= on= off=--brains-off=native
# Round 24 (the standing practice since 4ba8fd0b's void session): a NATIVE_TP_COOLDOWN s pause first (never straight after
# a build), and the arms ALTERNATED arena by arena and seed by seed, the order reversed every pair (ABBA), so a laptop
# warming or cooling through the session moves both arms together. Read the paired column (tick_profile_paired.py).
# Round 25 (N5a): two WORKLOADS. `bar` (the default) is C24.7's: foundry + parade, the bar's definition, which does not
# move without him. `water` is his last two playtests' kind of map: the Locks and the Crossing (rivers and bridges, where
# SlotGround's water rules and the crossings do real work), with its own window (NATIVE_TP_WATER_WINDOW: the armies
# meet later across a river; set from where the fight starts on those maps, native.md *The two workloads*). A session
# reads one workload; never pool them. The previous session's logs move to build/tp-prev/ first (one session per table).
NATIVE_TP_WORKLOAD ?= bar
NATIVE_TP_WATER_ARENAS ?= locks crossing
NATIVE_TP_WATER_WINDOW ?= 12,24
NATIVE_TP_ARENAS ?= $(if $(filter water,$(NATIVE_TP_WORKLOAD)),$(NATIVE_TP_WATER_ARENAS),foundry parade)
NATIVE_TP_SEEDS ?= 92721 31337 5988
NATIVE_TP_COOLDOWN ?= 180
NATIVE_TP_WIN = $(if $(filter water,$(NATIVE_TP_WORKLOAD)),$(NATIVE_TP_WATER_WINDOW),$(NATIVE_TP_WINDOW))
native-tick-profile: ## The windowed in-contact tick split on the laptop, arms alternated ABBA per arena x seed (NATIVE_TP_WORKLOAD=bar|water, NATIVE_TP_ARMS "name=flags") -> build/tp-<arm>-*.log + table
	@mkdir -p $(BUILD_DIR)/tp-prev && for f in $(BUILD_DIR)/tp-*.log; do [ -e "$$f" ] && mv "$$f" $(BUILD_DIR)/tp-prev/; done; true
	@echo ">> native-tick-profile: workload $(NATIVE_TP_WORKLOAD) ($(NATIVE_TP_ARENAS), window $(NATIVE_TP_WIN) s) on $$(hostname) at $$(git rev-parse --short HEAD)"
	@echo ">> native-tick-profile: cooling down $(NATIVE_TP_COOLDOWN) s first"; sleep $(NATIVE_TP_COOLDOWN)
	@i=0; for arena in $(NATIVE_TP_ARENAS); do for seed in $(NATIVE_TP_SEEDS); do \
		specs="$(NATIVE_TP_ARMS)"; [ $$((i % 2)) = 1 ] && specs=$$(echo $$specs | tr ' ' '\n' | tac | tr '\n' ' '); \
		for spec in $$specs; do name=$${spec%%=*}; flags=$${spec#*=}; size=$(NATIVE_TP_SIZE); \
			case $$name in *@*) size=$${name#*@}; name=$${name%%@*};; esac; \
			echo ">> native-tick-profile: $$arena $$seed arm $$name, $$size a side ($$flags)"; \
			$(MAKE) --no-print-directory perf-fight PERF_FIGHT=size PERF_FIGHT_SIZES=$$size PERF_FIGHT_ARMS=main \
				PERF_FIGHT_ARENAS=$$arena PERF_FIGHT_SEEDS=$$seed PERF_FIGHT_CYCLES=$(NATIVE_TP_CYCLES) PERF_FIGHT_NAME=tp-$$name \
				PERF_FIGHT_EXTRA="--native-tick-profile=$(NATIVE_TP_WIN) $$(case "$$flags" in *--squad-cap*) ;; *) echo --squad-cap=$$((size / 5));; esac) $$flags" || exit 1; \
		done; i=$$((i + 1)); \
	done; done
	$(PYTHON) tests/native/tick_profile_table.py $(BUILD_DIR)
	@$(PYTHON) tests/native/tick_profile_budget.py $(BUILD_DIR) $(firstword $(subst @, ,$(firstword $(subst =, ,$(firstword $(NATIVE_TP_ARMS)))))) || true

# Round 24 (stretch b): the library cross-compiled for Android arm64-v8a with the NDK (pinned below, fetched into
# .tools/ once per machine; ~660 MB). Builds godot-cpp for arm64 beside the desktop binding (same numeric flags) and
# native/src into native/bin-android/. The desktop library and its .gdextension are untouched; the Android export's
# entry and the trig hazard's proof on a device (bionic's libm) are what is left (_agents/native.md *Android*).
NDK_VERSION ?= r27c
NDK_SHA256  := 59c2f6dc96743b5daf5d1626684640b20a6bd2b1d85b13156b90333741bad5cc
NDK_URL     := https://dl.google.com/android/repository/android-ndk-$(NDK_VERSION)-linux.zip
native-android: native ## Cross-compile the native library for Android arm64-v8a (NDK pinned, fetched once into .tools/) -> native/bin-android/
	GODOT=$(GODOT) TOOLS_DIR=$(TOOLS_DIR) DOWNLOADS=$(DOWNLOADS) NDK_VERSION=$(NDK_VERSION) NDK_SHA256=$(NDK_SHA256) \
		NDK_URL=$(NDK_URL) GODOTCPP_SRC=$(GODOTCPP_SRC) GODOTCPP_API=$(GODOTCPP_BUILD)/api/extension_api.json \
		GODOTCPP_VERSION=$(GODOTCPP_VERSION) NATIVE_FP_FLAGS="$(NATIVE_FP_FLAGS)" NATIVE_DIR=$(NATIVE_DIR) \
		NATIVE_JOBS=$(NATIVE_JOBS) NATIVE_CPUS=$(NATIVE_CPUS) CMAKE=$(CMAKE) NATIVE_TRIG=$(NATIVE_TRIG) bash $(NATIVE_DIR)/build_android.sh

# Round 24 (N4): where the in-contact tick goes, headless on builder0 (no display there): his Sumps at NATIVE_TPH_SIZE a
# side with leaders, `--native-tick-profile=NATIVE_TP_WINDOW` (every sub-lap on), one run per seed, then
# every section sorted (tests/native/tick_profile_parts.py). Proportions for choosing a port; the ruling stays the
# laptop's windowed table (native-tick-profile).
NATIVE_TPH_SIZE ?= 25
NATIVE_TPH_SEEDS ?= 92721 31337 5988
native-tp-headless: import ## Every SimProfile section of the in-contact window, headless, NATIVE_TPH_SIZE a side x NATIVE_TPH_SEEDS (NATIVE_TPH_FLAGS) -> build/native-tph/
	@mkdir -p $(BUILD_DIR)/native-tph $(BUILD_DIR)/perf-armies && rm -f $(BUILD_DIR)/native-tph/*.log
	@$(PYTHON) tools/perf_armies.py size $(NATIVE_TPH_SIZE) $(BUILD_DIR)/perf-armies
	@for seed in $(NATIVE_TPH_SEEDS); do log=$(BUILD_DIR)/native-tph/tph-$$seed.log; \
		echo ">> native-tp-headless: $(NATIVE_TPH_SIZE) a side, seed $$seed ($$(hostname), $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-?}))"; \
		$(if $(NATIVE_PRICE_CPUS),taskset -c $(NATIVE_PRICE_CPUS)) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control \
			--green-doctrine=res://$(BUILD_DIR)/perf-armies/green_$(NATIVE_TPH_SIZE).json \
			--rust-doctrine=res://$(BUILD_DIR)/perf-armies/rust_$(NATIVE_TPH_SIZE).json --budget=100000 \
			--time-limit=30 --seed=$$seed --arena=$(or $(PROF_ARENA),sumps) --green-elements --rust-elements \
			--native-tick-profile=$(NATIVE_TP_WINDOW) $(NATIVE_TPH_FLAGS) > $$log 2>&1 || true; \
		grep -c '^NATIVE_TICK_PROFILE' $$log >/dev/null || { echo "   no NATIVE_TICK_PROFILE: see $$log"; tail -5 $$log; }; \
	done
	$(PYTHON) tests/native/tick_profile_parts.py $(BUILD_DIR)/native-tph/*.log | tee $(BUILD_DIR)/native-tph/parts.txt

# Round 28 (N7 guard): every native switch in force takes its native path under the tick profile (the instrument every
# price and the laptop's ruling use). Counts from the profile's install until its window opens (20 s), a fight at 20 a
# side on foundry, then tests/native/live_guard.py: a switch ON but never taken fails, named. ~1 min on builder0.
# Round 31 (the planner's two segfaults): a C++ STATIC holding a godot builtin (RID, String, ...) crashes at LIBRARY LOAD
# (its constructor calls a binding the extension's init has not set yet: d373af4e died inside --import), and a static
# godot Ref crashes at EXIT (it outlives the ObjectDB: ad1d1f3d). Either is invisible to a test that passed, so first: one
# headless start and quit through the library, exit 0 and no crash line, or the guard fails. A few seconds.
native-live-guard: import ## Every ON native switch is LIVE under the tick profile (a seam that steps aside for a measurement mode fails)
	@if [ -e $(NATIVE_GDEXT) ]; then \
		$(GODOT) --headless --path . --quit > $(BUILD_DIR)/native-load-guard.log 2>&1; code=$$?; \
		if [ $$code -ne 0 ] || grep -q 'handle_crash\|Program crashed\|signal 11' $(BUILD_DIR)/native-load-guard.log; then \
			echo "native-load-guard: the library's load or exit CRASHED (exit $$code; build/native-load-guard.log): a C++ static holding a godot Ref or builtin?"; \
			tail -20 $(BUILD_DIR)/native-load-guard.log; exit 1; \
		fi; \
		echo "native-load-guard: the library loads and unloads cleanly (exit 0)"; \
	fi
	@mkdir -p $(BUILD_DIR)/perf-armies && $(PYTHON) tools/perf_armies.py size 20 $(BUILD_DIR)/perf-armies
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control \
		--green-doctrine=res://$(BUILD_DIR)/perf-armies/green_20.json --rust-doctrine=res://$(BUILD_DIR)/perf-armies/rust_20.json \
		--budget=100000 --time-limit=24 --seed=92721 --arena=foundry --green-elements --rust-elements \
		--native-tick-profile=20,22 > $(BUILD_DIR)/native-live-guard.log 2>&1 || true
	@$(PYTHON) tests/native/live_guard.py $(BUILD_DIR)/native-live-guard.log

# Round 36 (native, E4b): what the physics space holds at a new body's FIRST tick depends on where the setup ran, not on
# engine state the first main-loop iteration sets (R35.57's naming, corrected). Two overlapping bodies, six setup contexts,
# known answers: synced only from a call_deferred flushed inside the physics frame (run_tests.gd's first test before the
# warm-up) or a node's _physics_process; stale from a physics/process signal, an idle-frame flush, or a main scene's _ready
# (real play's --skirmish). Fails if the engine ever moves one (a Godot upgrade). Not part of check; a few seconds.
FIRST_TICK_SYNCED := physics_flush in_tick
FIRST_TICK_STALE := physics_signal process_signal process_flush main_ready
native-first-tick-sync: import ## E4b: which setup contexts a new body's first tick sees synced (known answers; tests/native/first_tick_sync.gd)
	@mkdir -p $(BUILD_DIR); fail=0; \
	for arm in $(FIRST_TICK_SYNCED) $(FIRST_TICK_STALE); do \
		if [ $$arm = main_ready ]; then $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . res://tests/native/first_tick_sync_scene.tscn; \
		else $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/native/first_tick_sync.gd -- --arm=$$arm; fi \
			> $(BUILD_DIR)/first-tick-sync-$$arm.log 2>&1 || true; \
		line=$$(grep -m1 '^FIRST_TICK_SYNC ' $(BUILD_DIR)/first-tick-sync-$$arm.log || true); echo "$${line:0:150}"; \
		want=stale; case " $(FIRST_TICK_SYNCED) " in *" $$arm "*) want=synced;; esac; \
		got=$$(echo "$$line" | awk '{print $$3}'); \
		if [ "$$got" != "$$want" ]; then echo "native-first-tick-sync: $$arm read '$${got:-nothing}', want $$want (build/first-tick-sync-$$arm.log)"; fail=1; fi; \
		if grep -q 'ERROR' $(BUILD_DIR)/first-tick-sync-$$arm.log; then grep -m3 ERROR $(BUILD_DIR)/first-tick-sync-$$arm.log; fail=1; fi; \
	done; \
	[ $$fail = 0 ] && echo "native-first-tick-sync: synced = $(FIRST_TICK_SYNCED); stale = $(FIRST_TICK_STALE) (as known)"; exit $$fail

# Round 26 (C25.6, orders' showmatch): a skirmish on the LAPTOP preset, headless, every faction against the next, both
# sides faction armies (the case the cap folds). Fails on any "Elements.form ... refused" line (a squad past five that
# fought with no element) or when ARMY_CAP_FIELDED does not read four squads of at most 20 a side.
NATIVE_CAP_PAIRS ?= gangs:law law:syndicate syndicate:condemned condemned:gangs
native-cap-probe: import ## Headless skirmishes on --render-preset=laptop, each faction pair (NATIVE_CAP_PAIRS): no refused element, 4 squads <= 20 a side -> build/native-cap/
	@mkdir -p $(BUILD_DIR)/native-cap && rm -f $(BUILD_DIR)/native-cap/*.log; bad=0; \
	for pair in $(NATIVE_CAP_PAIRS); do p=$${pair%%:*}; e=$${pair##*:}; log=$(BUILD_DIR)/native-cap/$$p-$$e.log; \
		timeout 600 $(GODOT) --headless --path . --fixed-fps $(SIM_HZ) -- --skirmish --scripted --player=cpu --enemy=cpu \
			--no-pick-faction --player-faction=$$p --enemy-faction=$$e --seed=7 --arena=sumps --mute --render-preset=laptop \
			--hash-every=30 --hash-until=300 > $$log 2>&1 || true; \
		cap=$$(grep -a '^ARMY_CAP_FIELDED' $$log | head -1 || true); refused=$$(grep -ac 'refused (C19.1)' $$log || true); \
		echo ">> native-cap-probe $$p v $$e: $$(grep -a '^ARMY_CAP ' $$log | head -1 || true) | $$cap | refused $$refused"; \
		echo "$$cap" | grep -q 'squads=4 green_squads=[1-4] green=\([0-9]\|1[0-9]\|20\) rust_squads=[1-4] rust=\([0-9]\|1[0-9]\|20\)$$' || bad=1; \
		[ "$$refused" = 0 ] || bad=1; \
	done; [ $$bad = 0 ] && echo ">> native-cap-probe: PASS" || { echo ">> native-cap-probe: FAIL"; exit 1; }

# Round 30 (C30.2, brains' B5c-v4 pair): brains' gate-series cells (mk/nav.mk) with the rule ON on the DEFAULT path (the
# native drive), so each run can be held field for field against brains' judged on-arm run (its --brains-off=native).
# NATIVE_GATE_FLAGS adds flags (e.g. --brains-off=native for the GDScript twin). -> build/native-gate.jsonl
.PHONY: native-gate-cells
native-gate-cells: import ## Round 30: brains' yard + Sumps gate cells, rule ON, on the default (native) path -> build/native-gate.jsonl
	@rm -rf $(BUILD_DIR)/native-gate-runs; mkdir -p $(BUILD_DIR)/native-gate-runs
	@echo ">> native-gate-cells on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | flags '$(NATIVE_GATE_FLAGS)'"
	@for cell in yard sumps; do \
		case $$cell in yard) for s in $(GATE_YARD_SEEDS); do for t in $(GATE_TICKS); do echo "$$cell on $$s $$t"; done; done;; \
		sumps) for s in $(GATE_SUMPS_SEEDS); do for t in $(GATE_TICKS); do echo "$$cell on $$s $$t"; done; done;; esac; \
	done | xargs -P $(GATE_JOBS) -L 1 sh -c 'cell=$$0; arm=$$1; seed=$$2; tick=$$3; flags="$(NATIVE_GATE_FLAGS)"; \
		out=$(BUILD_DIR)/native-gate-runs/$$cell-$$arm-$$seed-$$tick.json; \
		case $$cell in \
		sumps) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/settle_probe.gd -- --arena=sumps \
			--dir=forward --metres=150 --seed=$$seed --units=law_scout:law_ifv:law_tank:law_tank --seconds=120 --drills=on \
			--lab-start-tick=$$tick $$flags 2>/dev/null | grep -o "SETTLE_PROBE {.*" | sed "s/^SETTLE_PROBE {/{\"cell\":\"$$cell\",\"arm\":\"$$arm\",\"start_tick\":$$tick,/" > $$out;; \
		yard) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/tactics/reseat_probe.gd -- --arena=yard_open \
			--kind=cross --which=both --seed=$$seed --seconds=90 --lab-start-tick=$$tick $$flags 2>/dev/null \
			| grep -o "RESEAT_PROBE {.*" | sed "s/^RESEAT_PROBE {/{\"cell\":\"$$cell\",\"arm\":\"$$arm\",\"start_tick\":$$tick,/" > $$out;; esac; \
		[ -s $$out ] || echo "{\"cell\":\"$$cell\",\"arm\":\"$$arm\",\"seed\":$$seed,\"start_tick\":$$tick,\"missing\":true}" > $$out; \
		echo "  ran $$cell s$$seed t$$tick"'
	@cat $(BUILD_DIR)/native-gate-runs/*.json > $(BUILD_DIR)/native-gate.jsonl; wc -l < $(BUILD_DIR)/native-gate.jsonl

# C34.8 (a)'s moves list: each pinned stage run twice pinned and twice free (ABAB) on one commit, its output kept per
# arm under build/pin-moves/<target>/<arm><n>/ (the target's own outputs, its log, the 1-min load before and after).
# Stages run PIN_MOVES_JOBS at a time, each one's four arms in series. tests/native/pin_moves.py reads the result.
PIN_MOVES_TARGETS ?= five-squads-series interleaved-probe control-timing facing-probe hull-rest-probe flank-probe \
	gate-test pace-p0-tests pace-leak-tests planner-twin planner-trace-hull-rest converge-probe scenario-times traffic-far-hull
PIN_MOVES_JOBS ?= 6
# A run cut short (slot.sh's 90-minute limit took facing-probe's and hull-rest-probe's free2 the first time) is finished
# arm by arm: PIN_MOVES_TARGETS="facing-probe hull-rest-probe" PIN_MOVES_ARMS=free2 PIN_MOVES_KEEP=1.
PIN_MOVES_ARMS ?= pin1 free1 pin2 free2
PIN_MOVES_KEEP ?=
pin_moves_out = five-squads-series:five-squads interleaved-probe:interleaved facing-probe:facing hull-rest-probe:hull-rest \
	flank-probe:flank gate-test:gate-test.log pace-p0-tests:pace/p0t pace-leak-tests:pace/leakt planner-twin: \
	planner-trace-hull-rest:planner converge-probe:converge-probe scenario-times:scenario-times.txt traffic-far-hull:traffic-far-hull \
	control-timing:
pin-moves: import native ## C34.8 (a): every pinned stage x (pinned, free, pinned, free) on one commit -> build/pin-moves/ + the moves table
	@$(if $(PIN_MOVES_KEEP),,rm -rf $(BUILD_DIR)/pin-moves;) mkdir -p $(BUILD_DIR)/pin-moves
	@printf '%s\n' $(PIN_MOVES_TARGETS) | xargs -P $(PIN_MOVES_JOBS) -I{} sh -c '\
		out=""; for m in $(pin_moves_out); do [ "$${m%%:*}" = {} ] && out=$${m#*:}; done; \
		for arm in $(PIN_MOVES_ARMS); do d=$(BUILD_DIR)/pin-moves/{}/$$arm; rm -rf $$d; mkdir -p $$d; \
			case $$arm in pin*) fps="--fixed-fps $(SIM_HZ)";; *) fps="";; esac; \
			cut -d" " -f1 /proc/loadavg > $$d/load_before; started=$$(date +%s); \
			$(MAKE) --no-print-directory {} PIN_FPS="$$fps" > $$d/run.log 2>&1; echo $$? > $$d/exit; \
			echo $$(( $$(date +%s) - started )) > $$d/secs; cut -d" " -f1 /proc/loadavg > $$d/load_after; \
			[ -n "$$out" ] && [ -e $(BUILD_DIR)/$$out ] && cp -r $(BUILD_DIR)/$$out $$d/out; \
			echo "PIN_MOVES {} $$arm exit=$$(cat $$d/exit) secs=$$(cat $$d/secs) load=$$(cat $$d/load_before)"; done'
	@$(PYTHON) tests/native/pin_moves.py $(BUILD_DIR)/pin-moves | tee $(BUILD_DIR)/pin-moves/table.txt

# Round 39 (N4): the trig proof. trig-check: CORE-MATH v this machine's libm, all 2^32 inputs of acosf asinf atanf tanf and
# ATAN2_SAMPLES (4e8) pairs of atan2f, run WITHOUT the preload (0 differ on glibc >= 2.41). trig-digest: a digest of every
# output per function (the system's float math the engine and native import, and the cr_ five), the same lines on two
# machines = the same results. Minutes on every thread (TRIG_THREADS=4 on a shared builder); not in check.
TRIG_CHECK_BIN := $(BUILD_DIR)/trig/trig_check
$(TRIG_CHECK_BIN): native/src/trig/trig_check.c $(TRIG_SRCS)
	@mkdir -p $(dir $@)
	env -u LD_PRELOAD cc $(NATIVE_FP_FLAGS) -pthread -w -o $@ native/src/trig/trig_check.c $(filter-out %/tank_trig.c,$(TRIG_SRCS)) -lm

trig-check: $(TRIG_CHECK_BIN) ## N4: CORE-MATH's five float trig v this machine's libm, every input (0 differ on glibc >= 2.41)
	env -u LD_PRELOAD $(TRIG_CHECK_BIN) compare

trig-digest: $(TRIG_CHECK_BIN) ## N4: one digest line per float libm function; compare the lines across machines
	env -u LD_PRELOAD $(TRIG_CHECK_BIN) digest

# The orchestrator's ask (main 76f42a9c3, +8.8 % ai_usec_per_tick v 8952c3d64): N4's native trig cost, by removal. The
# library built cr (as shipped) v NATIVE_TRIG=libm, perf-judge per arm, TRIG_AB_ROUNDS (3) rounds in alternating order, on
# a quiet builder0: `make remote T=trig-perf-ab`. The library is left cr. -> build/trig-perf-ab/summary.txt
.PHONY: trig-perf-ab
trig-perf-ab: import ## N4: perf-judge with the native trig cr v libm, alternating, TRIG_AB_ROUNDS=3 (builder0) -> build/trig-perf-ab/
	tools/judge/trig_perf_ab.sh $(GODOT) $(SIM_HZ) $(BUILD_DIR)/trig-perf-ab

trig-info: ## N4: which trig this machine's Godot runs (cr = the builders' result; system = its own libm)
	@echo "TRIG glibc $(TRIG_GLIBC) | $(if $(TRIG_OLD_LIBM),older than 2.41,2.41+ (libm is CORE-MATH))| TRIG=$(TRIG) | LD_PRELOAD=$(or $(LD_PRELOAD),none) | sim-baseline key $(or $(SIM_BASELINE_KEY),glibc-$(TRIG_GLIBC))"

# Round 39 (stretch, the lead's question 2026-10-23: would a faster physics engine speed development?): what share of a
# simulation tick is the PHYSICS ENGINE. A tick's wall time (MATCH_RESULT real_seconds over the ticks: the match runner
# runs uncapped, startup excluded) = the scripts' _physics_process (SimProfile's whole tick) + the rest of Godot's frame,
# whose bulk headless is PhysicsServer3D's sync, query flush and step (Jolt). Physics queries made FROM scripts are inside
# the scripts' time: `tank/drive` (the motion model + move_and_slide) is reported beside, an upper bound on that part.
# PHYSICS_SHARE_SEEDS fights (CPU v CPU, condemned mirror, 5200 budget, TIME s each) -> build/physics-share/ + a table.
PHYSICS_SHARE_SEEDS ?= 3 7 11
physics-share: import native-for-check ## Stretch (round 39): the physics engine's share of a sim tick (frame wall v scripts; tank/drive beside) -> build/physics-share/
	@rm -rf $(BUILD_DIR)/physics-share; mkdir -p $(BUILD_DIR)/physics-share
	@for seed in $(PHYSICS_SHARE_SEEDS); do \
		$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . -- --match --elimination --control --sim-profile \
			--green-faction=condemned --rust-faction=condemned --budget=$(or $(BUDGET),5200) --time-limit=$(or $(TIME),120) \
			--seed=$$seed > $(BUILD_DIR)/physics-share/seed-$$seed.log 2>&1 || exit 1; \
	done
	@$(PYTHON) tools/judge/physics_share.py $(BUILD_DIR)/physics-share/seed-*.log

# Round 43 (native, CP43.0 stretch; `replay` is net.mk's relay replay): re-run a playtest from its recording, headless, and print how far the replay's crews are
# from his census (tests/replay/divergence.py; bar 3 m by default, the first two orders' crews, 20 s). The native library is
# built first: his match ran it, and the GDScript path is a different match after ~10 s (Status, round 43). The replay puts the
# recording's switches on its own command line (tests/replay_orders.gd); REPLAY_FLAGS adds an A/B switch (`--attack-shot=off`).
#   make replay-match RECORDING=_agents/streams/references/round42/playtest/2026-10-27T20-00-48-locks.jsonl.gz [REPLAY_SECONDS=49 CREWS=all]
REPLAY_MATCH_DIR := $(BUILD_DIR)/replay-match
.PHONY: replay-match
replay-match: native-fresh import ## Replay a match recording headless (RECORDING=file[.gz], REPLAY_SECONDS=20, CREWS=first2|all, REPLAY_FLAGS=...) and print the divergence table v his census
	@test -n "$(RECORDING)" || { echo 'usage: make replay-match RECORDING=build/recordings/X.jsonl[.gz] [REPLAY_SECONDS=20] [CREWS=first2|all] [REPLAY_FLAGS="--attack-shot=off"]'; exit 2; }
	@rm -rf $(REPLAY_MATCH_DIR) && mkdir -p $(REPLAY_MATCH_DIR)/out
	@case "$(RECORDING)" in *.gz) gzip -dc "$(RECORDING)" > $(REPLAY_MATCH_DIR)/his.jsonl;; *) cp "$(RECORDING)" $(REPLAY_MATCH_DIR)/his.jsonl;; esac
	@s=0; $(GODOT) --headless --fixed-fps 30 --path . --script res://tests/replay_orders.gd -- \
		--orders=$(CURDIR)/$(REPLAY_MATCH_DIR)/his.jsonl --seconds=$$(( $(or $(REPLAY_SECONDS),20) + 1 )) --record-dir=$(REPLAY_MATCH_DIR)/out \
		$(REPLAY_FLAGS) > $(REPLAY_MATCH_DIR)/replay.log 2>&1 || s=$$?; \
	grep -E '^REPLAY_(REEXEC|SETUP|SPAWN|ROSTER|NATIVE|SEED|CLICKS|FORMATIONS|DONE)|^NATIVE_EXEC' $(REPLAY_MATCH_DIR)/replay.log; \
	[ $$s -eq 0 ] || { echo "replay: godot exited $$s (log $(REPLAY_MATCH_DIR)/replay.log)"; exit $$s; }; \
	out=$$(ls $(REPLAY_MATCH_DIR)/out/*.jsonl | head -1); \
	test -n "$$out" || { echo "replay: no recording written (log $(REPLAY_MATCH_DIR)/replay.log)"; exit 1; }; \
	$(PYTHON) tests/replay/divergence.py $(REPLAY_MATCH_DIR)/his.jsonl $$out --seconds=$(or $(REPLAY_SECONDS),20) --crews=$(or $(CREWS),first2)

# Round 43 (native N5): his playtest in one command: (a) the match and recording_arrivals per order, (b) the camera at each hit
# and death (the `cam` rows; older recordings say they have none), (c) a 30 s replay-match of every crew with its divergence table
# (through make: the native library and, on an old glibc, the trig shim). Round 44 (N1): it PRINTS one screen he can paste (the
# match, one line per click, the off-screen count, the replay's verdict) and WRITES the full report to
# build/playtest-report/<recording>.txt and .html (HTML=<path> moves the page).
#   make playtest-report RECORDING=build/recordings/<his>.jsonl [HTML=build/playtest-report/report.html]
PLAYTEST_REPORT_DIR := $(BUILD_DIR)/playtest-report
.PHONY: playtest-report
playtest-report: ## His playtest on one screen (the full report to build/playtest-report/<recording>.txt + .html): clicks and arrivals, the camera at each hit/death, a 30 s replay (RECORDING=file[.gz], HTML=out.html)
	@test -n "$(RECORDING)" || { echo 'usage: make playtest-report RECORDING=build/recordings/X.jsonl[.gz] [HTML=build/playtest-report/report.html]'; exit 2; }
	@mkdir -p $(PLAYTEST_REPORT_DIR)
	@$(MAKE) --no-print-directory replay-match RECORDING="$(RECORDING)" REPLAY_SECONDS=30 CREWS=all > $(PLAYTEST_REPORT_DIR)/replay.txt 2>&1 || true
	@name=$$(basename "$(RECORDING)" .gz); name=$${name%.jsonl}; \
	$(PYTHON) tests/replay/playtest_report.py "$(RECORDING)" --replay $(PLAYTEST_REPORT_DIR)/replay.txt \
		--out $(PLAYTEST_REPORT_DIR)/$$name.txt $(if $(HTML),--html $(HTML))
