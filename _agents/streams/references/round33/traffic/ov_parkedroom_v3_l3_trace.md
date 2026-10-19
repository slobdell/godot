# parkedroom v3: L3's kill drop, the dev read of random-859 (R33.37; not judged)

Tree `pair/parkedroom-on-v3` `ef7f7901f` (game code = `6d0e00652`, the judged pair; tooling adds `far_census
--far-kills=on`, FAR_KILL rows that only read state). builder0, `make native traffic-far-census FAR_RANGE=859-859
FAR_AT=random`, both arms (base `--traffic-off=parkedroom`), --fixed-fps 30, n 1 fight. The fight reproduces the judged
series exactly: kills 54 -> 34 (census team kills 43 + 11 v 19 + 15).

**Lost, by team and hull (base -> arm):**

| side | hull | base | arm |
|---|---|---|---|
| Green (team 0, syndicate) | scout / ifv / lancer / tank | 6 / 2 / 2 / 1 = 11 | 6 / 3 / 3 / 3 = 15 (+ friendly) |
| Rust (team 1, gangs) | artillery | 14 | 3 |
| Rust | scout | 16 | 8 |
| Rust | ifv / support | 7 / 7 | 4 / 5 |

**By time (lost a 30 s):** base 12 / 16 / 15 / 9 / 3; arm 10 / 9 / 11 / 5 / 0. The last loss was at 127.8 s in the base,
99.7 s in the arm. First loss 7.2 s in both.

**What the victims were doing the tick before:** base driving 36, arrived 12, blocked 5, giving way 2; arm driving
20, arrived 12, blocked 3. No victim owed a way back. In the base, Rust's artillery was lost steadily from 48 s
(14: 9 while driving, 3 blocked, 2 giving way). In the arm, 3 were lost.

**Rooms in the arm:** 19, split across both sides (Rust 10, Green 9), from 13 s on (13, 17, 27, 31 ... 89 s).

**Cause (one line):** in random-859, room give-ways from 13 s on branch the fight, and the base's rout of Rust's
artillery park (caught driving or stuck) never happens, so the losing side loses half as many. The kills fell
because one side lost less, NOT because the same hits stopped killing. The guard read that as "fewer kills", and it is
two-sided by design.

Not shown (one fight): whether parkedroom generally spares crews that would die stuck or in a jam across the 48
random fights. The judged series has no FAR_KILL rows. That would need a fresh bar.
