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
