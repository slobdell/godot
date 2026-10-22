# O3's Crossing 5 click failure, traced (builder0 light, native, stream/orders a87449d6b = c14ec0d80 + docs/tests + the
# artillery fix; no artillery in the probe). Seeds 3717 3718 3719 3723, main v whole, probe trace squad 4. n 1 each.
- Reproduces the judged rows exactly: whole crosses in 3717 / 3719 and never arrives in 3718 / 3723; main is clean in all four.
- Squad 4's anchor is the same in both arms, (-100.2, 29.9) in 3717: at the west deck's south end (deck [-99, -3, -85, 31]).
- main: that place is filled by crews dealt from ANOTHER squad (Delta_4/5 under element Echo, goals (-103.6, 32.3) and
  (-103.3, 31.2)); no goal jumps.
- whole: squad 4 drives in whole. At t=22, still ~45 m out, Delta_1's goal jumps from its seat (-101.2, 32.1) to
  (-104.8, -7.1), 39 m north, past the deck on the far bank, and it crosses (goals_across at 21.5 s).
- So the cause is the halt lay at a bridge mouth re-laid mid-drive with a front seat across the deck (round 36's stretch
  "covered by the halt lay" holds for the click geometries it tried, not this one). The fix belongs to the bridge-mouth lay
  (deck_clear for plain clicks or the halt lay's deck test), as a new arm on fresh seeds.
