# Web and server exports, browser checks
# Owner: netcode (exports) + look-and-feel (web presentation) (see _agents/workstreams.md). Included by the root Makefile.

# ---- Exports ------------------------------------------------------------------

# Round 17 (ship W2): the announcer's clips beside the page, build/web/voice/ (the manifest and 3,112 loose Ogg files),
# fetched one by one on first use: the lead's Q1 tap (D) and Q2 tap (24 kbit/s). They are re-encoded from the
# as-recorded clips by tools/web_pack/voice_web.py into build/voice-24k/ (incremental: minutes once, then seconds;
# not copied back by make remote), 61.4 MB on the host. WEB_VOICE=0 leaves the voice out.
# The voice's manifest rides IN the main pack (VoiceFetch.PACKED_MANIFEST; git-ignored copy, refreshed each export).
export-web: import $(TEMPLATES_OK) ## Export the WebAssembly build to build/web (the voice at 24 kbit/s beside it always: the lead's Q1/Q2 taps, WEB_VOICE=0 leaves it out; packs/factions.pck always: the lead's Q3 tap; WEB_PACKS=0 leaves it out)
	mkdir -p $(BUILD_DIR)/web
	$(if $(filter 0,$(WEB_VOICE)),rm -f assets/announcer/voice_manifest.json,cp assets/announcer/clips/manifest.json assets/announcer/voice_manifest.json)
	$(GODOT) --headless --path . --export-release "Web" $(BUILD_DIR)/web/index.html
	$(if $(filter 0,$(WEB_PACKS)),rm -rf $(BUILD_DIR)/web/packs && mkdir -p $(BUILD_DIR)/web/packs && echo '{}' > $(BUILD_DIR)/web/packs/packs.json,$(MAKE) --no-print-directory -o export-web export-web-packs)
	$(if $(filter 0,$(WEB_VOICE)),rm -rf $(BUILD_DIR)/web/voice,$(PYTHON) tools/web_pack/voice_web.py assets/announcer/clips $(BUILD_DIR)/voice-24k --kbps 24 --rate 22050 && rsync -a --delete $(BUILD_DIR)/voice-24k/ $(BUILD_DIR)/web/voice/ && echo ">> web voice: $$(du -sm $(BUILD_DIR)/web/voice | cut -f1) MB in $$(find $(BUILD_DIR)/web/voice -name '*.ogg' | wc -l) clips at 24 kbit/s beside the page")

# Round 17 (ship W2): the factions' art as a second pack beside the page (the "Web Factions" preset, a PATCH against
# build/web/index.pck: only what the main pack lacks) and packs/packs.json (file, bytes, md5) for WebPacks.
# WEB_PACKS=0 writes an EMPTY packs.json (`{}`): the game then logs `WEB_PACK FAILED: factions is not in packs.json`
# instead of a 404, which every web smoke fails as a console error (round 17: it hid web-host-smoke's real failure).
export-web-packs: import $(TEMPLATES_OK) ## The browser's second pack: build/web/packs/factions.pck (+ packs.json); needs export-web first
	mkdir -p $(BUILD_DIR)/web/packs
	$(GODOT) --headless --path . --export-patch "Web Factions" $(BUILD_DIR)/web/packs/factions.pck > $(BUILD_DIR)/web-packs-export.log 2>&1
	$(PYTHON) -c "import hashlib,json,os,sys; d=sys.argv[1]; f='factions.pck'; b=open(os.path.join(d,f),'rb').read(); json.dump({'factions': {'file': f, 'bytes': len(b), 'md5': hashlib.md5(b).hexdigest()}}, open(os.path.join(d,'packs.json'),'w'), indent=1)" $(BUILD_DIR)/web/packs
	@echo ">> web packs: factions.pck $$(( $$(stat -c %s $(BUILD_DIR)/web/packs/factions.pck) / 1000000 )) MB beside the page (main pack $$(( $$(stat -c %s $(BUILD_DIR)/web/index.pck) / 1000000 )) MB)"

serve-web: export-web ## Serve the web build at http://localhost:8060 (?connect joins the local server via /ws; ?demo)
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(WEB_PORT) $(WEB_HOST) $(NET_PORT)

play: export-web ## One command: game server (BOTS=N) + web page. Open http://localhost:8060/?connect
	$(GODOT) --headless --path . -- --server=$(NET_PORT) --bots=$(BOTS) > $(BUILD_DIR)/play-server.log 2>&1 & server=$$!; \
	trap 'kill $$server 2>/dev/null || true' EXIT; \
	echo "game server log: $(BUILD_DIR)/play-server.log"; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(WEB_PORT) $(WEB_HOST) $(NET_PORT)

web-smoke: export-web $(WEB_SMOKE_DEPS) ## Boot the web export in headless Chrome, screenshot it, fail on errors (and check the pack: export-guard --pack)
	mkdir -p $(BUILD_DIR)/screenshots
	$(PYTHON) tools/web_pack/export_guard.py --pack $(BUILD_DIR)/web/index.pck --pack-preset Web
	@echo ">> web pack: $$(( $$(stat -c %s $(BUILD_DIR)/web/index.pck) / 1000000 )) MB pck + $$(( $$(stat -c %s $(BUILD_DIR)/web/index.wasm) / 1000000 )) MB wasm (round 17 W2: the pack's size is the lead's call)"
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 >/dev/null 2>&1 & server=$$!; \
	trap 'kill $$server || true' EXIT; \
	CHROME=$(CHROME) $(NODE) $(WEB_SMOKE_DIR)/smoke.mjs "http://127.0.0.1:$(SMOKE_PORT)/?demo" $(BUILD_DIR)/screenshots/web.png
	@# Round 17 (ship W3): and a scripted MATCH, judged like a player would notice (web-match-smoke). In this recipe, not
	@# beside it in check, because two targets exporting build/web at once would race.
	$(MAKE) --no-print-directory -o export-web web-match-smoke

# The browser client stands still; a server bot drives over from the far base and
# attacks it, so the screenshot shows a REMOTE tank, shells, and damage rendered in
# the browser. Settle time is tuned so the bot has arrived (~18 s on the 240 m arena).
web-net-smoke: export-web $(WEB_SMOKE_DEPS) ## Browser client (via the /ws proxy) vs a server bot; screenshot mid-fight
	mkdir -p $(BUILD_DIR)/screenshots
	$(GODOT) --headless --path . -- --server=$(SMOKE_NET_PORT) --bots=1 > $(BUILD_DIR)/web-net-smoke-server.log 2>&1 & server=$$!; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 $(SMOKE_NET_PORT) >/dev/null 2>&1 & web=$$!; \
	trap 'kill $$server $$web 2>/dev/null || true' EXIT; \
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

# ---- A browser MATCH, judged like a player would notice (ship W3, round 17) ----------------------------------
# web-smoke loads ?demo and looks at nothing a player hears. This plays a scripted skirmish (no planning pause) in
# headless Chrome with the audio tap and fails on: a console error or failed request, a soundtrack with no tracks, a
# page that never made a sound above -60 dBFS, and a booth that is not in the state tools/web_pack/web_expect.json
# declares (subtitles today; WEB_VOICE=1 also plays the ?web-voice=fetch build and requires spoken lines).
WEB_MATCH_QUERY := skirmish&scripted&player-faction=gangs&enemy-faction=law&seed=7&arena=yard
WEB_MATCH_ARGS  := --seconds=$(or $(WEB_MATCH_SECONDS),45) --shots=15
web-match-smoke: export-web $(WEB_SMOKE_DEPS) ## A scripted browser skirmish: boots, music found, sound HEARD (WebAudio tap), booth as web_expect.json declares (WEB_VOICE=1: also the fetched voice)
	$(MAKE) --no-print-directory -o export-web web-observe OBS_NAME=match_smoke OBS_QUERY='$(WEB_MATCH_QUERY)' OBS_ARGS='$(WEB_MATCH_ARGS)'
	$(PYTHON) tools/web_smoke/assert_match.py $(BUILD_DIR)/web-observe/match_smoke/report.json
	$(if $(WEB_VOICE),$(MAKE) --no-print-directory -o export-web web-observe OBS_NAME=match_smoke_voice OBS_QUERY='$(WEB_MATCH_QUERY)&web-voice=fetch' OBS_ARGS='$(WEB_MATCH_ARGS)' && \
		$(PYTHON) tools/web_smoke/assert_match.py $(BUILD_DIR)/web-observe/match_smoke_voice/report.json --voice=fetch)

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
	trap 'kill $$server || true' EXIT; \
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

# ---- The desktop export, booted (ship W5, round 17) ----------------------------------------------------------
# Nothing booted the exported desktop binary, and nothing could have heard that it has no voice: the clips are
# .gdignore'd, so no pack carries them, and an exported booth reads them from voice/ beside its binary
# (AnnouncerBooth.clips_folder). This exports, places the clips there, boots the EXPORTED binary headless into a scripted
# Gangs-v-Condemned match on the Yard, and fails unless it reaches READY, the booth loads its clips, and the match ticks
# (SIM_HASH at tick 90, then it quits by itself). With a display (builder0) it also saves a frame of the match.
# "ERROR: N resources still in use at exit" (1 without the voice, 2 with; the scripted quit at tick 90 ends a running
# match): this recipe does not fail on it, but the engine-message gate does (every target, since round 17's cfd514be),
# so desktop-smoke is RED in check-all and on tests/baselines/known_red.txt until the quit path releases them (round 18).
DESKTOP_SMOKE_FLAGS := --skirmish --scripted --player-faction=gangs --enemy-faction=condemned --seed=7 --arena=yard \
	--announcer=voice --music=on --hash-every=30 --hash-until=90
desktop-smoke: export-desktop ## Export the Linux desktop build, put the voice beside it, boot the BINARY into a match: READY, clips loaded, ticks
	@# The control first: WITHOUT voice/ the exported booth must say it has no clips -- proof this smoke can see a silent
	@# build (and the observation behind W5: the clips are in no pack, so a bare export is silent).
	rm -rf $(BUILD_DIR)/desktop/voice
	@# Each run's exit code is read (round 18, ship; lent): the KNOWN line above is a log line, not a licence to crash.
	s=0; timeout 300 $(BUILD_DIR)/desktop/tank_squad.x86_64 --headless -- $(subst --hash-until=90,--hash-until=30,$(DESKTOP_SMOKE_FLAGS)) > $(BUILD_DIR)/desktop-smoke-novoice.log 2>&1 || s=$$?; \
	tools/exit_gate.sh desktop-smoke/novoice $$s $(BUILD_DIR)/desktop-smoke-novoice.log
	@grep -E '^ANNOUNCER' $(BUILD_DIR)/desktop-smoke-novoice.log | cut -c1-200
	@grep -q '^ANNOUNCER no recorded clips' $(BUILD_DIR)/desktop-smoke-novoice.log || { echo "desktop-smoke FAILED: the control (no voice/ beside the binary) did not report a silent booth -- this smoke cannot tell"; exit 1; }
	rsync -a --delete --exclude=.gdignore --exclude=README.md assets/announcer/clips/ $(BUILD_DIR)/desktop/voice/
	@echo ">> desktop-smoke: $$(du -sm $(BUILD_DIR)/desktop/tank_squad.pck | cut -f1) MB pack + $$(du -sm $(BUILD_DIR)/desktop/voice | cut -f1) MB voice/ on $$(hostname) | commit $$(git rev-parse --short HEAD 2>/dev/null || echo $${TANK_SQUAD_COMMIT:-unknown})"
	s=0; timeout 300 $(BUILD_DIR)/desktop/tank_squad.x86_64 --headless -- $(DESKTOP_SMOKE_FLAGS) > $(BUILD_DIR)/desktop-smoke.log 2>&1 || s=$$?; \
	tools/exit_gate.sh desktop-smoke $$s $(BUILD_DIR)/desktop-smoke.log
	@grep -E '^(TANK_SQUAD_READY|ANNOUNCER|SIM_HASH|MUSIC on|SKIRMISH_ARMY)|ERROR|SCRIPT ERROR' $(BUILD_DIR)/desktop-smoke.log | cut -c1-200
	@ok=1; \
	grep -q '^TANK_SQUAD_READY role=SKIRMISH' $(BUILD_DIR)/desktop-smoke.log || { echo "desktop-smoke FAILED: the exported binary never reached READY"; ok=0; }; \
	grep -q '^ANNOUNCER voice: [1-9][0-9]* clips from' $(BUILD_DIR)/desktop-smoke.log || { echo "desktop-smoke FAILED: the booth loaded no clips (silent announcers)"; ok=0; }; \
	grep -q '^SIM_HASH tick=90 ' $(BUILD_DIR)/desktop-smoke.log || { echo "desktop-smoke FAILED: the match never reached tick 90"; ok=0; }; \
	! grep -E 'SCRIPT ERROR|^ERROR' $(BUILD_DIR)/desktop-smoke.log | grep -vqE '^ERROR: [0-9]+ resources still in use at exit' \
		|| { echo "desktop-smoke FAILED: errors in the log"; ok=0; }; \
	grep -E '^ERROR: [0-9]+ resources still in use at exit' $(BUILD_DIR)/desktop-smoke.log | sed 's/^/desktop-smoke: the engine-message gate FAILS this exit-time line (known red, tests\/baselines\/known_red.txt): /' || true; \
	[ $$ok = 1 ] && echo "DESKTOP SMOKE PASSED: the exported binary boots, the booth has its voice, the match ticks"
	@if [ -n "$$DISPLAY" ]; then mkdir -p $(BUILD_DIR)/screenshots; \
		s=0; timeout 300 $(BUILD_DIR)/desktop/tank_squad.x86_64 --resolution 1280x720 -- $(filter-out --hash-every=30 --hash-until=90,$(DESKTOP_SMOKE_FLAGS)) \
			--screenshot=$(CURDIR)/$(BUILD_DIR)/screenshots/desktop-smoke.png --screenshot-delay=5 > $(BUILD_DIR)/desktop-smoke-frame.log 2>&1 || s=$$?; \
		tools/exit_gate.sh desktop-smoke/frame $${s:-0} $(BUILD_DIR)/desktop-smoke-frame.log; \
		ls -l $(BUILD_DIR)/screenshots/desktop-smoke.png 2>/dev/null || echo "(no frame: see $(BUILD_DIR)/desktop-smoke-frame.log)"; fi

# ---- The web build's opening silence, A/B (ship, round 17; for guns' playback decision) -----------------------
# Godot's web default plays every stream in SAMPLE mode (audio/general/default_playback_type.web; project.godot has no
# [audio] section). Laptop, N=1: digital zeros until the fight music (43 s) vs 13.7 s with STREAM. This exports the
# STREAM arm from a temporary [audio] line (restored by trap; guns owns [audio], nothing is committed) and plays the same
# scripted match AB_N times per arm, interleaved, in each mode of AB_MODES (swiftshader | gpu | window; window needs a
# display: builder0's desktop at its normal frame rate). One WEB_AUDIO_AB line per run: arm, mode, fps, first sound.
AB_N     ?= 3
AB_MODES ?= swiftshader gpu window
web-audio-ab: export-web $(WEB_SMOKE_DEPS) ## Round 17: the browser's sound in SAMPLE (default) vs STREAM playback, AB_N runs per arm per mode -> WEB_AUDIO_AB lines (build/web-audio-ab.txt)
	cp project.godot $(BUILD_DIR)/project.godot.ab-keep; \
	trap 'cp $(BUILD_DIR)/project.godot.ab-keep project.godot' EXIT; \
	printf '\n[audio]\n\ngeneral/default_playback_type.web=0\n' >> project.godot; \
	mkdir -p $(BUILD_DIR)/web-stream && $(GODOT) --headless --path . --export-release "Web" $(BUILD_DIR)/web-stream/index.html > $(BUILD_DIR)/web-stream-export.log 2>&1
	@: > $(BUILD_DIR)/web-audio-ab.txt; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web $(SMOKE_PORT) 127.0.0.1 >/dev/null 2>&1 & a=$$!; \
	$(PYTHON) tools/serve_web.py $(BUILD_DIR)/web-stream $$(( $(SMOKE_PORT) + 1000 )) 127.0.0.1 >/dev/null 2>&1 & b=$$!; \
	trap 'kill $$a $$b || true' EXIT; sleep 1; \
	for mode in $(AB_MODES); do \
		[ $$mode = window ] && [ -z "$$DISPLAY" ] && { echo "WEB_AUDIO_AB mode=window SKIPPED: no display"; continue; }; \
		for i in $$(seq 1 $(AB_N)); do for arm in sample stream; do \
			port=$(SMOKE_PORT); [ $$arm = stream ] && port=$$(( $(SMOKE_PORT) + 1000 )); \
			env $$( [ $$mode = gpu ] && echo OBSERVE_GPU=1 ) $$( [ $$mode = window ] && echo OBSERVE_HEADFUL=1 ) CHROME=$(CHROME) \
				$(NODE) $(WEB_SMOKE_DIR)/observe.mjs "http://127.0.0.1:$$port/?$(WEB_MATCH_QUERY)" $(BUILD_DIR)/web-audio-ab/$$mode-$$arm-$$i \
				--seconds=50 --shots=50 >/dev/null 2>&1; \
			$(PYTHON) -c "import json,sys; r=json.load(open(sys.argv[1])); a=r.get('audio_thread',{}); print('WEB_AUDIO_AB arm=%s mode=%s run=%s fps=%s ready=%s first_sound_audio_t=%s peak_db=%s loud=%s' % (sys.argv[2], sys.argv[3], sys.argv[4], a.get('median_fps'), r['marks'].get('ready'), a.get('first_loud_t'), a.get('peak_db'), a.get('loud_block_fraction')))" \
				$(BUILD_DIR)/web-audio-ab/$$mode-$$arm-$$i/report.json $$arm $$mode $$i | tee -a $(BUILD_DIR)/web-audio-ab.txt; \
		done; done; \
	done
