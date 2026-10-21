# T8 (R35.7): a held crew that is being hit leaves the take-turns hold. Design note (DRAFT; bar filed before any number)

**What he will notice.** A crew waiting at a street mouth for another squad to come through no longer sits still while it is
being shot; it drives on (and sorts out the meeting by the ordinary give-way, T7 included).

**Why.** Manoeuvre's W1 (builder0, native, main a0ae0aafd, Locks/Terminus × 3500–3511, 24 fights, 984 deaths): 81 stuck:wedged,
80 hit in their last 10 s; 33 of them (41 %) HELD by the T1 hold at a street mouth, a median 5.4 s into the hold; the 3 longest
wedged episodes (18 s each) are holds. The hold caps at HOLD_CAP_S 20 s and knows nothing of fire.

**The rule (`--traffic-on=holdfire`, DEFAULT_OFF until judged).** In `Traffic.hold_of(me)`, after the cap and the passed tests:
a crew hit within `Movement.UNDER_FIRE_S` (5 s, T6/T7's "under fire") is released from its squad's wait, as a passed crew is
(`released[me] = true`, counted `released_fire`; the wait ends when every crew is released). Released for good for that wait (no
re-hold when the hits stop: a crew that has started into the mouth is not called back). The other crews of the squad hold on
unless they are hit too. The passing squad is unchanged. Hits only (`Tank.ticks_since_hit`, deterministic, on both drive paths);
read from the table's movers (`Traffic._hit`). **No native mirror needed:** the native drive calls back into GDScript's `Traffic.hold_of` (`NativeTraffic.avoid_hold`, drive_native.cpp ~545), so the rule runs on both paths.

**Interactions.** T7: the released crew meets the passer head-on in the street; the give-way decides as today, with T7's rule if
it is on. The battery rule: unchanged. Holding gates (`Traffic.holding` in `_negotiate`, `_track_progress`, C29.3's gates): lapse
LIVE_TICKS after the release, as for a passed crew.

**Risks to guard.** Released crews meeting the passing squad head-on in the street (contacts, jam deaths), crossings' arrivals
(T1/T3's own stage), far loops.

**Bar (FILED on main by the orchestrator from this draft, with its two lines below; filed before any number, read after T7's series).** Pair = main (with T7 as judged) + T8
(`--traffic-on=holdfire`, DEFAULT_OFF) + the ON flip (no native mirror: hold_of is called back); base `--traffic-off=holdfire`; switch-OFF sim-baseline
inertness beside the C31.1 check. Native, builder0 start to end, pinned, 180 s showmatch. FRESH fixed arenas {terminus, locks,
crossing, gorge, parade} × 1800–1827 (n 140; moved off 1700–1727: traffic's T7 dev read used Terminus/Locks 1700–1701; the hold fires on street mouths, so the street arenas; crossing for its bridge
mouths; sumps swapped out), no random arena, no twins. k = 1.645, paired se.
- **G (deciding gain): held deaths** = crews that die while `Traffic.holding` was true the tick before, or within 3 s of a hold
  ending (jam_census's `held` field, (D)'s sub-cause, reported beside T5's causes, which stay as they are): arm < base and
  (base − arm) − k·se > 0.
- **Guards:** (1) stuck deaths ≤ base + k·se; (2) jam deaths (T5) ≤ base + k·se; (3) open deaths ± k·se; (4) far loops ≤ base +
  k·se; (5) kills ± k·se, hit rate ≥ base − k·se; (6) all friendly hull contacts ≤ base + k·se; (7) crossing arrivals
  (traffic-series 44–46 × 6, the T1/T3 stage) ≥ base − k·se a case; (8) T1's own hold verdicts still taken (`tr_holds` ≥ half of
  base: the hold is not switched off by the back door).
- **Counter first (the orchestrator's addition):** `released_fire` > 0 in the arm before any guard is read.
- **Guard (the orchestrator's addition): all deaths per team** ≤ base + k·se (k 1.645, paired): T6's lesson, a rule can move deaths
  from one cause to another one for one and per-cause guards alone can miss a spread.
- **Reported:** `released_fire`, hold seconds, standoffs, all deaths, deaths by cause.
- **Sizing:** W1's 33 held-wedged deaths in 24 fights ≈ 1.4 a fight on Locks/Terminus; at n 140 (some arenas with fewer mouths)
  expect ~100–150 in base, se ~12–15; a halving clears by ~4 se.
