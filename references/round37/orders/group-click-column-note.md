# Design note: one click for the whole army lays a COLUMN OF WEDGES (orders, round 37, R37.29)

**His words (game_design.md, 2026-10-21, Terminus):** selecting all and clicking one point, "the target waypoints for each
squad was all over at far away places ... A bunch of units drove through streets ... I immediately lost control of the army".
**His proposal:** lay a group click as a column of wedges, one squad behind the other along the approach, the squad nearest
the click in front and the farthest at the back, sized to the corridor's real width; spread out only on open ground; every
squad keeps its own vehicles.

## 1. Why his places landed 130 m apart (recording 2026-10-21T21-52-44-terminus, tick 1108)
- He had selected all: Hunters, Battery, Eyes (three squads) and four loose Lancers, bunched round (-3, 55) (he had sent
  each squad to (2.9, 57.4) earlier). He clicked (-29.3, 85.8), about 40 m away.
- `RtsControls._order_squads` -> `SelectionSquads.ranks`: four blocks as a BODY. The three squads stand abreast in a front
  rank ACROSS the click, each slot as wide as the squad's halt frontage (five vehicles at 14 m: 57 m) plus GAP_M 14 m, so
  their anchors are 71 m apart: (-93.2, 54.4), (-29.3, 85.8), (34.6, 117.2). The front is ~200 m (MAX_FRONTAGE_M), laid as
  if the ground were open. On Terminus the outer two anchors are a block or more over, in other streets; `ground_cap` only
  refuses an anchor the click cannot reach by ground, and a street one block over is reachable, so it stands.
- The loose Lancers take the rank behind, 40 m back toward where the army came from: (-7.1, 51.3).
- Then `untangle` re-deals vehicles between the squads whose paths would cross (Hunters ended with Battery_4 + Eyes_5):
  the "squads mixed up" he saw.
- It recurs at 45.1, 56.1, 58.5 and 85.0 s: every all-army click on the street grid.

## 2. The proposal, concretely (one switch, `--group-lay=column`, OFF until its bar passes)
**Where:** `_order_squads`, a click with a point (`move`, `attack_move`) for two or more squads, not queued (queued legs
keep D6 / the gate). It replaces `ranks` + `never_behind`; `ground_cap`, `ground_anchors` stay after it.

**Reuse:** round 34/35's gate (`RtsControls.gate_anchors`, `gate_width`) already does most of this for an IN-BETWEEN
waypoint: abreast as the clear width allows, ranks behind along the approach, nearest in front, single file in a gap, a
deck stops the scan. His final click becomes a gate whose ranks are halts.

**(a) The approach.** `SelectionSquads.approach_of(blocks, click)`: from the body's centre to the click (his drawn facing
does not set it). If the body stands within ~10 m of the click, the team's forward.

**(b) How the corridor width is read.** `gate_width(click, across)` on the navmesh of an ordered vehicle: each side, in 2 m
steps, a point counts while it is reachable from the click by ground within 1.5 x straight (+1 m) and no deck lies between
(`crosses`). The scan is widened from 60 m to 100 m each side for this use (GROUP_SCAN_M), so "open" can be told apart from
"a wide street". Then **each rank is re-read at its own point** (the rank's centre on the approach line, `gate_width`
there) and centred in its own clear width, because a street bends and a rank 40 m back may stand in a different street
than the click. A rank whose own point is not reachable within 1.5 x straight from the click (round a block) steps back
along the approach until it is (the column follows the road, it does not jump a block).

**(c) Abreast or stacked.** k = floor((clear + GAP_M) / (frontage + GAP_M)), at least 1, at most MAX_ABREAST (3) and
MAX_FRONTAGE_M (200), where frontage is each squad's WEDGE frontage (his "column of wedges"; at 14 m a wedge of five is
57 m wide, a wedge of three 29 m). If even one wedge does not fit (clear < wedge frontage), the squad halts narrower: the
existing halt shape for lanes/dense (herringbone, 11 / 8 m spacing), whose frontage is read the same way; below that,
single file on the click line (the gate's rule).

**(d) Where open ground switches to spreading.** Open = the clear width reaches the scan limit on both sides (>= 2 x
GROUP_SCAN_M, nothing stopped it). Then k is what MAX_ABREAST / MAX_FRONTAGE allow, which is today's body: on open ground
nothing changes. Between, k grows with the width read: a 70 m street takes one wedge of five abreast; a 150 m plaza two.

**(e) Stacking order.** By how far along the approach each squad's centre already is: the one nearest the click (farthest
along) takes the front rank, the farthest the back (`gate_anchors`'s by_along). Within a rank, left to right by where they
stand across the approach, so no two cross on the way in. Rank step: the deepest halt depth + GAP_M, or the nested
`rank_step` when all share one shape (round 22's ruling (c)).

**(f) Every squad keeps its own vehicles.** No crew re-deal (`untangle`) on a group click under this switch. When two
squads' drives to their places cross, swap the squads' places whole (O3's `untangle_whole`, already built and judged
for its deciding line: squads arriving short 46 -> 0). O3's standalone retry is dropped (R37.29); it folds in here.

**(g) Bridge mouths.** The width scan stops at a deck, and ranks step back along -approach, away from the deck. O3's
Crossing 5 trace (66fda2d46): a squad's halt at the west mouth was re-laid mid-drive with a front seat 39 m over the deck.
So `deck_clear` (today queued legs only) applies to these places too: a place whose squad's reach touches a deck steps back
along the approach until clear, unless he clicked on the deck.

## 3. Measurement (before any bar)
- **His click, as a lab** (`test_control_group_click.gd`): his blocks and click on Terminus (real navmesh), today's anchors
  (spread ~130 m end to end, two anchors in other streets) v the column's (all on the click's street, stacked along the
  approach, nearest squad in front). Deterministic.

- **Lab result (laptop GDScript, 2026-10-21, `test_control_group_click`):** today's anchors from his click spread 128.8 m
  (recording ~130 m). The corridor at the click (`gate_width` across the approach) reads 60 + 16 m, and 2 of the 4 anchors
  stand OUTSIDE it. "Reached by ground within 1.5 x straight" counts 0: Terminus's streets join diagonally, so that read
  cannot see his complaint; the corridor read can.
- **Probe columns** (orders-probe, every cell): `outside_m` / `outside` (anchors standing outside the corridor read at the
  click, and by how far), `spread_m` (the largest distance between two squads' anchors), redealt crews, plus the existing
  guards.

## 4. Bar shape (to file before any arm number)
Orders probe, the 12 street cells (locks / crossing / terminus x 3 / 5 squads x click / route), fresh seeds, main v
`--group-lay=column`. Deciding: anchors outside the click's corridor summed, arm <= 25 % of base, AND crews re-dealt across squads, arm 0.
Guards (R36.6's, per cell): all-in <= base x 1.2 + 3 s, no more never-in, twitch worst <= base + 3 m, end foreign min >=
base - 3 m, crossed no higher; friendly contacts (probe) <= base x 1.1 + 5. An open-ground cell (yard_open) as a no-change
guard: anchors identical to main's.
A pass ships ON. Symmetric? The CPU never issues a multi-squad click, so this is his control only.

## 5. Open questions (decided by default; the lead can overrule)
- Column of WEDGES even in a street where a wedge is wider than the street? Default: no, narrower halts as (c).
- Attack-move: the front rank at the click, the rest behind (as today's ranks: nobody drives past his point).

## 6. Built (v1, `--group-lay=column`, OFF): what his click reads like (laptop GDScript, lab)
- The clear width at his click, read across 12 headings: about 16 m to one side (a building edge), 100 m (the scan limit) to the
  other on almost every heading. His click is not in a narrow street; it stands at the edge of open ground. Today's body put two
  of its four anchors beyond that 16 m edge, among the streets behind it.
- `column_lay` centres each rank in its own clear width, so the body shifts onto the open side: every anchor inside the corridor
  read at its rank (lab assertion), the squad nearest the click in front, the farthest at the back (lab assertion). Spread 95.8 m,
  on open ground (today 128.8 m, across the edge).
- A street narrower than one squad lays single file on the approach line (pure lab case); open ground both sides lays nothing
  (today's body, the yard_open no-change cell).
- Open for the bar: the route metric (the share of each squad's drive that leaves the click's corridor, R37.29's addition (1)),
  and the paired shots of his click, main v column (addition (2)).
