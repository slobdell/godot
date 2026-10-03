# Web and server exports, browser checks
# Owner: netcode (exports) + look-and-feel (web presentation) (see _agents/workstreams.md). Included by the root Makefile.

# ---- Exports ------------------------------------------------------------------

# Round 17 (ship W2, option c): WEB_VOICE=1 puts the announcer's clips beside the page (build/web/voice/: the manifest and
# 3,112 loose Ogg files, ~77 MB on the host, fetched one by one on first use by a game opened with ?web-voice=fetch).
# Without it the folder is removed, so a build never ships a voice by accident (the pack size is the lead's call).
export-web: import $(TEMPLATES_OK) ## Export the WebAssembly build to build/web (WEB_VOICE=1: the clips beside it for ?web-voice=fetch)
	mkdir -p $(BUILD_DIR)/web
	$(GODOT) --headless --path . --export-release "Web" $(BUILD_DIR)/web/index.html
	$(if $(WEB_VOICE),rsync -a --delete --exclude=.gdignore --exclude=README.md assets/announcer/clips/ $(BUILD_DIR)/web/voice/ && echo ">> web voice: $$(du -sm $(BUILD_DIR)/web/voice | cut -f1) MB in $$(find $(BUILD_DIR)/web/voice -name '*.ogg' | wc -l) clips beside the page",rm -rf $(BUILD_DIR)/web/voice)

serve-web: export-web ## Serve the web build at http://localhost:8060 (?connect joins the local server via /ws; ?demo)
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(WEB_PORT) $(WEB_HOST) $(NET_PORT)

play: export-web ## One command: game server (BOTS=N) + web page. Open http://localhost:8060/?connect
	$(GODOT) --headless --path . -- --server=$(NET_PORT) --bots=$(BOTS) > $(BUILD_DIR)/play-server.log 2>&1 & server=$$!; \
	trap 'kill $$server 2>/dev/null' EXIT; \
	echo "game server log: $(BUILD_DIR)/play-server.log"; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(WEB_PORT) $(WEB_HOST) $(NET_PORT)

web-smoke: export-web $(WEB_SMOKE_DEPS) ## Boot the web export in headless Chrome, screenshot it, fail on errors (and check the pack: export-guard --pack)
	mkdir -p $(BUILD_DIR)/screenshots
	$(PYTHON) tools/web_pack/export_guard.py --pack $(BUILD_DIR)/web/index.pck --pack-preset Web
	@echo ">> web pack: $$(( $$(stat -c %s $(BUILD_DIR)/web/index.pck) / 1000000 )) MB pck + $$(( $$(stat -c %s $(BUILD_DIR)/web/index.wasm) / 1000000 )) MB wasm (round 17 W2: the pack's size is the lead's call)"
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

# ---- Lesson 239's class, statically (ship W3, round 17) -------------------------------------------------------
# Every file the game reaches for (every game script, every res:// literal, every scene's ext_resource) against every
# preset's filters, the way Godot's exporter decides; a drop not declared in tools/web_pack/export_optional.json (with
# the code that copes) fails. No Godot, ~0.5 s. web-smoke runs it again with --pack: the prediction checked against
# the real pack, and nothing under _agents/ tests/ build/ in it.
export-guard: ## Every file the game reaches for is in every export preset's pack, or declared optional with its fallback (static, ~0.5 s)
	$(PYTHON) tools/web_pack/export_guard.py

# ---- What the browser player gets (ship W1, round 17) --------------------------------------------------------
# An INSTRUMENT, not a gate: tools/web_smoke/observe.mjs plays a URL in headless Chrome and writes what it saw and
# HEARD (an AnalyserNode on WebAudio's destination, sampled every 250 ms) to build/web-observe/<name>/report.json,
# console.txt and shot_<s>.png. `web-observe-w1` is round 17's set: the faction menu, one match per new faction, and
# the title. MBPS=N throttles the first load (CDP) to time it on a stated connection.
OBS_QUERY ?= skirmish
OBS_NAME  ?= adhoc
OBS_ARGS  ?= --seconds=40 --shots=5
web-observe: export-web $(WEB_SMOKE_DEPS) ## Play ?OBS_QUERY in headless Chrome: screenshots, console, an audio dBFS timeline -> build/web-observe/OBS_NAME/ (MBPS=N throttles)
	@mkdir -p $(BUILD_DIR)/web-observe
	@$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 >/dev/null 2>&1 & server=$$!; \
	trap 'kill $$server' EXIT; \
	echo ">> web-observe $(OBS_NAME): ?$(OBS_QUERY) on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown}) | load $$(cut -d' ' -f1-3 /proc/loadavg) | pck $$(stat -c %s $(BUILD_DIR)/web/index.pck) bytes"; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/observe.mjs "http://127.0.0.1:$(SMOKE_PORT)/?$(OBS_QUERY)" \
		$(BUILD_DIR)/web-observe/$(OBS_NAME) $(OBS_ARGS) $(if $(MBPS),--mbps=$(MBPS))

web-observe-w1: export-web $(WEB_SMOKE_DEPS) ## Round 17 W1: the faction menu, a match per new faction to first contact, the title -> build/web-observe/*
	$(MAKE) --no-print-directory -o export-web web-observe OBS_NAME=bare OBS_QUERY='' OBS_ARGS='--seconds=20 --shots=10'
	$(MAKE) --no-print-directory -o export-web web-observe OBS_NAME=menu OBS_QUERY='skirmish' OBS_ARGS='--seconds=10 --shots=5'
	$(MAKE) --no-print-directory -o export-web web-observe OBS_NAME=title OBS_QUERY='title' OBS_ARGS='--seconds=20 --shots=10'
	$(MAKE) --no-print-directory -o export-web web-observe OBS_NAME=garage OBS_QUERY='garage' OBS_ARGS='--seconds=10 --shots=5'
	for f in gangs law syndicate condemned; do \
		$(MAKE) --no-print-directory -o export-web web-observe OBS_NAME=match_$$f \
			OBS_QUERY="skirmish&player-faction=$$f&enemy-faction=condemned&seed=7&arena=yard" \
			OBS_ARGS='--seconds=90 --shots=10 --keys=Space@3' || exit 1; \
	done
	$(if $(WEB_VOICE),$(MAKE) --no-print-directory -o export-web web-observe OBS_NAME=match_voice_fetch \
		OBS_QUERY="skirmish&player-faction=gangs&enemy-faction=condemned&seed=7&arena=yard&web-voice=fetch" \
		OBS_ARGS='--seconds=90 --shots=10 --keys=Space@3')
