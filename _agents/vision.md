# Vision: Tank Squad

> Working title. Status: **aspirational north star**. Today's code is Milestone 1
> (one tank, direct control). This doc exists so early decisions don't close
> doors the vision needs open.

## The pitch

You don't drive a tank. You **command a squad of five** and win by writing a
better *strategy* than your opponent, then watching it play out.

You outfit each tank with equipment that has real trade-offs. You give each one
a role and a set of skills, in plain language:

> "Tanks 1 and 2 are bait: push up the east road, draw fire, fall back to the
> ridge when damaged past half. Tank 3 camps the ridge sector with the long gun
> and only fires at anything chasing the bait. Tanks 4 and 5 hold the perimeter
> around our flag and never leave it."

An **on-device LLM** (Gemini Nano on Android) turns that into a structured
**doctrine**, a data file the game simulation executes. The match is the
doctrines fighting.

The goal is to make **AI behavior design itself the gameplay**, with as much
room for "new-world AI complexity" as players want to explore.

## Why this is a good learning project

- It layers cleanly. Each layer is a complete game on its own: drive a tank → networked tanks → squads with hand-picked orders → strategies as data → strategies from language.
- Every layer is an industry-real concept: server authority, game AI (steering, perception, behavior trees or utility AI), data-driven design, LLM structured output, on-device ML, mobile export.

## The design space

### Equipment (trade-offs are the point)

| Slot | Options (initial brainstorm) | Trade-off axis |
|---|---|---|
| Hull / armor | light, medium, heavy; sloped front vs all-round | protection ↔ speed, turn rate, visibility |
| Engine | standard, turbo, quiet | speed ↔ noise/detection radius, fuel/heat |
| Main weapon | AP cannon, HE cannon, autocannon, guided missile (ATGM), mortar (indirect) | damage vs armor, range, reload, needs line of sight or not, min range |
| Sensors | optics, radar, acoustic | detection range ↔ reveals you, cost |
| Utility | smoke launcher, repair kit, decoy beacon, mine layer | one-shot vs recharge |

A shared **weight/points budget** forces choices: a heavy tank with a long gun can't also be fast.

### Roles and skills (the instruction set)

Skills are **parameterized behaviors the simulation knows how to run**. Players
(or the LLM) choose and configure them; they don't write code.

- `hold_sector(area, facing, fire_policy)`: camp a region, choose cover, hold fire until…
- `bait(route, retreat_to, retreat_when)`: be seen, draw fire, survive
- `guard_perimeter(anchor, radius)`: patrol and intercept
- `overwatch(ally, range)`: cover a teammate's approach
- `flank(target_area, approach)`: swing wide and avoid detection
- `scout(route)`: reveal enemies and report to the squad
- `regroup(point, when)`

Plus **triggers and conditions** (`when damaged > 50%`, `when enemy seen in sector B`,
`after 90 s`) and **squad communication** (a shared blackboard: enemy last-known
positions, who is engaged, who needs help).

Designing this vocabulary *is* designing the game. It must be expressive enough
for clever strategies and small enough for an on-device model to target reliably.

### The simulation needs (what the skills stand on)

- Navigation (Godot `NavigationServer3D` / navmesh)
- Perception: line of sight, detection radius vs stealth, fog of war, "last known position"
- Cover evaluation: which spots block line of sight to threats
- Ballistics and damage: armor facing, penetration, splash
- A decision layer per tank: behavior trees or utility AI, driven by the doctrine

## Where the LLM fits, and where it must NOT

**The LLM is a compiler, not a pilot.** It runs at *authoring time* and turns
natural language into doctrine data. It never runs inside the 30–60 Hz game loop.

Why this is non-negotiable:
1. **Latency.** On-device inference takes hundreds of milliseconds to seconds. A tick is 16–33 ms.
2. **Fairness.** Phones differ wildly in inference speed. If the LLM decided in real time, faster phones would play better.
3. **Authority and cheating.** Doctrine is *data* that the server validates against a schema. A modified client can't send "my tank has 10× armor"; it can only send a doctrine that the server checks.
4. **Replays and debugging.** Same doctrines + same map → a match you can re-simulate, inspect, and balance with headless batch runs.
5. **Availability.** Not every device has Gemini Nano. Web players and older phones still need a form-based doctrine editor, plus optionally a cloud model. The doctrine format is the contract that all authoring paths share.

A later, *optional* extension: a bounded "commander" re-plan, where the LLM may
revise doctrine every N seconds (for example, 20 s) from a summarized battle
state. It still emits data, and the server still enforces the cadence. Treat it
as a separate design decision with its own fairness analysis.

## Platform facts to re-verify when we get there

These were believed true in 2026-09 but move fast. **Verify before building the Android layer.**
- Gemini Nano on Android runs through the system **AICore** service. App developers reach it through Google's **ML Kit GenAI APIs**, including a general-purpose prompt API. It's available only on specific recent devices, so plan for capability detection plus fallback.
- Godot 4 exports to Android. Native Android APIs are reached through a **Godot Android plugin** (Kotlin/Java, v2 plugin architecture) that exposes methods and signals to GDScript. The Gemini Nano bridge would be one such plugin.
- Chrome has shipped experimental built-in AI APIs backed by Gemini Nano on desktop. If that's stable by then, web players might get on-device doctrine compilation too, reached through `JavaScriptBridge`. Unverified; don't design around it.
- Structured output matters: constrain the LLM to the doctrine JSON schema. Validate *everything* on the server regardless.

## Open design questions (decide deliberately, record the answer here)

1. **Real-time vs asynchronous matches.** If players only author doctrine, a match doesn't need both players online. The server could simulate it and let both watch or replay later. This massively simplifies networking and servers. Real-time spectating with mid-match doctrine swaps is more exciting and harder. Maybe both?
2. **Determinism.** Godot physics isn't bit-deterministic across platforms. We keep the server authoritative and record *state snapshots* for replays rather than relying on lockstep re-simulation. Revisit only if replays get too big.
3. **Direct control's future.** Keep it as a tutorial or "possess a tank" mode, or remove it once squads exist?
4. **Doctrine format.** JSON (portable, LLM-friendly, schema-validatable) is the default assumption. A Godot `Resource` is nicer in the editor but awkward for an LLM to produce.
5. **Behavior engine.** Leaning: **utility AI with player-tuned directives, switched by phase conditions** (a hybrid). Where player skill comes from, and the experiments that decide it: [squad_ai_design.md](squad_ai_design.md).
