# Stream: balance (the CPU meets his tank rush with artillery; Law's and Syndicate's artillery can hurt tanks; the faction stat change judged)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 42** (C42.1, C42.5,
> CP42.1) and *Rulings (round 41)* R41.12, R41.16, R41.18; your round-41 brief `streams/archive/round41/balance.md` (Status: FINAL
> REPORT, B5 WRITE-UP FOR HIM, the lines screen, *Next steps (round 42)*, the B2s v2 rebuild recipe). **You own:** `game/units/**`
> (unit numbers within C42.5; `army.gd`'s ARCHETYPES and `cpu_army`), `tools/balance/**`, `mk/balance.mk`, `tests/rules/**`,
> `mk/rules.mk`, `mk/tactics.mk`, your probes in `tests/tactics/` (`face_probe.gd`, `army_probe.gd`, the `*_table.py` / `*_bar.py`
> tools); GRANTS: `game/garage/garage_advice.gd` / `garage_opponent.gd` for the one suggestion line and the opponent deal (merge
> note); `game/modes/skirmish_mode.gd` demo_flags as R41.12. **Model:** Opus. **Machine:** builder2 (series, J24; `make gcp-start`,
> it is STOPPED at launch; Spot: read the verdict line, re-queue on preemption), builder0 light lane for checks. **Seeds:** B7 bar
> 9901-9940; B8 bar 10001-10040 + 10101-10140, B8 dev 10201-10240 (never a bar); Bar B2s v2 keeps 8801-8840 + 8901-8940 (filed round
> 40, unread); Bar B5 t50 keeps 9201-9240 + 9301-9340 (unread; only on his yes).

## The lead's direction

Combined arms (2026-10-24): "using a variety of units should theoretically create the advantage ... having a mix of unit types should
protect other units' weaknesses." Target (R40.6): a well-mixed army beats an all-tank army of equal cost ~60-65 %. His levers
(2026-10-26): "What about making the tanks slower than they currently are? Or what about making tank's turrets turn slower?" (measured:
~5 points each, R41.18). Faction balance (R40.1): "when a faction keeps losing, we should change its units' numbers" (+/-15 %).

**The round-41 write-up went to him (archived Status, B5 WRITE-UP FOR HIM) with this recommendation; his answer is pending and the
orchestrator decided the round starts on it:** (1) every faction gets an artillery-heavy lineup the CPU fields against an all-tank
army and the garage suggests ("bring two artillery squads with your tanks"); (2) Law's and Syndicate's artillery numbers within his
15 %; (3) the slow turret only if he likes the feel (its lines screen read G2 turtle +3.0 se 1.5: not safe alone); no missile.
A CPU that fields the counter is the CPU being smarter (memory: *smart AI on both sides*, symmetric improvements ship without asking).

## Where things stand (main at launch: see HANDOFF)

- B5 (R41.12/R41.16/R41.18): all-tanks v the normal mixed army 85 %; his levers -4/-5; IFV +15 %/-15 % -2; turret + IFV 77 %; pen7 0.
  **Artillery-heavy lineups reach the target with no number changed:** Condemned `siege` 47 %, Gangs `gang_hail` 52 %; Law `law_barrage`
  96 %, Syndicate `syndicate_barrage` 87 % (measure_only archetypes in `army.gd`: the Gas Rocket Truck deals 2.65 a credit v the
  Condemned Artillery's 5.4 and needs 79 s to kill an Assault Gun; the Missile Ring 1.06 a credit, 380 credits, dies to the Railgun
  in 5 s). `cpu_army` (army.gd:224) rolls one archetype a game from `archetypes_for(faction)` (measure_only skipped).
- Bar B2s v2 (fm_c5r2_lawt5, ARM d385cd308; 8801-8840 + 8901-8940 unread): BLOCKED on the bridge (R41.13); manoeuvre's Q6 is CP42.1;
  your rebuild recipe (cherry-pick ad956031b's re-pins onto the CP42.1 main) is proven. The v2 overrides tree crossed 72/72 fresh
  bridge seeds OFF; its only known failure is the drill's rust t15 s2.
- Tools: `search.py` (levers, `mono`, `faces`, `bar-b5`), `GUARD_TARGET`, the face probe; raw data `~/balance-guard-raw/b5`,
  `~/balance-runs` (keep).

## Backlog (in order)

1. **B7 the CPU counter-lineup, OFF behind `--cpu-counter=on|off` (ON when its bar passes).** First say in Status how the deal can know
   the player's army (the garage's opponent deal `garage_opponent.gd` sees his draft; a skirmish's `cpu` army may not): the rule = when
   the opposing army's cost is >= 60 % tanks (say the threshold with a reason), the CPU fields its faction's artillery-heavy lineup
   (`siege`, `gang_hail`, `law_barrage`, `syndicate_barrage`: the two measure_only ones become real lineups for this rule only); else
   today's roll. The garage suggestion: one line in `garage_advice.gd` when his draft is tank-heavy ("bring two artillery squads with
   your tanks"), ON (an `=off` escape). Bar B7 before any number on 9901-9940: deciding = all-tanks (each faction's `mono`) v the CPU's
   dealt army, ON <= 60 % pooled over the four factions (BASE ~85 %) AND paired < 0 by >= 2 se; guards (filed first): the mixed army v
   the CPU's dealt army within BASE +/- 1.645 se (a normal army doesn't get punished), fight length within +/-20 %, every faction's
   lineup dealt loads and fields within the unit cap (C25.6), demo and default `cpu` unchanged (test). A pass ships ON (the orchestrator
   tells him in player terms; his veto stands).
2. **B8 Law and Syndicate artillery within his 15 % (R40.1 / C42.5).** Dev screen on 10201-10240 (`search.py`, paired v base, 400 fights
   an arm as B5): Gas Rocket Truck damage +15 % and cost -15 % (each, then both); Missile Ring cost -15 %, toughness +15 %, both; read
   all-tanks v `law_barrage` / `syndicate_barrage` and the faction table (B2s's flatness and G3 fight-length lines). Pick the arm that
   moves all-tanks v barrage most toward 35-40 % without failing the faction lines; file Bar B8 on 10001-10040 + 10101-10140 before any
   number (deciding = that read; guards = Bar B2s v2's G1-G5 and flatness, unamended). On a pass the numbers ship (he hears the size).
3. **B9 Bar B2s v2 after CP42.1** (the orchestrator tells you the minute the bridge hash is on main): rebuild the ARM, run the filed
   bar, report. If CP42.1 never lands this round, say so in Status; the stat change carries again (do not loosen bridge-pooled).
4. **B10 Bar B5 t50 only on his yes** (a lead gate: the lines screen says G2 turtle +3.0 se 1.5 FAILS; the orchestrator tells him).
5. **Stretch:** B3 faction-aware CPU; B6 ADVANCE off a seat (archived round-40 Status).

## How to verify

`tools/balance/search.py` (every number with commit, machine, seeds, n, se); `make quick-remote`; a full check of every hash you name;
`python3 -m pytest tools/balance` if it has tests. Smoke like a player: `make skirmish ARENA=terminus` with an all-tank garage army v
the CPU: does it field artillery and scouts against you; the garage shows the suggestion line (screenshot it, desktop and phone).

## Don't touch

`game/tactics/**` (engage), movement / traffic (manoeuvre), `game/camera/**`, `native/**` (GUARD_TARGET is native's; ask via the
orchestrator), `game/combat/weapons.gd` / `armor.gd` except NUMBERS B8 needs (C42.5), `tests/baselines/**` (the orchestrator adopts).
Don't push.

## Waiting on the lead

His answer to the combined-arms recommendation (the round proceeds on it); the slow turret (B10).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
