# Vision: Tank Squad

> Working title. **Where the game is going and why.** Rewritten 2026-09-15 from the lead's decisions after
> round 1. The rules and player experience are in [game_design.md](game_design.md) (the source of truth
> for design); the look is in [art_direction.md](art_direction.md).

## The pitch

A **die-hard real-time squad tactics game** set in a Death Race gladiator arena. You buy an army of
**over-the-top converted war machines** (an armored prison bus with a dozer blade, a rally-truck scout with
a machine gun welded to the hood), split it into squads, and out-command your opponent. Every vehicle fights
smart on its own; your job is to put the right units in the right place at the right time.

## Who it's for, and what we refuse to build

The lead, 2026-09-15: *"most modern games suck because they're optimized for getting clicks or eyeballs. True
die-hard games seem to have died out to make them mass appeal. Many modern games make money by buying
inventory or buying shortcuts. We don't want that, we want a die-hard gamer's game (limited of course to our
constrained UX capabilities eventually on a phone)."*

- **No pay-to-win, microtransactions, premium currency, loot boxes, ads, or energy timers.** Progression is
  earned only by playing (credits from wins unlock units and budget tiers; [game_design.md](game_design.md)).
- **Business model (intent):** the online/web version is **free**; the **Android app is a paid app**.
- Depth over onboarding funnels. Respect the player's intelligence; teach through play (challenges, clear
  counters), not through nags.

## The vibe

**Over-the-top eccentric vehicles** in a night-time gladiator arena with cheering crowds: Mad Max × Death Race ×
Blade Runner. The lead: *"What made Mad Max and Death Race so good was the over-the-top eccentric vehicles. This
makes it go from a nerdy army game to a fun game"* (in the spirit of classic Metal Gear Solid). The assets
stream's up-armored prison-bus dozer found this vibe in round 1. Photoreal and grimy, neon-lit, never cartoon.

## Platforms

- **Web** (WebAssembly, free) and **Android** (paid), from one Godot codebase; a headless server build exists.
- **Mobile first:** single taps, drags, and pinches; no right-click, no hover, no keyboard required.
- Online play: players host matches through our relay broker, so our servers never simulate (built in
  round 1, paused while the core game gets fun); lockstep for ranked play is feasible (integer-core spike).

## Why this is also a learning project

The lead is learning Godot ahead of their son, who learns game programming with Claude. So the repo explains
*why* as well as *what* (`_agents/`, `teaching_notes.md`), and every layer is an industry-real concept:
server authority, game AI (utility scoring, tactical positioning, squad tactics), data-driven design,
asset pipelines, mobile export.

## History: how the vision moved

- 2026-09-12: "players author doctrine for 5 tanks, compiled by an on-device LLM; no direct control."
- 2026-09-13: the lead chose live squad commanding on a tactical map, with autonomous tank brains.
- 2026-09-14: budgeted armies, shields, ammo, heat, MechWarrior-style loadouts; the cyberpunk look; the
  Death Race prison dozer as the art north star.
- **2026-09-15: fixed unit types instead of loadouts (StarCraft-style counters), up to 5 squads, credits and
  progression, friendly fire, sophisticated unit AI, tap-only commanding, gladiator arena with crowds, no
  pay-to-win.** The LLM is now a possible later *commander* issuing the same squad commands, not the core loop.

## If an LLM joins later: where it fits, and where it must NOT

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

