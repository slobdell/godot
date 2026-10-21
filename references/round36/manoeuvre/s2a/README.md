# S2a (h1bside + yieldgap): evidence beside the series

## (1) The water condition (R36.27): side points over water, 0 of 15

`side_water_86e058424_builder0.txt`. Lab `lab/s2a-sideprobe` `86e058424` = ON `bf678480c` + an `H1B_SIDE` row per side point
(measurement only, never merged). Builder0 light lane, `manoeuvre-fights` Locks + Sumps x 6540–6563 (48 fights, the series'
seeds), `--brains-off=native` (the GDScript twin; the native exec prints no rows).
- **Counts:** 26 fires, 15 side points + 11 stands. None was in water or a pit, on the far bank, reached over water off a deck,
  or on a deck.
- **Terminus** has no terrain entries: 0 by construction.
- **Caveat:** the nearest point was 43.8 m from water. The ship condition's lab case covers the bank:
  `test_manoeuvre_h1b_side::test_beside_the_canal_the_side_point_stays_on_its_bank` (`33919af3d`, builder0 light 4/4, both paths).
  - **Locks north bank**, the friend's water side 1 m off the rim, the goal a little towards the water: the water-side point is
    refused (not on the navmesh) and the land side is taken. Side point z 15.94, the hull's least z 10.27 (the canal is |z| <= 7),
    past at 19.6 s; base re-rams with 5 fires.
  - **Bridge mouth:** the rim is cut at a bridge, so the open deck mouth is room. Both arms drive round over it with no H1 fire,
    so the side rule never arises there. This is pinned as ON = base.

## (2) Rust_Eyes_3, Locks 6550: one crew picks 9 side points on one parked artillery and moves 1 m in 30 s (traced)

`trace_locks-6550_Rust_Eyes_3.txt.gz` (`--turn-trace=Rust_Eyes_3`, the same lab tree, GDScript twin, builder0 light).

A law_scout routes past Rust_Battery_2 (law_artillery, another element, arrived and parked). Its route waypoint is already
(45.5, −83.7), a point beside the artillery, and driving straight at it clips the artillery's hull: est 13 m/s, real 0 m/s,
the artillery its only collider. H1 fires and backs it 3 m, H1b's far branch fires the side rule, and the side point chosen is
(45.3, −84.0): **the same place the route was already steering at.** It drives back into the same corner. This repeats every
~3 s (frames 1563–3352, 9 picks, net 1.0 m).

**Cause:** `_side_clear` tests only the point, against hull CENTRES (and the friend at half its radius). It never tests the
straight drive from here to the point against the friend's oriented box. The point sits abreast of the friend's centre on the
perpendicular to the here→friend line. A long friend (an artillery) seen at an angle has a corner across that drive.

**How often:** in the 48 fights, 17 crew–friend pairs reached the side rule. 15 fired once (a step or a stand, as designed),
Rust_Spears3_2 twice (net 0.9 m), Rust_Eyes_3 9 times.

**What he'd see:** a scout nosing into a parked artillery's corner every 3 s for half a minute (base did the same, with H1's
re-ram instead of a side pick).

**Fix candidates (not built; the series judges bf678480c as is):**
- (i) `_side_clear` also rejects a point whose straight drive from here passes within my half-width of the friend's oriented
  hull box (its length and heading, not a circle).
- (ii) A side step that ends with the hull still blocked by the same unmoved friend makes the next far fire on it a STAND (as
  if no side were clear), until the friend moves or the goal changes.

(ii) bounds the loop to one step whatever the geometry; (i) picks better points. Deciding lab: a long parked friend seen at
30–45°, the asker diagonal behind its corner. ON takes a point whose drive clears the box, or stands; at most one side step on
an unmoved friend; both paths.
