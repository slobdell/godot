# B3 report (brains fork): the sim's tick at his Sumps and at 50 a side

Scratch copy: `<scratchpad>/godot-brains-b3`, its own git repo. Its first commit is the tree of `32748a0c`; the B3 commits
sit on top (`deec4d9` tick table, `3c420d5` open-mesh certificate at movement's sites, `e8973c6` stride rows, `e204baa`
brain_stride through the levers gate). Every builder0 run went through `tools/remote.sh` from that copy. Builder0 was
SHARED with three other streams' checks the whole afternoon (load 4–15), so **compare across separate runs at ±30 % at
best**. Prices that matter come from the in-run A/B (`BrainsAB`), where both arms share the load.

## 1. The workloads (all under `tests/ai_scenarios/armies/`)

- `his_sumps_law.json` / `his_sumps_syndicate.json`: his Sumps match `2026-10-07T13-46-42` (seed 5988, main 5beb038f),
  rebuilt from the recording's unit list. His Law: 8 law_tank, 8 law_ifv, 4 law_scout, 4 law_suppressor (his two
  squads of 8 split into two of 4 each, as his elements did) = 24. The Syndicate: 3 syn_ifv, 5 syn_lancer, 6 syn_scout,
  3 syn_artillery = 17. Total 41.
- `scale_{law,syndicate}_{25,50}.json`: 5 / 10 squads of five, the same mix doubled. Law: tank, ifv, scout, suppressor,
  tank. Syndicate: tank, ifv, lancer, scout, artillery.

## 2. The tick table (builder0, `deec4d9`, `make tick-table`, n = 1 match per arm, whole match, load 4–13)

`open_ground` OFF in every row except "on", so these rows are 32748a0c's behaviour. "both" = leaders on both sides
(`--green-elements --rust-elements`, standing in for his squads being tasked); "rust" = CPU leaders only (his path's
CPU); "none" = no leaders.

| workload | leaders | ticks | vehicles start → end | **tick ms** | controllers | elements | tank | match |
|---|---|---|---|---|---|---|---|---|
| his Sumps 24 v 17 | none | 4064 | 41 → 15 | 15.6 | 13.9 | — | 1.07 | 0.53 |
| his Sumps | rust | 3635 | 41 → 10 | 16.7 | 13.5 | 1.69 | 0.88 | 0.53 |
| his Sumps | both | 5850 | 41 → 8 | 19.6 | 14.5 | 3.45 | 0.96 | 0.58 |
| 25 v 25 Sumps | none | 2014 | 50 → 23 | 16.6 | 14.9 | — | 1.02 | 0.60 |
| 25 v 25 Sumps | both | 3082 | 50 → 14 | 21.9 | 16.5 | 3.60 | 0.99 | 0.74 |
| 50 v 50 Sumps | none | 2707 | 100 → 44 | **41.7** | 37.4 | — | 2.51 | 1.61 |
| 50 v 50 Sumps | both | 2401 | 100 → 35 | **62.7** | 49.0 | 8.63 | 2.50 | 2.38 |

**Ratio 50/25:** 2.5 without leaders and 2.9 with leaders on both sides. Per vehicle that is roughly linear with a mild
rise; it is not quadratic. The elements segment is per element (3.6 → 8.6 ms for 10 → 20 elements). On his laptop
(×2.75) the 50 v 50 tick with leaders is ~170 ms, so at 30 Hz the frame cannot keep up.

The `his-both-on` row (13.4 ms) and `scale50-both-on` (87.6 ms) are listed in the raw table but are NOT a price: they
are separate runs on a loaded box, ±30 %, and point opposite ways. The price is the A/B in §4.

## 3. Where the tick goes (`--brains-parts`; the timing inflates the tick: read shares and calls)

Full 50 v 50 table: `b3-parts-50v50.txt` (builder0, `deec4d9`, Sumps, leaders both, open_ground off, n = 1, 2401 ticks).
Top parts, usec a tick (calls a tick): execute 47 422 (100) · think 37 999 (100) · move 29 036 (68) · by.move_to.moving
25 910 (42) · situation 18 972 (14.7 thinks) · weapon 14 901 · nav.closest 9 686 (286 calls) · weapon.scan 8 349 ·
move.avoid 7 438 · nav.chord 7 055 · move.path 6 435 · t.poll 5 242 · s.cover_fire 5 219 · decide 4 663 · avoid.solve
3 765 · move.guard 3 567 · s.contacts 3 509. match.gd's OWN sections: match/intel 3.0 ms a tick (0.33 calls), the rest
under 1 ms. So perf's "+12.1 ms" for match.gd by removal is the brains' calls INTO match.gd (incoming_projectiles,
friendlies_in_line_of_fire, threat fields, …), booked under the brain parts, not match's own `_physics_process`.

Function level (laptop, `deec4d9`, his Sumps + CPU leaders, `make ai-script-profile`, 120 s, 53 sampled fight frames,
profiler on, shares only): Pathing.closest_point 14.0 % self (104 calls a tick); TankBrain.build_situation 24 % total;
Movement.drive 33 % total (_chord_compute 9 %, _next_waypoint 8 %, _avoid 7.8 %); TankBrain.decide 8.7 % total.

nav.closest by site (builder0, 50 v 50 both, off): chord 105 · slot 75 · kturn 66 · avoid 21 · gate 17 a tick. In an
element FORM-UP (the first seconds) the slot site alone reaches ~200 calls a tick (laptop, 25 v 25).

**The profile is flat after closest_point.** No single equal-answer cut is worth more than ~5–10 %.

## 4. The equal-answer cut: `open_ground` (switch in BrainSwitches; patch `b3.patch`)

- **What it does:** a CERTIFICATE that a point stands in level open navmesh. It is built once per navigation-map
  iteration from the navmesh polygons: boundary edges are bucketed in 4 m cells; a cell counts as level when no sloped
  polygon is near and the heights' bound is ≤ 0.15 m; a cell counts as inside when its centre query lands on itself;
  a cell is deep when all its neighbours are open too.
  (a) `SlotGround.standable_for` / `standable` return the point itself without a query: that is the full grounding's
  answer there.
  (b) Movement's chord, k-turn outline (kturn_cap path), avoid probe and two gate sites skip `Pathing.closest_point`
  when the probe is certified. They only compare the distance against a slack of 0.3–1.5 m, and the certificate
  bounds it at 0.15 m.
- **Proof it is an equality:**
  - `tests/test_tactics_slot_open.gd` (laptop, passes): on sumps / parade / foundry / terminus, every certified point
    (≈ 33 000 point × hull pairs; coverage 36 / 62 / 79 / 36 %) returns ITSELF from the full grounding, and every point
    certified on-mesh has its closest point within 0.15 m.
  - In-run A/B state hashes equal: slot sites only (`44a362c`): his Sumps `d670087f51c1e6f3` = plain; 50 v 50
    `a982c4be969fb23b` = plain. Movement sites added (`e204baa` tree): his Sumps + rust leaders `c4e01e809d1b98e5` =
    plain; his Sumps + both `d670087f51c1e6f3` = plain; 50 v 50 + both `a982c4be969fb23b` = plain.
  - **sim-baseline (builder0, `e204baa` tree, open_ground ON): exited 0, all 13 dealt maps UNMOVED** (glibc-2.43).
- **Price:**
  - Slot sites only (builder0 A/B, `44a362c`, n = 1 run, 30-tick blocks): his Sumps + both leaders, whole tick's
    scripts 8.70 → 8.52 ms (−2.1 %); 50 v 50 both −2.4 % (noise).
  - Movement sites added (laptop, `3c420d5`, his Sumps + rust leaders, 75 s, parts): nav.closest 76.8 → 39.5 calls,
    1.95 → 1.05 ms a tick (≈ −4 % of the 23.5 ms tick).
  - **Builder0 A/B of the widened cut (`e204baa` tree, his Sumps + rust leaders, 195 s, 30-tick blocks): whole tick's
    scripts 9.355 → 9.324 ms (−0.3 %), controller band −0.4 %; in the fight −0.0 %, early (form-up) −9.0 %.** The
    laptop's −4 % did NOT reproduce on builder0. Same tree, his Sumps + both leaders: −1.8 % (fight −2.1 %); 50 v 50 + both: −2.1 % (fight −2.3 %, 66.1 → 64.6 ms of scripts a tick). Verdict: an equality worth ~0–2 % in a fight, mostly in form-ups. Ship it
    if it is free to merge; it is not the 4×.

## 5. The stride priced (C17.4 / the orchestrator: game-wide, a switch, default OFF)

Measurement rows in `BrainVariants` (clone only): `b3s2` = x18m + brain_stride 2 (EVERY unit, both sides, his
included); `b3fs2` / `b3fs3` = x18m + far_exec_stride 2 / 3; `b3fi1` = far_idle_hz 1; `b3fs2i1` both. `brain_stride` is
now read through `BrainLevers.gate`, so `--brains-ab-run=levers` alternates it in 300-tick blocks inside one fight.
Outside an A/B it reads the same value, so x5b2/x5pb2 are unchanged.

(chain 6: PENDING — table: arm, ms a tick at 25 and 50 by in-run A/B, ratio, think-rate scenario deltas, pursuit and
arrive series stride on v off, commit, machine, n.)

The sim-baseline lines WILL move with the stride on. The levers A/B's state hash differs from the plain run's by
construction (a lever changes the fight), so shipping it would be DECLARED.

## 6. Verdict and recommendations

1. **The tick at his sizes is per vehicle, close to linear** (50/25 = 2.5 without leaders, 2.9 with). The leaders add
   ~25–50 % on top (elements 8.6 ms at 20 elements). On builder0, 50 v 50 with leaders is ~63 ms a tick; on his laptop
   that is ~170 ms.
2. **Equal-answer cuts top out near 5–10 %.** closest_point was the biggest single function. Its certificate is in the
   patch, measured at 0–2 % in the fight on builder0. The rest of the profile is flat: movement's
   path / avoid / guard / steer per moving vehicle, the think's situation (cover_fire, contacts), weapon.scan. None of
   these is more than ~10 %.
3. **The ~4× needs a rate change**, i.e. a DECLARED behaviour change: brain_stride 2 game-wide, or far_exec_stride /
   far_idle_hz. That is priced in §5 (chain 6). Or a smaller cap. Other directions, not measured: fewer element updates
   at 20 elements (Element.UPDATE_TICKS = 3). match/intel runs every 3rd tick at ~9 ms a call at 100 vehicles: cheap
   averaged per tick, but a spike.

## 7. Still running when this fork ended (detached; read the results there)

- `b3-chain4.sh`: DONE (18:26 PDT); all three open_ground A/Bs equal-hash, numbers in §4.
- `b3-chain6.sh` → the stride priced:
  - `b3-results/levers-{b3s2,b3fs2}-{sumps,foundry}-{50,25}.out`: in-run A/B, `--brains-ab-run=levers`, 300-tick blocks.
    The target's final hash check FAILS by design (a lever changes the fight); read the BRAINS_AB lines.
  - `stride-scenario.out`: scenario_stride_price, dodging and the beaten zone, x18m v b3s2 / b3fs2 / b3fs3 / b3fi1 /
    b3fs2i1, 6 seeds.
  - `stride-table/`: sim-profile per brain, Sumps + foundry, 25 + 50.
  - `pursuit-{x18m,b3s2}.jsonl`: pursuit-series, seeds 1–4, both maps.
  - `arrive.jsonl`: squad-arrive-series, green-brain x18m v b3s2, seeds 1–2.
- Logs: `b3-chain4.log`, `b3-chain6.log`. PIDs: `b3-chain4.pid`, `b3-chain6.pid`.
- When chain 6 prints CHAIN6 DONE: delete the scratch copy `godot-brains-b3` and clear builder0's
  `~/tank_squad/godot-brains-b3/build` (small logs only).

## Patches (all against 32748a0c)

- `b3-open-ground.patch`: the certificate (slot_ground.gd, movement.gd's sites, brain_switches.gd `open_ground`) plus
  its test. Equal-answer; the 13 lines are unmoved.
- `b3-tick-table.patch`: `make tick-table` and `make stride-table` (mk/ai.mk), `tools/tactics/tick_table.py`, the
  his-Sumps and scale armies.
- `b3-stride.patch`: measurement only. brain_stride is read through BrainLevers' gate (the same value outside an A/B),
  the b3* rows, `scenario_stride_price.gd`, `PURSUIT_EXTRA`. NOTE: ai-scenarios picks up `scenario_stride_price.gd` and
  takes longer with it: drop it or gate it before merging.
- `b3.patch`: all of the above.
