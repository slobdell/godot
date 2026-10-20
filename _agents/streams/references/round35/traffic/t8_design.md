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
the table carries it as a column read in `refresh`. Native mirrors (`NativeTraffic` hold).

**Interactions.** T7: the released crew meets the passer head-on in the street; the give-way decides as today, with T7's rule if
it is on. The battery rule: unchanged. Holding gates (`Traffic.holding` in `_negotiate`, `_track_progress`, C29.3's gates): lapse
LIVE_TICKS after the release, as for a passed crew.

**Risks to guard.** Released crews meeting the passing squad head-on in the street (contacts, jam deaths), crossings' arrivals
(T1/T3's own stage), far loops.

**Bar (to be filed before any number, after T7's series):** fixed arenas, fresh block, native, builder0, n 140. G: deaths of crews
held at a mouth (`jam:held`, (D)'s sub-cause, plus stuck:wedged while held) arm < base − k·se. Guards: all stuck deaths, jam
deaths, open deaths ± k·se, far loops, kills/hit rate, all friendly contacts, crossing arrivals (traffic-series 44–46 × 6).
