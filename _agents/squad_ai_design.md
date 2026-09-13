# Squad AI and Player Skill: Design Exploration

> **Status: direction accepted by the project lead (2026-09-12); details still hypotheses**
> until experiments E1–E4 run. The lead will smoke test the game personally
> before squad AI (M5) begins. This captures the
> project lead's two open questions and a proposed way to answer them *with
> experiments* rather than guesses. Promote conclusions into
> [architecture.md](architecture.md) / [vision.md](vision.md) as they're validated.

The questions, in the lead's words:
1. *"Each tank maintains some weighted tree with tunable directives where it otherwise acts within its own control loop to navigate the course and attack enemies."* Is that a workable design?
2. *"A computer opponent would have identical capabilities, so we need this to be a game where there's some degree of skill… what's the difference between a good player and a bad player?"*

---

## Part 1: The weighted tree has a name, utility AI

Game AI has a few standard families. The lead's intuition lands squarely on the
last row of the core three:

| Family | Idea | Strength | Weakness |
|---|---|---|---|
| Finite state machine | States + transitions (`patrol → chase → attack`) | Simple | Explodes combinatorially; brittle |
| Behavior tree | A prioritized tree of conditions and actions, evaluated top-down | Readable, debuggable, industry standard | Priorities are hard-coded; tuning means restructuring the tree |
| **Utility AI** | Every possible action gets a **score** from weighted considerations; the tank does the highest-scoring one | **Weights are the tuning surface**, behavior emerges smoothly, easy to expose as sliders | Can dither between near-equal options; needs debug overlays to understand |
| GOAP / planners | Search for a sequence of actions reaching a goal | Clever multi-step plans | Heavy; overkill here |

**Proposal: directives over utility.** A small tree picks *which set of weights
is active* ("phases"), and utility scoring picks *what to do right now*. That is
literally a weighted tree with tunable directives.

### The per-tank control loop

```
 every physics tick (60 Hz)                      every "think" (~5 Hz, staggered per tank)
┌────────┐   ┌────────────┐   ┌───────────────────────────────┐   ┌──────────────────────┐
│ SENSE  │──▶│ BLACKBOARD │──▶│ THINK: score each candidate   │──▶│ ACT: current action  │──▶ TankCommand
│ LOS,   │   │ threats,   │   │ action × target with the      │   │ steers/aims/fires via│
│ hearing│   │ allies,    │   │ active directive weights;     │   │ navmesh + steering   │
│ damage │   │ last-known │   │ keep current unless beaten by │   └──────────────────────┘
└────────┘   └────────────┘   │ a margin (commitment)         │
                              └───────────────────────────────┘
```

It ends in a `TankCommand`, the same seam the keyboard and network use today.
An AI tank is just another controller ([architecture.md](architecture.md)).

### Layers (who tunes what)

| Layer | Contents | Tuned by |
|---|---|---|
| 5. Squad | Shared blackboard (spotted enemies, who's engaged, who needs help), role assignment | player (roles) |
| 4. **Phases** (the "tree") | Conditions that swap directive sets: *until enemy spotted → Scout; when HP < 40% → Fall back; after 2 allies lost → Regroup* | **player** |
| 3. **Directives** (the "weights") | aggression, preferred engagement range, retreat threshold, leash zone, target priority (closest / weakest / most dangerous / whoever attacks my ally), fire discipline, cover-seeking | **player** |
| 2. Actions | Shared vocabulary: `advance_to`, `engage`, `take_cover`, `retreat_to`, `hold`, `escort`, `scout_route` | game designers (us) |
| 1. Motor | Path following, obstacle avoidance, turret aiming, shot leading → `TankCommand` | game designers (us), identical for everyone |

A sketch of scoring:

```
score(engage, target) = aggression
                      × range_fit(distance, preferred_range)     # response curve, 0..1
                      × confidence(my_hp, target_hp, armor_facing)
                      × priority(target, target_priority_rule)
                      × visible(target)

score(take_cover)     = caution × threat_level × (1 − my_hp)^2 × cover_available
```

Known pitfalls, planned for up front:
- **Dithering** (flip-flopping between two near-equal actions): add a commitment bonus to the current action, plus a minimum commit time.
- **Knob explosion**: expose about 5–8 player-facing directives that each map onto several internal weights. If a knob doesn't change outcomes, delete it (see experiment E2).
- **Opacity**: players can't improve what they can't see. A debug overlay showing each tank's top 3 scored actions is a core feature for learning, not a debug nicety.

Why this suits the LLM plan: Gemini Nano only has to emit a small, schema-bound
JSON of phases and directive values, never code. The vocabulary is small enough
to validate and to generate reliably.

---

## Part 2: Where skill comes from when both sides are identical

Chess pieces are identical too. **Skill is the quality of decisions.** The
design job is to make sure decisions (a) *matter*, (b) have *no dominant
answer*, and (c) can be *learned* from feedback.

Five places decisions live in this game:

| # | Source of skill | What makes it real | Example |
|---|---|---|---|
| 1 | **Composition under a budget** | Non-transitive counters (rock-paper-scissors) between equipment | Heavy long-gun beats light flankers in open ground; flankers beat mortars; mortars beat dug-in heavies |
| 2 | **Doctrine quality** | Tanks' directives must work *together* and fit *this map* | A bait tank's retreat path leads into the ambusher's preferred range. Bad doctrine: bait retreats the wrong way |
| 3 | **Reading the opponent** | Hidden information (fog of war, unknown loadouts) + opponent AI that is **predictable in exploitable ways** | Their tanks target "closest", so a fast decoy pulls them out of cover. Scouting reveals their composition |
| 4 | **Live intervention with a limited command budget** | A dial between auto-battler (0 commands) and RTS (unlimited). E.g. one command point per 10 s: switch a tank's phase, mark focus fire, pop smoke, set a rally point | Spending the point to pull back the bait *just* before it dies. Real-time decision skill without twitch micro, and fair on phones |
| 5 | **Iteration between matches** | Replays + score overlay → players improve doctrine | Watching a loss, seeing the ambusher's "hold" score lose to "engage", lowering its aggression |

| A weak player… | A strong player… |
|---|---|
| Leaves default directives; every tank aggressive | Gives each tank a role that complements the others |
| Brings five identical "best" tanks | Builds a composition with counters and covers weaknesses |
| Never scouts; fights on the enemy's terms | Scouts, then commits where the enemy is weak |
| Spends commands randomly or not at all | Saves commands for decisive moments |
| Blames the AI after losing | Reads the replay overlay and fixes the doctrine |

**The computer opponent is just a doctrine + a command-spending policy.**
Difficulty comes from doctrine quality and command usage, **never** from stat
bonuses or seeing through fog. Later, opponents can be *other players' saved
doctrines* (an asynchronous ladder), which gives endless human-authored variety
without real-time matchmaking.

**Genre references worth playing (a good father–son homework assignment):**
Gladiabots (programmable robot squads with behavior trees, probably the
closest existing game), Final Fantasy XII's Gambit system (if/then rules for AI
party members), Frozen Synapse (simultaneous squad planning), auto-battlers
like Teamfight Tactics (composition and counters), and Screeps / Robocode
(AI written as code). Note what makes each feel skillful or random.

---

## Part 3: Validate with experiments before committing

Every experiment runs **headless and faster than real time**, which is the
real reason to build the match runner early (see roadmap). Results go in a
table at the bottom of this doc.

| # | Question | Setup | Pass if | Needs |
|---|---|---|---|---|
| **E1** | Does one utility-AI tank look smart? | 1 AI tank vs 3 scripted dummies; score overlay; watch replays | Takes cover when hurt, fights at preferred range, doesn't dither (fewer than ~1 action switch/s) | M3 combat, navmesh, LOS |
| **E2** | Does each directive matter? | Mirror match, vary ONE knob (e.g. preferred range 10→60 m), 200 matches per value, random spawns | Win-rate curve isn't flat. **A flat curve means the knob is dead weight: delete it** | match runner |
| **E3** | Does skill exist at all? | 4 hand-written doctrines (rush, turtle, bait-and-ambush, flank) + 1 random-weights doctrine; round robin, 200 matches per pairing | (a) authored beat random ≥ 75%; (b) **no doctrine beats all others** (non-transitive); (c) repeated runs agree within ±5% | match runner, doctrine format |
| **E4** | Does live commanding add skill? | Same doctrine, with k = 0, 1, 3 command points per minute, used by a simple heuristic policy | Win rate rises with k, with diminishing returns | command system |

If E3 fails (b), the equipment/directive trade-offs need rebalancing before any
LLM or Android work. That's the cheapest possible place to find out.

## Consequences for the roadmap

- **M3 (combat) must include what AI considerations will read:** line of sight, armor facing (front/side/rear), and cover, not just hit points. Playing M3 by hand is how we learn which considerations matter.
- **Pull a headless match runner forward** (it was in M5): experiments E2–E4 depend on it, and it doubles as a load and balance tool.
- M4's acceptance becomes E1; M5's becomes E3.

## Results log

| Date | Experiment | Result | Decision |
|---|---|---|---|
| 2026-09-12 | Informal: Claude (commander via agent bridge) vs 1 BotController, 1v1 | Bot 4 : 2 Claude. Slow commanders die between decisions; chargers always show front armor; first shot wins even duels; straight-line bots deadlock on walls | Keep phases/conditional orders (layer 4) in the design; navmesh + perception memory are M4 requirements; judge positional skill in squads, not 1v1. Details: [agent_bridge.md](agent_bridge.md) play report #1 |
