# Round 47 (route stream): which way a crew goes. The `Pathing.reroute` seam (C47.3), the route trace of his recordings (R1),
# and the route rule's bar (R3).

# R1: his match replayed (as replay-match: his switches, his rules stamp, the native library) with a ROUTE_TRACE line each
# time a named crew's order, drive goal, navmesh route or element route changes (tests/route/route_replay.gd), its length
# v the shortest drivable to the same goal and to its target. Log: build/route-trace/replay.log; the rows: route.jsonl.
#   make route-trace RECORDING=references/round46/playtest/2026-10-30T15-49-20-locks.jsonl ROUTE_CREWS=Green_Hunters_4 REPLAY_SECONDS=80
ROUTE_TRACE_DIR := $(BUILD_DIR)/route-trace
.PHONY: route-trace
route-trace: native-fresh import ## Replay a recording with a ROUTE_TRACE of named crews (RECORDING=, ROUTE_CREWS=a,b|all, REPLAY_SECONDS=80, STAGE_TICK=, REPLAY_FLAGS=)
	@test -n "$(RECORDING)" -a -n "$(ROUTE_CREWS)" || { echo 'usage: make route-trace RECORDING=X.jsonl[.gz] ROUTE_CREWS=Green_Hunters_4 [REPLAY_SECONDS=80] [REPLAY_FLAGS=...]'; exit 2; }
	@rm -rf $(ROUTE_TRACE_DIR) && mkdir -p $(ROUTE_TRACE_DIR)/out
	@case "$(RECORDING)" in *.gz) gzip -dc "$(RECORDING)" > $(ROUTE_TRACE_DIR)/his.jsonl;; *) cp "$(RECORDING)" $(ROUTE_TRACE_DIR)/his.jsonl;; esac
	@authority=$$($(PYTHON) tests/replay/authority.py $(ROUTE_TRACE_DIR)/his.jsonl auto); flags='$(REPLAY_FLAGS)'; \
	case "$$flags" in *--player-authority*) ;; *) if [ "$$authority" = off ]; then flags="$$flags --player-authority=off"; fi;; esac; \
	rules=$$($(PYTHON) tests/replay/rules.py $(ROUTE_TRACE_DIR)/his.jsonl "$$flags"); flags="$$flags $$rules"; \
	s=0; $(GODOT) --headless --fixed-fps 30 --path . --script res://tests/route/route_replay.gd -- \
		--orders=$(CURDIR)/$(ROUTE_TRACE_DIR)/his.jsonl --seconds=$(or $(REPLAY_SECONDS),80) --record-dir=$(ROUTE_TRACE_DIR)/out \
		--route-trace=$(ROUTE_CREWS) --route-trace-every=$(or $(ROUTE_EVERY),30) $(if $(STAGE_TICK),--stage-tick=$(STAGE_TICK)) $$flags > $(ROUTE_TRACE_DIR)/replay.log 2>&1 || s=$$?; \
	grep -E '^REPLAY_(REEXEC|SETUP|SPAWN|ROSTER|NATIVE|SEED|DONE)|^ROUTE_STAGE' $(ROUTE_TRACE_DIR)/replay.log; \
	grep -E '^ROUTE_(TRACE|POSE) ' $(ROUTE_TRACE_DIR)/replay.log | sed -E 's/^ROUTE_(TRACE|POSE) //' > $(ROUTE_TRACE_DIR)/route.jsonl; \
	echo "route-trace: $$(grep -c '^ROUTE_TRACE ' $(ROUTE_TRACE_DIR)/replay.log) route changes, $$(grep -c '^ROUTE_POSE ' $(ROUTE_TRACE_DIR)/replay.log) poses -> $(ROUTE_TRACE_DIR)/route.jsonl"; \
	[ $$s -eq 0 ] || { echo "route-trace: godot exited $$s (log $(ROUTE_TRACE_DIR)/replay.log)"; exit $$s; }; \
	if grep -q '^REPLAY_NATIVE_MISMATCH' $(ROUTE_TRACE_DIR)/replay.log && [ "$(NATIVE)" != off ]; then echo "route-trace: FAILED: not his match's native path"; exit 3; fi
