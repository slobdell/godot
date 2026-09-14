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

# ---- Player-hosted matches through the relay (N1) ------------------------------------------
# A headless player HOST (its own --demo tank + 2 bots, one per team so combat happens) opens a
# room on a local broker; clients join with the code it prints.
RELAY_SMOKE_HOST_FLAGS ?= --demo --bots=2

# Start a broker + host, wait for the room code in $$code. Recipe fragment (one shell).
define relay_host_up
	$(NODE) $(BROKER_DIR)/src/main.mjs --port=$(SMOKE_BROKER_PORT) $(1) > $(BUILD_DIR)/$(2)-broker.log 2>&1 & broker=$$!; \
	for i in $$(seq 1 50); do grep -q BROKER_LISTENING $(BUILD_DIR)/$(2)-broker.log && break; sleep 0.1; done; \
	$(GODOT) --headless --path . -- --host --relay=ws://127.0.0.1:$(SMOKE_BROKER_PORT) $(RELAY_SMOKE_HOST_FLAGS) > $(BUILD_DIR)/$(2)-host.log 2>&1 & host=$$!; \
	trap 'kill $$host $$broker 2>/dev/null' EXIT; \
	code=""; for i in $$(seq 1 150); do code=$$(grep -oP 'TANK_SQUAD_ROOM code=\K\w+' $(BUILD_DIR)/$(2)-host.log || true); [ -n "$$code" ] && break; sleep 0.2; done; \
	if [ -z "$$code" ]; then echo "host never opened a room:"; cat $(BUILD_DIR)/$(2)-host.log; exit 1; fi; \
	echo "host opened room $$code"
endef

# Run bot_client_check.gd clients in the background, one log each: $(call relay_client,NAME,FLAGS)
define relay_client
	$(GODOT) --headless --path . --script res://tests/net/bot_client_check.gd -- \
		--join=$$code --relay=ws://127.0.0.1:$(SMOKE_BROKER_PORT) $(2) > $(BUILD_DIR)/$(1).log 2>&1 & \
	pids="$$pids $$!"
endef

# Wait for the clients, show their verdicts, and fail on any client/host ERROR.
define relay_verdict
	status=0; for pid in $$pids; do wait $$pid || status=1; done; \
	grep -hE 'NET_CHECK|ERROR' $(foreach c,$(2),$(BUILD_DIR)/$(c).log) || true; \
	grep -qE 'ERROR' $(foreach c,$(2),$(BUILD_DIR)/$(c).log) && status=1; \
	grep -E 'joined|left|RELAY|destroyed' $(BUILD_DIR)/$(1)-host.log | head -20 || true; \
	grep -E 'ERROR' $(BUILD_DIR)/$(1)-host.log && status=1; \
	exit $$status
endef

relay-smoke: import $(BROKER_DEPS) ## Broker + headless player host (+2 bots) + 2 headless clients by room code; combat replicates
	mkdir -p $(BUILD_DIR)
	$(call relay_host_up,,relay-smoke); \
	pids=""; \
	$(call relay_client,relay-smoke-client1,--demo --expect-tanks=5 --expect-any-damage --timeout=60); \
	$(call relay_client,relay-smoke-client2,--demo --expect-tanks=5 --expect-any-damage --timeout=60); \
	$(call relay_verdict,relay-smoke,relay-smoke-client1 relay-smoke-client2)

# Mobile backgrounding / losing signal: one client's socket is cut for RELAY_DROP_SECONDS (default 10)
# and must resume its seat and keep playing; the other client must be unaffected.
RELAY_DROP_SECONDS ?= 10
relay-drop-smoke: import $(BROKER_DEPS) ## Relay: cut one client's socket for 10 s mid-match; it must resume its seat and keep playing
	mkdir -p $(BUILD_DIR)
	$(call relay_host_up,,relay-drop-smoke); \
	pids=""; \
	$(call relay_client,relay-drop-smoke-dropper,--demo --expect-tanks=4 --drop-after=4 --drop-seconds=$(RELAY_DROP_SECONDS) --timeout=75); \
	$(call relay_client,relay-drop-smoke-steady,--demo --expect-tanks=4 --min-travel=20 --timeout=40); \
	$(call relay_verdict,relay-drop-smoke,relay-drop-smoke-dropper relay-drop-smoke-steady)

# ---- Browsers through the relay ------------------------------------------------------------
# Humans: `make play-relay`, open http://localhost:8060/?host (add &demo&bots=2 to taste), read the
# room code off the HUD, then http://localhost:8060/?join=CODE in other tabs/devices.
play-relay: export-web $(BROKER_DEPS) ## Broker + web page: ?host opens a room in YOUR browser, ?join=CODE joins it
	mkdir -p $(BUILD_DIR)
	$(NODE) $(BROKER_DIR)/src/main.mjs --port=$(BROKER_PORT) --host=127.0.0.1 > $(BUILD_DIR)/play-relay-broker.log 2>&1 & broker=$$!; \
	trap 'kill $$broker 2>/dev/null' EXIT; \
	echo "broker log: $(BUILD_DIR)/play-relay-broker.log"; \
	echo "Host:  http://localhost:$(WEB_PORT)/?host      Join: http://localhost:$(WEB_PORT)/?join=CODE"; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(WEB_PORT) $(WEB_HOST) $(NET_PORT) $(BROKER_PORT)

# A browser PLAYER joins a headless player host; the screenshot should show remote tanks.
web-relay-smoke: export-web import $(BROKER_DEPS) $(WEB_SMOKE_DEPS) ## Browser joins a headless player host by room code via /relay; screenshot
	mkdir -p $(BUILD_DIR)/screenshots
	$(call relay_host_up,,web-relay-smoke); \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 $(SMOKE_NET_PORT) $(SMOKE_BROKER_PORT) >/dev/null 2>&1 & web=$$!; \
	trap 'kill $$host $$broker $$web 2>/dev/null' EXIT; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs "http://127.0.0.1:$(SMOKE_PORT)/?join=$$code" \
		$(BUILD_DIR)/screenshots/web-relay.png 12 TANK_SQUAD_SPAWNED; \
	grep -E 'joined' $(BUILD_DIR)/web-relay-smoke-host.log; \
	! grep -E 'ERROR' $(BUILD_DIR)/web-relay-smoke-host.log

# A BROWSER hosts (the phone-as-host case, in wasm): a headless client joins its room and must see
# tanks move and combat replicate from the browser's simulation.
WEB_HOST_SMOKE_FLAGS ?= demo&bots=2
web-host-smoke: export-web import $(BROKER_DEPS) $(WEB_SMOKE_DEPS) ## Browser HOSTS via /relay; a headless client joins and checks the wasm host's simulation
	mkdir -p $(BUILD_DIR)/screenshots
	$(NODE) $(BROKER_DIR)/src/main.mjs --port=$(SMOKE_BROKER_PORT) > $(BUILD_DIR)/web-host-smoke-broker.log 2>&1 & broker=$$!; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 $(SMOKE_NET_PORT) $(SMOKE_BROKER_PORT) >/dev/null 2>&1 & web=$$!; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs "http://127.0.0.1:$(SMOKE_PORT)/?host&$(WEB_HOST_SMOKE_FLAGS)" \
		$(BUILD_DIR)/screenshots/web-host.png 40 TANK_SQUAD_ROOM > $(BUILD_DIR)/web-host-smoke-browser.log 2>&1 & browser=$$!; \
	trap 'kill $$broker $$web $$browser 2>/dev/null' EXIT; \
	code=""; for i in $$(seq 1 450); do code=$$(grep -oP 'TANK_SQUAD_ROOM code=\K\w+' $(BUILD_DIR)/web-host-smoke-browser.log || true); [ -n "$$code" ] && break; sleep 0.2; done; \
	if [ -z "$$code" ]; then echo "the browser never opened a room:"; cat $(BUILD_DIR)/web-host-smoke-browser.log; exit 1; fi; \
	echo "browser opened room $$code"; \
	$(GODOT) --headless --path . --script res://tests/net/bot_client_check.gd -- \
		--join=$$code --relay=ws://127.0.0.1:$(SMOKE_BROKER_PORT) --demo --expect-tanks=4 --expect-any-damage --timeout=35 \
		> $(BUILD_DIR)/web-host-smoke-client.log 2>&1; status=$$?; \
	grep -E 'NET_CHECK|ERROR' $(BUILD_DIR)/web-host-smoke-client.log || true; \
	grep -qE 'ERROR' $(BUILD_DIR)/web-host-smoke-client.log && status=1; \
	wait $$browser || status=1; \
	grep -E 'joined|SMOKE|RELAY' $(BUILD_DIR)/web-host-smoke-browser.log | tail -5; \
	exit $$status
