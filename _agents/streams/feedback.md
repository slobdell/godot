# Stream: feedback (he can't miss the match ending; the support trucks read in a real fight)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 38** (C38.1) and `game_design.md` *his
> playtest note, mid-round* (round 37) and *his picks on feedback's directions page*. Your round-37 close notes:
> `streams/archive/round37/feedback.md`. **You own:** `game/ui/**`, `game/theme/**`, `game/audio/**`, `game/announcer/**`,
> `tests/feedback/**`, `tests/test_feedback*.gd`, new assets for your items. Presentation only: sim-baseline must not move.
> **Model:** Opus. **Machine:** builder0 checks; the laptop for looking (his test bed, Intel UHD 620).

## The lead's direction

His round-37 playtest: he kept ordering his last two artillery trucks after the match had ended on zone points (game_design.md, R37.27:
the match ended at 195.4 s; his later clicks still echoed "move"). His standing rules: concept choices on a tap-to-approve page before
anything final; he limits asset COUNT, not spend; announcer satire subtle, the caller authentic UFC hype.

What he will notice: when a match ends, he knows at once (who won, why), and clicks after the end don't pretend to give orders.

## Where things stand

- His picks are ON (hit C ring, pinned A, repair A, cone C), six sounds/lines live, `marks` OFF.
- The end screen exists (`game/ui/scoreboard_bug.gd` and the match result) but he missed it in a real game.
- The Resupply Tanker rarely got to repair in real fights (3 s quiet rule). His answer (2026-10-22): it also repairs during combat (F3).

## Backlog (in order)

1. **F1 the end of a match:** read his recording (`build/recordings/2026-10-21T21-43-57-archipelago.jsonl`, the end at 195.4 s) and the
   current end flow; propose 2-3 end treatments (a clear banner + reason, the announcer's call, input that says "match over") on a
   directions page; the orchestrator relays; build his pick.
2. **F2 orders after the end:** a click after the match ends says so instead of echoing "move".
3. **F3 the Tanker repairs under fire (C38.4, HIS ANSWER: "yes it also repair during combat").** Grant: `Match.repair_rate_for` and
   the repair tick in `game/match/match.gd`, one guarded seam `--repair-under-fire` (OFF until its bar). Half rate (2.5 hp/s) under
   fire, full after 3 s quiet. File the bar (C38.4) before numbers; series on the guard lines on builder2 (native's tooling). The repair
   beam must show the slower mending.
4. **Stretch:** any rough edge in his picks seen in real fights at his laptop preset.

## How to verify

Tests; screenshots and clips LOOKED at on his laptop preset; perf on the laptop preset (`make control-timing`); `make skirmish` to the
end of a match.

## Don't touch

Simulation code, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

F1's page when it exists (the orchestrator relays).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**2026-10-22 12:20, F3 PASSED its bar (C38.4) -> ships ON.** f0ad5a44d, builder2, the 320 CP37.1 guard fights (blob + turtle,
seeds 2601-2608/2701-2708, 5 arenas, both sides), base `--repair-report` v ON `--repair-under-fire --repair-report`, paired:
- **Deciding:** gang hp mended a fight 399.6 -> 556.5 (+39 %; 174.1 of it under fire); up in 93, down in 16 of 120 gang fights;
  diff +156.8, se 50.0 over the 6 seeds with a gang side. (Base already mends ~400 hp a fight once quiet: more than the round-37
  clips suggested; under fire adds the rest.)
- **Guards:** blob 49 % -> 48 % (2 flips to a loss, 1 to a win); turtle 40 % -> 41 % (+1.2, se 0.9, McNemar p 0.94); gangs guard
  blob 5 -> 6 of 30, turtle 3 -> 4 of 30 (one flip each, p 0.5); kills/fight and median length flat per faction (gangs blob 51.0 ->
  51.2 kills, 102 -> 99 s). All inside noise. Perf: no new loop (perf-judge in the check).
- Table: `python3 tests/feedback/repair_table.py ~/projects/godot-feedback-guard-raw/f0ad5a44d-repair{base,on}`; guard.py --pair the same.

**2026-10-22 ~11:30, F1 page up (WAITING ON HIS PICK), F3 ON arm running.**
- **F1 page:** https://claude.ai/artifact/V4dAc2UNofD2553VqKKS5q (db `picks/end`), relayed by the orchestrator. Four looks filmed by
  `make remote T=end-shots` (f0ad5a44d + the harness tweak 4b070b284, builder0, laptop preset, archipelago seed 44214, Law v Gangs,
  enemy wins on the rings at 90-61 after 10 s of fight, a click 3.5 s after the end): A end card (recommended), B broadcast end,
  C banner stays, P today's banner plus why (the default). Looked at: every look shows DEFEAT + "Road Gangs held the rings: 90 points
  to 61"; MATCH OVER at the click in all four; in A the command bar is hidden under the dim; B's bars cover the score bug; P is as
  easy to miss as today's (the point of the page). The clips' sources live in ~/projects/godot-feedback-endkeep/ (outside build/,
  which every remote copy-back resets). Note: the sim keeps running after the end (survivors still fight; "Vehicles left" is the
  board at the finish).
- **F3 base arm:** f0ad5a44d, builder2, guard.sh (GUARD_CHUNK=2, GUARD_JOBS=20), `--repair-report`, 320/320 fights with MATCH_MENDED,
  0 attempts lost. **Paired with main's base (references/scoreboard/guards/1c484a525.fights.jsonl): identical, blob 49 % -> 49 %,
  turtle 40 % -> 40 %, 0 flips:** the counters and the OFF seam change nothing. ON arm started 10:59.

**2026-10-22, F1/F2 built, F3 seam built (in progress).**
- **F2 (every look):** `EndCard` (game/ui/end_card.gd), mounted by the Hud on `Match.finished` where he commands an army (the
  controls node on the HUD layer, not spectated). From that moment a click on the field or any key stops at the card: a click
  says MATCH OVER where it landed and the choices pulse; the wheel and middle drag still look around (RtsCamera.handle_mouse),
  the camera's keys are polled so they still pan. Enter = PLAY AGAIN (his factions and map, a new seed), Esc = NEW MATCH (the
  faction menu); both appear 0.6-2.5 s after the end so a click in flight cannot restart. Under the garage loop: no choices, and
  keys go to its results screen once it is up. Tests: tests/test_feedback_end_card.gd (real pushed input), test_feedback_match_end.gd.
- **F1 looks** (`--end-look=plain|a|b|c`; default `plain` until his pick): plain = the old centre banner text + why + the choices;
  a = the end card (battle dims, a card: result, why, what was left, choices); b = the broadcast end (letterbox bars, the camera
  goes to the ring the winner held / its survivors, the choices after 2.5 s); c = the banner stays (a wide band across the top
  third, the battle stays bright). Reason lines in his words (MatchEnd): "The Syndicate held the rings: 90 points to 61", "Your
  last vehicle was destroyed. The Syndicate kept 4", "Time's up: you led at the rings, 40 points to 22".
- **F3 seam** (C38.4 grant, match.gd): `Match.repair_under_fire_on` (`--repair-under-fire`, OFF), `repair_under_fire_rate_for`
  (best friendly FIELD mender at x0.5; never the base, never itself: a Tanker being shot does not mend its own hull, so it stays
  "easy to kill" as L3 meant; a second Tanker can), stats `hp_mended` / `hp_mended_under_fire` (counters only),
  `--repair-report` prints MATCH_MENDED at exit for the series. The beam (FeedbackReader.mending, same rule) runs its pulses at
  half speed, fainter and thinner while mending under fire. Tests: tests/test_feedback_repair_fire.gd.

**2026-10-22, started.** Launch check: main 1c484a525 + docs inherits round 37's close check (HANDOFF: GREEN, ALL JUDGED, builder0);
not re-run. His 2026-10-21 recording (`2026-10-21T21-43-57-archipelago.jsonl`) is gone with round 37's worktrees; game_design.md's
read of it stands (control end at 195.4 s, later clicks echoed "move").

**What the end is today (read, 5b20bfd62):** `make skirmish` (his way in, faction menu) ends with `Hud.show_banner`: a plain 34 px
label in the screen centre saying VICTORY / DEFEAT / DRAW, no reason, under the busy fight. The match keeps simulating (survivors
drive on), RtsControls keeps taking orders, so a click still answers "Moving" with a ground marker. No results screen and no way
on except quitting (the garage loop has its results screen 3 s later; skirmish does not).

**F3's bar (C38.4), filed 2026-10-22 BEFORE any number.** Switch `--repair-under-fire` (OFF until this passes; `Match.repair_under_fire_on`).
Rule: a friendly field mender (the gangs' Resupply Tanker) keeps mending a vehicle that is under fire at HALF its rate (2.5 hp/s);
full rate after `REPAIR_QUIET_SECONDS` as today. The base's own mending still waits for quiet (his answer was about the Tanker).
Run: the CP37.1 guard set (blob + turtle, both sides, the same 320 fights) through `tests/feedback/repair_probe.gd` (extends
`guard_line.gd`, read-only, as rules' guard_motion_probe does; it adds the match's mending counters), base v ON, paired, builder2.
- **Deciding:** hp mended by field menders per fight with a gang side, UP (paired; base and ON on the same fights). Expect a large
  rise (base: Tankers rarely mend in a fight); a rise under ~25 % is a fail (the rule would not be something he notices).
- **Guards (what it could BREAK):** (1) the blob line overall must not move beyond noise, and no faction's blob or turtle rate may
  rise beyond noise; the gangs in particular must not start winning the blob line (paired, guard.py --pair, p >= 0.05 = inside
  noise); (2) kills and fight length per faction within noise (no stalemates from immortal gang trucks: median length up < 15 %);
  (3) perf: the repair loop already runs for every unit every INTEL tick; ON adds no loop (perf-judge in the check).
- **Fails if** the deciding read is flat, or any guard moves beyond noise in the gangs' favour. A pass ships ON (his call, C38.4).

**Plan (smallest foundation first):**
1. `MatchEnd` (pure, `game/ui/match_end.gd`): the headline, the reason in player words ("The Syndicate held the rings: 90 points
   to 61", "Your last vehicle was destroyed"), the score line, the next match's flags. Tests first: `tests/test_feedback_match_end.gd`.
2. `EndCard` (`game/ui/end_card.gd`), mounted by the Hud on `Match.finished` where he commands an army: F2's guard in every look
   (a field click or order key says "Match over" instead of ordering; the camera still looks around) and `--end-look=` for F1's
   directions. Decision: until he picks, the default is `plain` (today's banner + the reason line + the guard): the guard is
   F2's fix, not a look; the three directions sit behind the flag (round 37's precedent: nothing he has not picked shows).
3. `make end-shots` (builder0 display, laptop preset): a real commanded skirmish ended by each reason, stills + a clip per look,
   including a click after the end. The directions page from those; the orchestrator relays.
4. F3: bar filed first (C38.4), then `--repair-under-fire` in `Match.repair_rate_for` + the tick, the beam showing the half rate,
   the series on builder2.
