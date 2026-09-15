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
- **Business model (intent):** the online/web version is **free**; the **Android app is a paid app**. A paid
  desktop build (Steam) is under discussion.
- **Keep our running costs near zero** (the lead, 2026-09-15): *"making the game servers strictly match makers and
  packet routers."* Players' devices simulate (player-hosted now, lockstep for ranked later); LLM opponents use the
  player's own key or on-device models. Plan: [server_management.md](server_management.md) §5.
- Depth over onboarding funnels. Respect the player's intelligence; teach through play (challenges, clear
  counters), not through nags.

## The vibe

**Over-the-top eccentric vehicles** in a night-time gladiator arena with cheering crowds: Mad Max × Death Race ×
Blade Runner. The lead: *"What made Mad Max and Death Race so good was the over-the-top eccentric vehicles. This
makes it go from a nerdy army game to a fun game"* (in the spirit of classic Metal Gear Solid). The assets
stream's up-armored prison-bus dozer found this vibe in round 1. Photoreal and grimy, neon-lit, never cartoon.

## Platforms

- **Desktop first, Steam as the primary target for now** (the lead, 2026-09-15: *"perhaps that even means we target
  Steam as our primary platform so we can shift, right click, etc"*): StarCraft-style mouse and keyboard controls to
  find the fun. **Web** (free) and **Android** (paid, with on-device Gemini Nano, which the lead still sees as *"the
  whole magic of this system"*) follow from the same Godot codebase once the game is fun; touch gets its own adaptation.
- History: rounds 1–2 designed mobile first (single taps, no right-click); superseded because commanding felt
  burdensome.
- Online play: players host matches through our relay broker, so our servers never simulate (built in
  round 1, paused while the core game gets fun); lockstep for ranked play is feasible (integer-core spike).
  Cross-play: web, Android, and any desktop build share one player pool.

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
- 2026-09-15 (later): the LLM commander becomes a planned **optional opponent**: bring-your-own Gemini key first,
  as the proving ground for on-device Gemini Nano on Android (below). **Factions decided** (game_design.md): the
  Condemned, road gangs, the Law, and the Syndicate, with wildly different trade-offs. A Steam build is under
  discussion.

## The AI Commander: an optional LLM opponent (decided 2026-09-15)

The lead: *"we'll plan on a bring your own key model. The use case would be to make the game more fun by making
the opponent smarter, and it would otherwise load test our eventual intended Android use case. We want to be
pioneers in the Gemini Nano space for android."*

**What it is.** An optional opponent whose *commander* is an LLM. Every ~10–15 s it reads a compact battle summary
and issues **SquadCommands**, the same data the player's taps produce. The heuristic unit brains still drive, aim,
and take cover. The heuristic `CpuCommander` stays the default and must be a good opponent on its own (the die-hard
promise); the AI Commander is the fun extra: a more surprising opponent that can state its plan, taunt through the
announcer, and explain itself in an after-match debrief.

**Why, in order:**
1. **Fun:** a smarter, less predictable opponent.
2. **The proving ground for on-device Gemini Nano on Android.** The web and desktop version uses the same prompt,
   JSON schema, cadence, and fallback as the Android app will, so shipping on Android is a backend swap, not a
   redesign. We intend to be early: few games use on-device LLMs yet.

**Backends** (one commander-backend interface; the game never knows which one answers):

| Backend | Where | Status |
|---|---|---|
| Scripted fake | tests, CI, the sim baseline | first, so everything else is testable |
| **Bring your own key:** the player pastes their own Google AI Studio key | web, desktop | **first real backend** |
| **Gemini Nano on device** via ML Kit's GenAI Prompt API (AICore) and a Godot Android plugin | Android (paid app) | **the target** |
| Chrome's built-in Prompt API (Gemini Nano) | desktop Chrome on capable machines | bonus, detect and use when present |

**Bring your own key, the rules:**
- The key is stored only on the player's device, and the game calls Google directly. It never touches a server of
  ours, so we can't leak it and it costs us nothing. Nothing is sold (vision: no microtransactions).
- The free tier covers it (checked 2026-09-14: Gemini 3.5 Flash-Lite and 3.1 Flash-Lite have free input and output).
  Free-tier content is used to improve Google's products; say so in one line in settings. Rate limits are per
  Google Cloud project, unpublished, and have been cut before, so design for them to shrink.
- Budget: ~50 calls for a 10-minute match, with small prompts and short JSON replies.

**Non-negotiables (all backends):**
1. **Never in the tick loop.** Inference takes hundreds of ms to seconds; a tick is 16–33 ms. The game sets the
   cadence, not the device's speed.
2. **Schema-constrained output, validated like player input.** Invalid or illegal orders are dropped.
3. **Replays stay deterministic:** the LLM isn't, so its orders are recorded like any other input and a match
   re-simulates from the recording.
4. **Fail quietly:** a rate limit, timeout, bad JSON, or missing model hands that decision to the heuristic
   commander. A match never stalls.
5. **Fairness:** against the CPU only. Never in ranked.
6. **Design for Nano's size.** Nano is far smaller than Flash-Lite. Tune prompts and the battle summary against the
   smallest model available during development (Google describes Gemma 3n as sharing Nano's architecture; verify
   it is on the Gemini API), so we never build a design only a big model can follow.

**Measure it** like any brain (ai stream's ladder): win rate against the heuristic commander, latency, tokens per
match, and fallback rate per backend. That's the load test for Android.

The 2026-09-12 idea of an LLM *compiling doctrine* before a match is superseded, but the reasoning carries over:
commands are data, validated, never real-time control.

## Platform facts (checked 2026-09-14; re-verify before building each layer)

- **Gemini API pricing:** free tiers exist for Flash-Lite (3.5, 3.1) and Flash (3.5–3.8). Paid 3.5 Flash-Lite:
  $0.30 / $2.50 per million input / output tokens. [Pricing](https://ai.google.dev/gemini-api/docs/pricing),
  [rate limits](https://ai.google.dev/gemini-api/docs/rate-limits) (per project, shown in AI Studio).
- **Gemini Nano on Android:** the system **AICore** service, reached through **ML Kit's GenAI Prompt API** (alpha
  since 2025-10). Supported on Pixel 8+, Galaxy S24+, and some Xiaomi and Motorola phones; best on Pixel 10. Plan for
  capability detection plus fallback. [ML Kit Prompt API](https://developers.google.com/ml-kit/genai/prompt/android).
- **Godot on Android:** native APIs are reached through a **Godot Android plugin** (Kotlin/Java, v2 plugin
  architecture) exposing methods and signals to GDScript. The Nano bridge is one such plugin.
- **Chrome's Prompt API** (Gemini Nano) is available to regular web pages on **desktop** Chrome, reached from Godot
  through `JavaScriptBridge`. Requirements: Windows 10/11, macOS 13+, Linux, or Chromebook Plus; 22 GB free disk;
  a GPU with more than 4 GB VRAM, or 16 GB RAM and 4 cores. No mobile Chrome. The model (~3–4 GB) downloads on first
  use. The lead's dev laptop does **not** qualify (Intel UHD 620, 7.6 GB RAM).
  [Prompt API](https://developer.chrome.com/docs/ai/prompt-api).
