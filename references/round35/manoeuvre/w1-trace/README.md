# W1: why crews die `stuck:wedged` (round 35, manoeuvre, C35.6): trace and design note

**Run:** builder0, `make native manoeuvre-wedge-trace WEDGE_RANGE=3500-3511 WEDGE_JOBS=3`, behaviour of main a0ae0aafd plus the probe
(`tests/manoeuvre/wedge_trace.gd`, committed in 60e5746b8), native path (`NATIVE_EXEC 19346 native, 653 handed back (face 653)`),
Locks and Terminus × fresh seeds 3500–3511, 180 s showmatch fights: 24 fights, 984 deaths. `table.txt` is the reader's output;
`wedge_deaths.jsonl.gz` has every wedged death's last 10 s (one sample every 0.5 s: position, speed, the drive's throttle/steer, pace,
driver, Traffic hold, unstick's clocks, hull contact, friends/enemies near, time since hit, brain option, order).

**The rate matches T5's census:** 81 of 984 (8.2 %; T5 8.3 %), every one `driving`, 80/81 hit in the last 10 s, 67 of 81 wheeled.
Each death is classified by `death_cause`, copied verbatim from far_census.

## What moved them (force on the death tick / over the last 3 s)

| force | death tick | last 3 s |
|---|---|---|
| **Traffic's take-turns hold** (`Traffic.holding`: waiting at a street mouth for another squad) | **40 %** | 38 % |
| ORCA slowing the route's pace (pace < 0.999, heading kept) | 32 % | 32 % |
| ORCA turning the steering point > 15° off the route | 10 % | 11 % |
| the drive's own steer at full pace | 10 % | 7 % |
| a k-turn leg | 7 % | 7 % |
| sideways shove (> 0.5 m/s across the hull) | 1 % | 2 % |
| unstick / pressing escape | 0 % | 1 % |

The stall rule was counting in the last 3 s for only 10 of 81, and unstick drove 1 % of the ticks. **Unstick doesn't see them, and it
shouldn't**: there are two populations, and neither is a stuck hull.

1. **Held for traffic under fire: 33 deaths (41 %), 32 of them wheeled.** Median 5.4 s into the hold, net 1.4 m. The three longest
   wedged-death episodes (18.0–18.3 s: locks s3510 Rust_Guns_1 gang_tank, terminus s3507 Green_Burners II_3 burner, terminus s3501
   Green_Hunters_8 law_ifv) are all holds. At the hold spot, Traffic asks for pace 0 facing a point 20 m along the squad's way. On
   **wheels**, throttle 0 at full lock is the plant's creep: of 106 sampled at-spot ticks, 67 show the hull moving at throttle 0
   (39 at full lock, ≥ 0.5 m/s): **the round-8 shuffle, in a lane mouth, while being shot.** The burner moved 1.5–2.5 m/s at
   throttle 0 for 9 s before it died.
2. **Slowed by ORCA among squadmates in a fight: 48 deaths (59 %).** Wedged for only a **median 1.2 s** before death, net 0.9 m,
   with friends ≤ 14 m (median 2.5) and enemies ≤ 56 m (median 4). The label fires on a crew that avoidance slowed for a second or
   two in a fight's crowd. That's ordinary combat traffic, not a hull pinned somewhere.

**The measurement:** `wedged` is "pace < 0.999 on > 50 % of 2 s and moved < a hull length". A deliberate hold (pace 0) and a short
avoidance slow both meet it, and T5's precedence (`yielding`, `blocked`, then `wedged`) files a held crew as `stuck:wedged`.

## Design note (to the orchestrator)

- **(A) No new "wedged" trigger in unstick.** Backing a crew off or pushing it through on this label acts on a held crew and on a
  crew slowed for a second in a fight. Neither is pinned, so a second unstick trigger has nothing true to act on. This drops round
  34's candidate as written.
- **(B) The biggest lever is traffic's: a held crew that is being hit leaves the hold** (or its squad's wait ends early under fire).
  Holds are 41 % of wedged deaths, 80/81 were hit, held a median 5.4 s against HOLD_CAP_S 20. That's Traffic's code
  (`Traffic.hold_of`, C29.3); it sits beside C35.8's "under fire" (T7) and should go to traffic, judged on T5's census. **Request to traffic.**
- **(C) Mine: a wheeled hull held to a standstill doesn't creep** (W1b). When the drive's pace is 0 (Traffic's at-spot hold, or
  avoidance says stop) a wheeled hull gets turn 0 too, so the plant never shuffles it. It stands on the heading it arrived on and the
  turret keeps its aim. What he'd notice: crews waiting at a lane mouth sit still instead of rocking back and forth. Native mirrors it
  (drive_native's `out_keep == 0` / pace 0 branch). **This alone will not move the wedged-death count much**: a still held crew is
  still `wedged` by definition and still under fire. It's a legibility fix, guarded for no harm.
- **(D) Measurement fix (traffic's `death_cause` / far_census):** a `jam:held` cause before `stuck:wedged`, so a crew holding for
  traffic is counted as what it is. Without it, every wedged-death number mixes the two populations.

## The bar W1b would file (before any number)

Fixed arenas only, **locks, terminus, sumps** (no random arena: R34.15, random arenas deal twins; the orchestrator's change, R35.7) × a fresh block of seeds (no twins, `seed_twins.py`), native path, the pair = stream +
native's mirror; base = `--nav-off=wheelhalt` (the switch). n = 72 fights an arm. **First:** the creep counter (the probe's `halt_creep_ticks`, wheeled pace-0 drive ticks still moving ≥ 0.5 m/s, read from
motion) is NON-ZERO in the base arm. **Deciding:** that counter → ~0 in the ON arm; wedged + held deaths not up beyond 1.645 se. **Guards (as T6b):** open deaths, stuck deaths, jam deaths, far
loops, kills and hit rate per team, each within 1.645 se paired; all deaths reported. The scout's fights (C33.9 shipped) are covered by
kills/hit rate.

## W1b's series, as agreed with the orchestrator (2026-10-19 afternoon, before any judged number)

- **Arms, both native:** base = `pair/native-w1b` f4f6bf1d2 as is (WHEEL_HALT_DEFAULT false); ON = `lab/w1b-on` 0015f48ad (the same
  + WHEEL_HALT_DEFAULT true). (A `--nav-off` arm would leave native's drive.)
- **Gate (C31.1):** `make native check` on 0015f48ad, sim-baseline moves attributed with the base tree.
- **Seeds:** 3820–3843 × locks/terminus/sumps = 72 fights an arm, through the wedge probe (`manoeuvre-wedge-trace`: the creep counter,
  causes, wedged/held deaths) and the fights census (`manoeuvre-fights FIGHT_AT=locks,terminus,sumps`: kills, hit rate, far rows).
- **Counter first:** `wheel_halts` > 0 in the ON arm, and `halt_creep_ticks` non-zero in the base.
