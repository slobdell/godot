# Map kit (round 47, mapkit stream): the cheap pieces (_agents/arenas.md *The cheap-piece map kit backlog*) and the
# blast doors. Owner: mapkit (_agents/streams/mapkit.md).

.PHONY: mapkit-looks

LOOKS_SCREEN ?= 1920x1080
LOOKS_DIR ?= $(BUILD_DIR)/mapkit-looks

# Needs a display. builder3 runs Xorg on :1 (not Xwayland, so remote.sh exports no DISPLAY there): pass it inside the
# quotes, make remote T="mapkit-looks DISPLAY=:1 XAUTHORITY=/run/user/1000/gdm/Xauthority".
mapkit-looks: import ## Mapkit P1: every candidate look (doors shut/open, sight screens, overpass, tank traps, pipes, crane) at his camera beside a dozer -> build/mapkit-looks/looks-*.png [ONLY=door_a_shut,traps_b YAW=30 LOOKS_SCREEN=1920x1080]
	@mkdir -p $(LOOKS_DIR)
	timeout 180 $(GODOT) --path . --resolution $(LOOKS_SCREEN) res://tests/mapkit/looks_gallery.tscn -- \
		--shots-dir=$(abspath $(LOOKS_DIR)) $(if $(ONLY),--only=$(ONLY)) $(if $(YAW),--yaw=$(YAW))
