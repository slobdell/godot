# Web and server exports, browser checks
# Owner: netcode (exports) + look-and-feel (web presentation) (see _agents/workstreams.md). Included by the root Makefile.

# ---- Exports ------------------------------------------------------------------

export-web: import $(TEMPLATES_OK) ## Export the WebAssembly build to build/web
	mkdir -p $(BUILD_DIR)/web
	$(GODOT) --headless --path . --export-release "Web" $(BUILD_DIR)/web/index.html

serve-web: export-web ## Serve the web build at http://localhost:8060 (?connect joins the local server via /ws; ?demo)
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(WEB_PORT) $(WEB_HOST) $(NET_PORT)

play: export-web ## One command: game server (BOTS=N) + web page. Open http://localhost:8060/?connect
	$(GODOT) --headless --path . -- --server=$(NET_PORT) --bots=$(BOTS) > $(BUILD_DIR)/play-server.log 2>&1 & server=$$!; \
	trap 'kill $$server 2>/dev/null' EXIT; \
	echo "game server log: $(BUILD_DIR)/play-server.log"; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(WEB_PORT) $(WEB_HOST) $(NET_PORT)

web-smoke: export-web $(WEB_SMOKE_DEPS) ## Boot the web export in headless Chrome, screenshot it, fail on errors
	mkdir -p $(BUILD_DIR)/screenshots
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 >/dev/null 2>&1 & server=$$!; \
	trap 'kill $$server' EXIT; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs "http://127.0.0.1:$(SMOKE_PORT)/?demo" $(BUILD_DIR)/screenshots/web.png

# The browser client stands still; a server bot drives over from the far base and
# attacks it, so the screenshot shows a REMOTE tank, shells, and damage rendered in
# the browser. Settle time is tuned so the bot has arrived (~18 s on the 240 m arena).
web-net-smoke: export-web $(WEB_SMOKE_DEPS) ## Browser client (via the /ws proxy) vs a server bot; screenshot mid-fight
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --headless --path . -- --server=$(SMOKE_NET_PORT) --bots=1 > $(BUILD_DIR)/web-net-smoke-server.log 2>&1 & server=$$!; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 $(SMOKE_NET_PORT) >/dev/null 2>&1 & web=$$!; \
	trap 'kill $$server $$web 2>/dev/null' EXIT; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs \
		"http://127.0.0.1:$(SMOKE_PORT)/?connect" \
		$(BUILD_DIR)/screenshots/web-net.png 18 TANK_SQUAD_SPAWNED; \
	! grep -E 'ERROR' $(BUILD_DIR)/web-net-smoke-server.log

$(WEB_SMOKE_DEPS): $(WEB_SMOKE_DIR)/package.json
	cd $(WEB_SMOKE_DIR) && $(NPM) install --no-audit --no-fund
	touch $@

export-server: import $(TEMPLATES_OK) ## Export the headless Linux server binary to build/server
	mkdir -p $(BUILD_DIR)/server
	$(GODOT) --headless --path . --export-release "Linux Server" $(BUILD_DIR)/server/tank_squad_server.x86_64
