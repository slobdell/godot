# Stream: board (a scoreboard he can read all match: how close each side is to the win, and the kills, in the register of a televised sport)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 19 direction* (item 4),
> *Match rules*, *The arena kit → Giant screens*, *The arena announcer* and the humour ruling of 2026-09-15,
> `_agents/legibility.md`, `_agents/announcer.md` (if present; else `streams/archive/round10/announcer.md`),
> `assets/announcer/README.md` (*Moments*), `_agents/workstreams.md` *Round 19*. You own `game/match/**` (ADDITIVE:
> signals, a kill's value, a score snapshot; the rules of winning do not change, C19.4), `game/ui/hud.gd`, `hud.tscn`,
> `game/ui/hud_messages.gd`, `game/ui/widgets/hud_skin.gd`, `game/ui/scoreboard*.gd` (new), `game/announcer/**`,
> `assets/announcer/**` (lines and the ledger; a lead gate for paid audio), `game/theme/arena_kit/ads/**` and the
> live feed (`game/theme/arena_kit/**`), `tests/test_control_point.gd`, `tests/test_hud*.gd`,
> `tests/test_match*.gd`, `tests/test_assets_ad_screens.gd`, `tests/announcer/**`, `mk/announcer.mk` (if present).
> **After CP1** (garage's kit): build on `CyberFrame` / `CyberUiTheme` / `_agents/ui_kit.md`; before it, on what
> HudSkin uses today.

## The lead's direction (2026-10-05, in chat; verbatim)

> *"On the gameplay note, I think we need more sense of a scoreboard. There's this notion of taking the center floor
> to win the game, but there's no obvious scoreboard to show how close someone is based on holding that positions -
> there's also no notion of a scoreboard tracking kills. The scoreboard is a chance to take advantage of our slightly
> satirical game (i.e. a ghastly kill is met with celebratory score increases in a manner that's consistent with
> watching a professional televised sports game)"*

His humour rule (2026-09-15) governs every word and animation on the board: *"What makes satire funny is things blur
the line between believable and non-believable… something's slightly off"*; the PA host: one slightly wrong detail,
no emphasis, no jokes, no winks; the caller: authentic fight-night hype, played straight (memory: *announcer humour*).

**His second message, after the launch (2026-10-05, ~22:20 PDT; verbatim):**

> *"there's very little indication that holding the center is what scores points, or that standing in the ring scores
> points. Getting points for killing doesn't really matter much because ultimately one army eventually dies, but we at
> least need some sort of indicator - this is a matter of making the game more engaging to create the look and feel of
> a professional sporting event"*

**Read plainly, and it reorders your backlog:** the first job is the INDICATOR, not the tally. While he plays it must
be obvious that standing in a ring is what scores and that the score is moving right now: the ring on the ground
fills for whoever stands in it (its light, its floor, the radar ring), the board's meter visibly ticks while a side
holds, and the moment a ring starts (or stops) scoring is an event he cannot miss (the caller's line, the arena
screens, the ring's light; the `Show` building-light is already there, `show.gd:571`). Kills on the board are
secondary ("one army eventually dies"): keep them, small, after the meter. S2 is the indicator first (the ring, the
radar, the meter, the moment), then the kill tally rides on it. The look and feel of a professional sporting event is
the acceptance; his eye is the check.

## Where things stand (read at `93ec68b4` by the orchestrator; not played)

- **How a match is won** (`game/match/match.gd:153-159, 508-569, 1021-1059`): `control` first: a side alone in an
  objective zone fills it in `CONTROL_CAPTURE_SECONDS = 8` (flat rate; both inside = frozen; pushed past 0 =
  neutral); each side's `control_score[team]` grows by the share of zones it holds per second (both zones 1 pt/s,
  one 0.5); `CONTROL_POINTS_TO_WIN = 90`. Then `elimination`, `score_limit`, `time_limit`. A time-out goes to control
  points, then cost-weighted losses (`_points_lost`, `:1267`). Skirmish turns on elimination and control
  (`skirmish_mode.gd:241,251`; `--no-control` off; no time limit unless `--army-loop-time`).
- **Every dealt map in the rotation has TWO mirrored side zones** (`Arena.objectives_of`, `arena.gd:593`; e.g. the
  Terminus "the west ring" at (−75, −26) and "(far)" at (75, 26), radius 15). The single centre `control_point` is
  the older arenas' (foundry, barriers, …). "Centre" survives in the announcer ("We hold the center",
  `game/match/announcer.gd:114-120`), the touch-map meter's text, and `game_design.md` *Match rules*: all stale.
- **Nothing on the desktop path shows the control score.** `TacticalMap._draw_control_meter`
  (`tactical_map.gd:678-701`: a two-sided bar and "CENTER: ours N : M of 90", zone 0 only) draws only under
  `--touch-map`; the default path is `RtsControls` (`skirmish_mode.gd:336-348`). The HUD's `Scoreboard` label
  (`hud.gd:73-92`; `hud.tscn`; laid out by `hud_skin.gd:239-296` in the top-left block, `BLOCK_FRACTION = 0.19`)
  shows "Green N units vs M units Rust": units alive. `hud_messages.gd:137-151` warns once at 15 points to go. The
  radar draws one ring per zone in the owner's colour, no progress (`radar.gd:519-523, 605-614`). `Show` lights the
  nearest building when a zone changes hands (`show.gd:571-585`).
- **Kills:** `_score_kill` (`:1907-1917`) on enemy kills only: `stats["kills"][team]` +1, `score_green/rust` +1,
  `kills_by_unit[team][unit_id]`; friendly and hazard kills counted apart. Every kill is worth 1; kills never decide
  a skirmish (`score_*` only ends match-runner `--score-limit` games). No per-squad or per-tank tally. Signals:
  `finished`, `objective_changed(index, owner)`, `control_changed(owner)` (zone 0 only), `tank_destroyed(victim,
  killer)`, `unit_destroyed(event)` (cause: enemy / friendly_fire / hazard), `weapon_fired`, `projectile_impact`.
  **No score-changed signal**: `control_score` moves silently on every intel tick.
- **Shown nowhere in play except the arena screens' "live" card** (`AdBroadcast`, `ad_broadcast.gd:246-303`:
  headline "CONDEMNED 3 / LAW 1", fine print "Law lost a scout. CONDEMNED 2:1."), which the live camera feed covers
  during a match (`_show_live`, `:130-144`; `live_feed.gd`); its tally counts every death for the other side,
  friendly fire included. Sides are named by FACTION on the screens (round-5 rule, test at
  `test_assets_ad_screens.gd:126`); the HUD still says Green / Rust (`game_design.md:1661` is stale against it).
- **The announcer already says there is a board**: `pa.control.02` "The scoreboard reflects the change, and the
  betting windows remain open", `pa.control.11`, `pa.ff.08`, `caller.stat.08` "Look at the board. One side keeps
  scoring…", `pa.odds.01/02`. Moment tags on a kill: `first_blood, streak, last_unit, final_kill, even, lead_change,
  comeback, upset, weak_spot, rear` (+ `another / flurry / trade`); "leading" is by units alive, not score. 1,287
  lines; lines carry no digits. `AnnouncerBooth.line_started(cue)` (`announcer_booth.gd:20-21, 234`: moment,
  intensity, team) exists for "the ad screens (show the caller's line, the team that scored)" and nothing listens.
- End of match: the VICTORY / DEFEAT banner at 66 % height (`hud_skin.gd:363-390`), the results screen's reason
  line ("they held the centre longer (X to Y)", `results_screen.gd:248-258`) and "Destroyed N enemy units".
- The HUD's per-unit cost on his laptop is a known line (round 18: markers −19 %, unit bars −12 %; `make
  hud-digest`, `hud_cost_probe.gd`): the board adds nothing per unit per frame, and redraws on change only
  (lesson 242: a redraw signature by identity or version, never by count).

## Decided by the orchestrator (each reversible; he overrules any; record a reason if you overturn one)

- **A score bug, like a broadcast's**, in the top-centre lane (today kept clear for the WARNING banner: share it;
  the banner slides below the bug) or replacing the top-left `Scoreboard` block: two faction names, each side's
  progress to the win as a filled meter with the points (N of 90) and the zones it holds as lit segments named as
  the map names them, each side's kills, and the credits destroyed (C19.4: a kill is worth the victim's price on the
  board; `Units.cost` as the garage prices it after CP3, the raw cost before). Readable at a glance from his
  camera at his window size (1854×1011) and at the phone aspect. "Centre" only where a map has one.
- **The number that just changed is celebrated the way a broadcast does it**: a flash and a tick-up on the kill,
  the credits rolling up, a "lead change" flare, a stinger from the caller tied to the same moment (the booth's
  cue via `line_started`), and the PA's one slightly wrong detail on the fine print, never a joke. The ghastlier the
  kill (a War Rig, a last unit, a rear shot, a streak), the bigger the celebration: the moment tags are the scale.
- **Kills do not decide a match this round** (a rules change is his; asked by the orchestrator with your
  recommendation: today they break only a time-out tie, cost-weighted). The board shows them; the win meter is
  control.
- **One truth:** `Match` publishes a score snapshot and a `score_changed(snapshot)` signal (additive; the rules
  untouched; brains reads it for its posture, C19.4); the HUD bug, the radar, the arena screens and the results
  screen all read the snapshot. The screens' own tally goes.
- **The arena screens join the broadcast** (after the HUD bug): the live card's score visible during play (an
  overlay on the feed, or the card between replays), the caller's line on the screen with the team that scored,
  the odds shifting with the meter.
- **Team names by faction everywhere he reads** (the screens' rule wins; the HUD's Green / Rust goes).

## Backlog (in order)

- **S1. The snapshot and the signal.** `Match.score_snapshot()` (per side: faction, points, points to win, zones
  held with names and fill, kills, credits destroyed, units alive) and `score_changed` emitted on every change of
  any of them; a kill's value from `Units.cost`. Tests first (`test_control_point.gd`, a new `test_match_score.gd`):
  the snapshot matches the rules on one- and two-zone maps; the signal fires once per change; friendly and hazard
  kills are not credited. Determinism and the thirteen lines UNMOVED (reading only).
- **S2. The score bug.** The widget in the kit's style (before CP1: `CyberFrame` as HudSkin uses it), laid out by
  HudSkin at both aspects; reads the snapshot; redraws on `score_changed` only; `make hud-digest` shows no change
  elsewhere and `hud_cost_probe.gd` no per-unit cost. Frames: a fresh match, one zone taken, both, contested,
  a kill, a lead change, the final seconds; desktop and phone; looked at. Replace the "units vs units" label and
  the touch map's meter with it (one widget, both paths).
- **S3. The celebration.** The tick-up, flash, credits roll, lead-change flare; the booth's `line_started` wired to
  the bug (the caller's line as a lower-third for its duration; the PA's fine print); the moment tags as the scale.
  Text through the announcer's rules (no digits in spoken lines; the board shows the digits). Paid audio only
  after the lead approves new lines (lead gate; today's 1,287 lines first: pick the ones that already talk about
  the board).
- **S4. The screens and the results.** The live card reads the snapshot and is visible during play; the results
  screen's reason line and tally from the same snapshot, naming zones as the map does ("the west ring" not "the
  centre"); the stale "center" in `match/announcer.gd` and the touch-map text fixed; `game_design.md` *Match rules*
  updated by request through the orchestrator (your text, their commit).
- **S5. Play it like him.** `make skirmish ARENA=parade` and on the Terminus: can he tell, without looking away
  from the fight, who is winning and by how much? A short paragraph and frames in Status.
- **Stretch.** (a) A kill feed (last three kills, one line each, faction-named) under the bug. (b) The odds board
  on the screens moving with the meter. (c) A "match summary" card at the end: the broadcast's stat sheet. (d) Your
  recommendation on kills counting toward the win, with the numbers a series would need (lesson 256).

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` and `N
passed, M failed`; never a pipe). **Thirteen baseline lines and determinism UNMOVED on every commit** (you add
reads and signals; a move is a finding: stop and message the orchestrator). `make hud-digest` (the rest of the HUD
unchanged), `hud_cost_probe.gd` (no per-unit cost), `make announcer-check`, `make audio-check`; frames at desktop and
phone aspect of every state, looked at. His eye and ear are the check for the register (C18.3).

## Don't touch

`game/control/**`, `game/ui/**` except the files named above (orders) · `game/garage/**`, `game/progression/**`,
`game/units/**`, the kit files (garage; read `Units.cost` and the kit freely) · `game/ai/**`, `game/tactics/**`
(brains) · the rules of winning (`CONTROL_*`, `_check_finished`, `result()`: his, C19.4) · `arenas/**`,
`game/arena/**` · `mk/core.mk`, `tests/baselines/**` · balance values (C12.6).

## Waiting on the lead

- **Kills counting toward the win** (recommended: not this round; shown, not scored). Asked by the orchestrator.
- **One central floor or the maps' two side zones** (recommended: the maps' zones, named). Asked by the orchestrator.
- **New announcer lines for the board** (paid audio): the text goes to him before generation (lead gate).

## Status

**Updated 2026-10-05 23:10 PDT by the board worker.** First check on `c1896e55` (builder0) was RED: lint, one type-inference error
in `scoreboard_bug.gd` (fixed in `3c39833f`, with the zone shader's duplicate `TAU`, which the tests caught). The
board's own tests: 122 passed, 0 failed on `3c39833f` (laptop, headless, `--filter` over the match, HUD, announcer and
screens tests). `check board-shots board-play-shots` on `3c39833f` is queued on builder0.

### Plan and progress (the lead's second message puts the indicator first)

1. **S1 the snapshot and the signal**: done, awaiting green. `Match.score_snapshot()` (per side: faction, name,
   points, to win, rate, zones with fill, zones held, kills, credits destroyed at `Units` cost, units alive; per zone:
   label, owner, progress, who stands in it, contested) + `score_changed` once per tick at most, compared by value;
   `Match.final_score` at the finish. `MatchScore` names sides and zones. Tests: `tests/test_match_score.gd`.
2. **S2 the indicator**: built, frames looked at (desktop), awaiting green and the phone frames.
   - **On the floor** (`ZoneRings`, `game/theme/arena_kit/zones/`): each scoring zone drawn where it is. Dashed white
     rim while free; a capture arc runs round it in the capturer's colour; held = rim solid in the holder's colour,
     floor tinted, rings flowing inward (the points going in); both inside = it blinks. The name stands over it with
     SCORING / CONTESTED under it. Added by the HUD, so only where there is a screen.
   - **The score bug** (`ScoreBug`, `game/ui/scoreboard_bug.gd`), top centre, replacing "Green N units vs M units
     Rust": faction names; big points with FIRST TO 90; a meter per side with ticks every 10; while a side scores its
     meter's edge breathes, a chevron runs toward the win, "SCORING +1/S" (or +.5/S) sits under its number and every
     point pops a "+1"; zone chips W / E fill in the capturer's colour and flash yellow when contested; a lower-third
     "CONDEMNED TAKE THE WEST RING · SCORING" when a zone changes hands, "LEAD CHANGE: LAW IN FRONT", a possession
     bar on the leader's half; the last 15 points run hot (yellow); kills and credits destroyed small underneath.
   - Frames: `make board-shots` (the bug in 10 states at 1854x1011 and 1200x540, `build/board-shots/`),
     `make board-play-shots` (a CPU-vs-CPU skirmish on the Terminus and parade at 25 / 60 / 110 s, both sizes,
     `build/board-play/`). New file `mk/board.mk`.
3. **S3 the celebration**: built. The booth hears every zone (it heard only zone 0's: `control_changed`), each with
   its own previous owner; the 25 control lines that say centre / middle are tagged `centre` and play only on a
   one-zone map (text unchanged, no audio needed). The booth hands each cue to the bug: a ghastly kill's moment tags
   put up a graphic in the killer's colour ("LAW: 4 STRAIGHT KILLS", "CONDEMNED DOWN TO THEIR LAST VEHICLE", "KILL
   FROM BEHIND", "ENGINE DECK, CLEAN KILL", "UPSET", "FIRST BLOOD"), and the call's intensity scales the kill flash
   and the "+240 CR" pop. The spoken words stay on the caption line. Tests: `tests/announcer/test_announcer_zones.gd`,
   `tests/test_hud_score_bug.gd`. No new lines (paid audio is a lead gate, and none were needed for this).
4. **S4 screens and results**: screens built; results by request. The giant screens show a score strip along the
   bottom of the live feed during play (`ScoreStrip` in its own 320x104 viewport, redrawn only on a change, so it
   costs nothing per frame), with the booth's line under it in the team's colour while it is spoken; the live card
   reads the snapshot (the screens' own tally counted friendly kills for the other side; it is now only a fallback for
   stand-ins). The match announcer says "We hold the west ring", not "the center". The results screen is garage's file
   (request 3).
5. **S5 play it like him**: frames queued (`board-play-shots`); a windowed play on his laptop needs the orchestrator's
   slot.

### Findings

- **The only ring drawn on the floor of every map was at the CENTRE, and on the twelve dealt maps it scores nothing**
  (`arena_dressing.gd:99-109`). Fixed on main by the orchestrator (`6ebdaf78`); the real zones are now ZoneRings.
- The booth heard only zone 0's captures, and 25 of its control lines say "centre". Both fixed (S3).

### Decisions (each reversible)

- A mirrored zone is named by its compass word swapped ("the west ring (far)" at +x is "the east ring"), the way he
  already drives the mirrored streets by their real names (`tools/make_arenas.py:202`); no compass word: "the far
  <name>"; a name that already says "far" keeps the map's word.
- `score_changed` fires at most once per physics tick, at its end, compared by value: a kill and the death it causes
  are one emission. Nothing in the simulation listens.
- Leader on the board: points, then credits destroyed, then kills (without control: credits, then kills). Display only.
- The bug shows the stat; the booth's words stay on the caption line (not repeated on the bug). The screens use team
  colours (the venue is neutral); the HUD uses friend / foe.
- One windowed run of `scoreboard_shots.gd` (about 10 s) opened on his laptop at ~23:00 PDT before I moved frames to
  builder0. Windowed runs go to builder0 from here.

### Requests to other streams

1. *(nobody's; done by the orchestrator, `6ebdaf78`)* no centre ring on maps that list `objectives`.
2. *(orders, via the orchestrator)* the radar rings show the capture fill; the touch map's `_draw_control_meter` goes
   once the bug is on main.
3. *(garage)* `results_screen.gd:248-258`: "held the centre longer" becomes "held the rings longer" where the map has
   two zones, and the results can show the board as it stood at the end: `Match.final_score` (the snapshot at the
   finish) is there to put in the report.
4. *(orchestrator, by request)* `game_design.md` *Match rules*, my text:
   > - **Control: the map's scoring zones** as a second win condition, **on by default** (the lead: *"sure, I agree
   >   with you"*). Every dealt map scores TWO mirrored side zones (`Arena.objectives_of`), named on the board, on the
   >   floor and by the booth as the map names them ("the west ring", and its mirror by its compass word, "the east
   >   ring"); the older arenas score one centre zone. A side alone in a zone fills it in 8 s (flat rate; both inside
   >   freezes it); each side scores the share of the zones it holds, a point a second for all of them; first to 90
   >   wins; a time-out goes to points, then cost-weighted losses.
   > - **Kills are shown, not scored** (round 19): the board carries each side's kills and the credits destroyed (the
   >   victim's price); they decide only a time-out tie.

### Questions for the lead

(none new; the brief's three stand)

### Merge notes

New files: `game/match/match_score.gd`, `game/ui/scoreboard_bug.gd`, `game/ui/scoreboard_shots.gd`,
`game/theme/arena_kit/zones/**`, `game/theme/arena_kit/ads/score_strip.gd`, `mk/board.mk`, `tests/test_match_score.gd`,
`tests/test_hud_score_bug.gd`, `tests/announcer/test_announcer_zones.gd`. Shared-file edits: none outside board's
paths. `assets/announcer/lines.json`: tags only (25 lines gain `centre`), no text, no clip ids.
