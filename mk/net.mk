# Multiplayer server/client, network smoke tests, agent bridge
# Owner: netcode (see _agents/workstreams.md). Included by the root Makefile.

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

# ---- Broker (N0: lobbies + relay; see _agents/streams/netcode.md) ----------------------
# Ports derive from the per-worktree NET ports so parallel worktrees never collide.
BROKER_DIR        := server/broker
BROKER_DEPS       := $(BROKER_DIR)/node_modules/.package-lock.json
BROKER_PORT       ?= $(shell echo $$(( $(NET_PORT) + 5 )))
SMOKE_BROKER_PORT ?= $(shell echo $$(( $(SMOKE_NET_PORT) + 5 )))
BROKER_HOST       ?= 127.0.0.1

$(BROKER_DEPS): $(BROKER_DIR)/package.json $(BROKER_DIR)/package-lock.json
	cd $(BROKER_DIR) && $(NPM) ci --no-audit --no-fund
	touch $@

broker-bootstrap: $(BROKER_DEPS) ## Install the broker's pinned Node dependencies (server/broker)

broker: $(BROKER_DEPS) ## Run the match broker on ws://127.0.0.1:9085 (BROKER_PORT, BROKER_HOST=0.0.0.0 for LAN)
	$(NODE) $(BROKER_DIR)/src/main.mjs --port=$(BROKER_PORT) --host=$(BROKER_HOST)

broker-test: $(BROKER_DEPS) ## Broker unit tests (node --test)
	cd $(BROKER_DIR) && $(NODE) --test test/*.test.mjs

broker-smoke: $(BROKER_DEPS) ## Real broker process + scripted host/players: relay, drop + resume, host leaves
	mkdir -p $(BUILD_DIR)
	$(NODE) $(BROKER_DIR)/src/main.mjs --port=$(SMOKE_BROKER_PORT) --heartbeat-ms=500 > $(BUILD_DIR)/broker-smoke.log 2>&1 & broker=$$!; \
	trap 'kill $$broker 2>/dev/null' EXIT; \
	$(NODE) $(BROKER_DIR)/smoke.mjs $(SMOKE_BROKER_PORT)
