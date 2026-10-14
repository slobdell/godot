# ---- planner (round 30): a local motion planner for long wheeled hulls, isolated this round (C30.4) -----------------
# Owner: the planner stream (_agents/streams/planner.md). Nothing here is reached in play. Every Godot run goes to
# builder0 (`make remote LIGHT=1 T=planner-...`: one process, the light lane, one at a time).

# P0 reproductions on main's code, each the exact command the problem statement cites
# (_agents/streams/references/round30/planner/problem.md). Logs: build/planner/.

# The wedge (round 29 M4's trace): the War Rig squad driven across the Terminus, seed 9, the GDScript plant and brains
# (--brains-off=native), every rig's drive traced per tick (DRIVE_TRACE: tank.gd prints wanted v moved) and the turn
# census logged. A pinned rig reads a speed with no displacement.
PLANNER_WEDGE_SEED ?= 9
PLANNER_WEDGE_TRACE ?= Green_S0_1,Green_S0_2,Green_S0_3,Green_S0_4
.PHONY: planner-repro-wedge
planner-repro-wedge: import ## planner P0: the wedged rig reproduced (Terminus rigs drive, seed PLANNER_WEDGE_SEED, DRIVE_TRACE on every rig, --turn-log) -> build/planner/wedge-<seed>.log
	@mkdir -p $(BUILD_DIR)/planner
	@echo ">> planner-repro-wedge on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | seed $(PLANNER_WEDGE_SEED)"
	@DRIVE_TRACE=$(PLANNER_WEDGE_TRACE) $(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/terminus_drive.gd -- \
		--squad=rigs --seed=$(PLANNER_WEDGE_SEED) --arena=terminus --leg-time=90 --turn-log --brains-off=native $(PLANNER_FLAGS) \
		> $(BUILD_DIR)/planner/wedge-$(PLANNER_WEDGE_SEED).log 2>&1 || true
	@grep -E "^NAV_DRIVE_LEG|^NAV_DRIVE |SCRIPT ERROR|control FAILED" $(BUILD_DIR)/planner/wedge-$(PLANNER_WEDGE_SEED).log | cut -c1-400 || true
	@$(PYTHON) tests/planner/wedge_table.py $(BUILD_DIR)/planner/wedge-$(PLANNER_WEDGE_SEED).log || true

# The creep (round 29 M2's base census): the mixed squad across the Terminus, seed PLANNER_CREEP_SEED, every turn
# episode logged with its cause (creep / kturn / circle / press / ...) and what was in the way.
PLANNER_CREEP_SEED ?= 1
.PHONY: planner-repro-creep
planner-repro-creep: import ## planner P0: the creep reproduced (Terminus mixed drive, seed PLANNER_CREEP_SEED, --turn-log) -> build/planner/creep-<seed>.log + the census table
	@mkdir -p $(BUILD_DIR)/planner
	@echo ">> planner-repro-creep on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | seed $(PLANNER_CREEP_SEED)"
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/nav/terminus_drive.gd -- \
		--squad=mixed --seed=$(PLANNER_CREEP_SEED) --arena=terminus --leg-time=90 --turn-log --brains-off=native $(PLANNER_FLAGS) \
		> $(BUILD_DIR)/planner/creep-$(PLANNER_CREEP_SEED).log 2>&1 || true
	@grep -E "^NAV_DRIVE_LEG|^NAV_DRIVE |SCRIPT ERROR|control FAILED" $(BUILD_DIR)/planner/creep-$(PLANNER_CREEP_SEED).log | cut -c1-400 || true
	@$(PYTHON) tests/manoeuvre/census_table.py $(BUILD_DIR)/planner/creep-$(PLANNER_CREEP_SEED).log || true

# The boxed-in face (F3) and the arrival gate (F4) on main's code, in a TacticsLab (tests/planner/boxed_face_probe.gd).
PLANNER_PROBE_CASE ?= all
.PHONY: planner-repro-face
planner-repro-face: import ## planner P0: four War Rigs in a line abreast each told to face east, and a car's 180-degree arrival through today's gate (PLANNER_PROBE_CASE=face|gate|all, PLANNER_FLAGS) -> build/planner/face.log
	@mkdir -p $(BUILD_DIR)/planner
	@echo ">> planner-repro-face on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | case $(PLANNER_PROBE_CASE)"
	@$(GODOT) --headless --fixed-fps $(SIM_HZ) --path . --script res://tests/planner/boxed_face_probe.gd -- \
		--case=$(PLANNER_PROBE_CASE) --brains-off=native $(PLANNER_FLAGS) > $(BUILD_DIR)/planner/face.log 2>&1 || true
	@grep -E "PLANNER_PROBE_DONE|SCRIPT ERROR" $(BUILD_DIR)/planner/face.log | cut -c1-900 || true

# P3: the lab scene (needs a display: builder0's). One real hull on a real arena cut, the planner's legs driven by
# PlannerExecutor beside the same hull under today's code; frames + PLANNER_LAB rows -> build/planner-lab/.
# PLANNER_FIXTURES=turnround,slot180,tjunction,yardcorner PLANNER_ARMS=planner,today PLANNER_SECONDS=60
# MOVIE=path.mp4 records the whole run (renders slower than real time; ffmpeg makes the .mp4 from Godot's .avi).
PLANNER_LAB_DIR ?= $(BUILD_DIR)/planner-lab
# Defaults with ?=, not $(or ...): make's `or` splits on the commas and keeps only the first fixture (the first run).
PLANNER_FIXTURES ?= turnround,slot180,tjunction
PLANNER_ARMS ?= planner,today
PLANNER_SECONDS ?= 60
.PHONY: planner-lab
planner-lab: import ## planner P3: the planner v today's drive on real arena cuts, frames + rows -> build/planner-lab/ (needs a display: make remote LIGHT=1 T=planner-lab; PLANNER_FIXTURES, PLANNER_ARMS, PLANNER_SECONDS, MOVIE=out.mp4)
	@rm -rf $(PLANNER_LAB_DIR) && mkdir -p $(PLANNER_LAB_DIR)
	@echo ">> planner-lab on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown})"
	@movie="$(MOVIE)"; record=""; avi=""; if [ -n "$$movie" ]; then case "$$movie" in /*) ;; *) movie="$(CURDIR)/$$movie" ;; esac; \
		avi="$${movie%.*}.avi"; record="--write-movie $$avi"; fi; \
	timeout 1500 $(GODOT) --path . --fixed-fps $(SIM_HZ) --resolution 1280x720 $$record --script res://tests/planner/planner_lab.gd -- \
		--fixtures=$(PLANNER_FIXTURES) --arms=$(PLANNER_ARMS) \
		--seconds=$(PLANNER_SECONDS) --out=res://$(PLANNER_LAB_DIR) $(if $(MOVIE),--movie=1) --brains-off=native $(PLANNER_FLAGS) \
		> $(PLANNER_LAB_DIR)/run.log 2>&1 || true; \
	grep -E "PLANNER_LAB |PLANNER_LAB_PLAN|PLANNER_LAB_SHOT|SCRIPT ERROR" $(PLANNER_LAB_DIR)/run.log | cut -c1-600 || true; \
	grep -q PLANNER_LAB_DONE $(PLANNER_LAB_DIR)/run.log || echo ">> planner-lab: did not finish"; \
	if [ -n "$$movie" ] && command -v ffmpeg >/dev/null && [ -f "$$avi" ]; then ffmpeg -loglevel error -y -i "$$avi" -c:v libx264 -preset slow -crf 18 \
		-pix_fmt yuv420p -movflags +faststart "$$movie" && rm -f "$$avi" && echo "PLANNER_LAB_MOVIE $$movie"; elif [ -n "$$avi" ]; then echo "PLANNER_LAB_MOVIE $$avi"; fi
