class_name Credits
extends RefCounted
## Round 19 (garage, G1; contract C19.2): the per-game money the lead named. *"each player is given 1000 credits per
## game ... Each vehicle has a cost"* (2026-10-05). Credits are what the player READS: every price on a card, the
## meter, the results. Underneath, the simulation keeps its points (`Units.PROFILES[*].cost`, balance, his: C12.6).
##
## WHY a presentation and not a rescale (measured at 567e1997, laptop, tools: the brief's G1 table in Status): a real
## rescale of every price by 1000/5200 (so 1000 credits buys today's 5,200-point skirmish army) rounds 21 prices, and
## `Army.cpu_army`'s buy-down then builds a DIFFERENT army in 182 of 1,250 archetype x budget x start cases (18 at the
## baseline's 5,200) -- every baseline line would move. Every price is a multiple of 5 points, so ONE CREDIT = FIVE
## POINTS is exact: each card's price, the sum of a squad's, and the meter all agree to the credit, and nothing the
## simulation reads changes. 1000 credits = 5,000 points: the army a faction skirmish fields today (5,200), less ~4 %.
##
## His later layer (*"as players advance they get more credits or something"*) is a different GAME_CREDITS per
## player, read from the profile; nothing is built for it (game_design.md *Progression*).

## One credit, in the simulation's points.
const POINTS_PER_CREDIT := 5
## Each side's money for one game, in credits (both sides: his fairness guard, "a shared budget tier").
const GAME_CREDITS := 1000
## How the player's money is written: "40 CR".
const SUFFIX := "CR"


## A game's budget in points (what the skirmish, the CPU buyer and the loader check against): 5,000.
static func game_points() -> int:
	return GAME_CREDITS * POINTS_PER_CREDIT


## Points as credits. Exact for every price in the game (a test holds that every `Units` cost is a multiple of
## POINTS_PER_CREDIT); anything else rounds down, so a shown price never undercharges.
static func of_points(points: int) -> int:
	return floori(float(points) / float(POINTS_PER_CREDIT))


static func to_points(credits: int) -> int:
	return credits * POINTS_PER_CREDIT


## What a unit costs the player, in credits.
static func of_unit(unit_id: String) -> int:
	return of_points(Units.cost_of({"unit": unit_id}))


## "40 CR"
static func text(credits: int) -> String:
	return "%d %s" % [credits, SUFFIX]
