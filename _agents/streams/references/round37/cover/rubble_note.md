# Taller rubble (his Q1 alternative): what it would take

_cover, round 37, 2026-10-21. Notes only: no art made, no paid request. Arenas at main 821c7f494._

**The question.** If a waist-high jersey barrier hides most of a low car but only a fifth of a 4 m truck (Q1, kept honest),
could chest-height rubble (about 1.2 m, low enough to see over) give the big vehicles real hull-down cover?

## What exists today
- **No rubble, debris or sandbag prop exists.** The kit's low piece is `barricade` (ArenaKit.PROPS: 6.0 x 0.9 x 0.8 m), drawn in
  code with no art asset: `kit_yard.gd` builds the jersey profile (a wide foot, sloped waist, narrow top), one MultiMesh per 96 m
  light cell. The closest thing to rubble is `wreck`, an approved paid Meshy husk (`prop_wreck.glb`), but its box is 2.0 m tall,
  above eye height (1.3 m): full cover, not hull-down.
- Adding a type is not additive (ArenaKit's note): the `ArenaKit.PROPS` entry, its `prop.<type>` theme slot and its scene land in
  one commit, owned by whoever owns the art (feedback this round).

## Two hard limits (these decide it)
1. **Rounds fly flat at muzzle height, 1.05-1.14 m** (Units `muzzle_height`; Shell/Match `HIT_MASK` = layers 1+2, which obstacles
   are on). A piece taller than ~1.0 m is physically hit by every flat round crossing it, **including the sheltering crew's own
   shots**: the crew could see over it but not shoot over it. Today's barricade (0.9 m) clears every muzzle, which is why it
   works. So "chest height" needs ONE rules change first: low cover on a collision layer shells do not hit (the hull-down roll
   already decides what it stops). That is combat's path (rules), not art.
2. **Eye height is 1.3 m for every hull** (Perception.EYE_HEIGHT), so low cover stays under ~1.25 m or it starts blocking sight
   and turns into ordinary full cover. Under the honest rule, a 1.25 m piece hides height share 1.25 / hull height:

   | hull | height | barricade 0.9 m | rubble 1.25 m |
   |---|---|---|---|
   | Rat Rod (gang_scout) | 1.24 | 0.73 | 1.00 |
   | scout | 1.50 | 0.60 | 0.83 |
   | syn_tank | 1.85 | 0.49 | 0.68 |
   | ifv | 3.08 | 0.29 | 0.41 |
   | tank | 4.08 | 0.22 | 0.31 |
   | gang_tank (War Rig) | 5.24 | 0.17 | 0.24 |
   | law_suppressor | 6.18 | 0.15 | 0.20 |

   **Taller rubble lifts a 4 m tank from about a fifth to about a third of its frontal hits stopped. It does not make big trucks
   hard to hit.** Only a rule that stops reading hull height (every hull treated as shown only above the cover, as a "turret
   showing") would do that, and that is the dishonest version Q1 recommends against.

## If he still wants it
- **Art:** the pipeline can make it either way. (a) **Procedural, like the barricade** (no money): a low broken-concrete berm /
  rubble ridge built in `kit_yard.gd` as one more MultiMesh kind, the same kind of work as the barricade's profile, plus the theme slot. (b) **Meshy**
  (paid): concept images on the tap-to-approve page first (2-3 directions, his standing rule), then image-to-3D, fitted to its
  box the way the wreck was. One model plus 1-2 variants (rotated and mirrored per instance) covers every map.
- **Pieces:** the same sites as the K5 drafts. Option (a) re-shape: 11 mirrored swaps = **22 pieces** on 7 maps. Option (b)
  added runs: 4 maps x 2 runs x 2 mirrors x 2 pieces = **32 pieces** (6 m each). Either way it is one model, instanced.
- **Order of work:** rules moves low cover off the shells' hit layer, art adds the type and slot, cover places it (granted
  `tools/make_arenas.py`, R37.7), then Bar K's series on the new maps.

**Cover's recommendation stands:** keep the honest rule and the 0.9 m barricade; place barricades where the fighting is (K5);
measure. Taller rubble buys a big hull roughly +10 points of frontal protection at the cost of a rules change and a new
asset. It is worth doing only if Bar K's series shows hull-down working for the low cars and he wants the same feel for the
trucks.
