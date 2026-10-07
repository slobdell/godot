class_name Credits
extends RefCounted
## Round 19 (garage, G1; contract C19.2): the per-game money the lead named. *"each player is given 1000 credits per
## game ... Each vehicle has a cost"* (2026-10-05). Credits are what the player READS: every price on a card, the
## meter, the results. Underneath, the simulation keeps its points (`Units.PROFILES[*].cost`, balance, his: C12.6).
##
## Round 20 (garage, R1; contract C20.1): the scale is anchored on the Road Gangs' scout. The lead: *"for now we will
## assume that an all scout army for the road gangs is 25 vehicles, and all costs and counts can be based on that"*
## (2026-10-06). The Gangs' scout is 70 points and 25 of them are 1000 credits, so ONE CREDIT = 1.75 POINTS (7/4) for
## every faction: the Gangs' scout 40 CR, the Condemned's 63, the Law's 80, the Syndicate's 120; an all-scout army at
## 1000 is 25 / 15 / 12 / 8 vehicles, each faction's identity by count as in skirmish. 1000 credits = 1,750 points.
##
## Rounding: a price is its points x 4/7 ROUNDED UP to the credit. Up, because a shown price must never undercharge:
## an army whose credits fit 1000 then always fits the fight's 1,750 points (rounding to nearest put the Syndicate's
## 300-point IFV at 171, and six of them plus change bought more than 1,750 points). There are no ties to break: every
## price is a multiple of 5 points, and 5 x 4/7 is never a whole half. Exact for the scales' anchors (70, 175, 140,
## 210 points: 40, 100, 80, 120 CR). Points still decide every fight; nothing the simulation reads changes.
##
## His later layer (*"as players advance they get more credits or something"*) is a different GAME_CREDITS per
## player, read from the profile; nothing is built for it (game_design.md *Progression*).

## One credit is POINTS_PER_CREDIT_NUM / POINTS_PER_CREDIT_DEN points (7/4 = 1.75), integers so nothing drifts.
const POINTS_PER_CREDIT_NUM := 7
const POINTS_PER_CREDIT_DEN := 4
## One credit in points, for reading and printing (the arithmetic uses the fraction above).
const POINTS_PER_CREDIT := 1.75
## The anchor: the vehicle whose price the scale is built on, and how many of it the game's money buys.
const ANCHOR_UNIT := "gang_scout"
## The anchor's price in credits (its 70 points x 4/7; tests pin it to of_unit, which a constant cannot call).
const ANCHOR_PRICE := 40
## Round 22 (army, C22.1; the lead: *"yeah double it sounds good"*): a full army of the anchor is his army's cap, so the
## money follows the cap: ten squads of five, 50 Gangs scouts, 2000 credits (C22.3: 8 squads -> 1600, 6 -> 1200).
const ANCHOR_COUNT := ArmyCatalog.MAX_UNITS
## Each side's money for one game, in credits (both sides: his fairness guard, "a shared budget tier"). 2000.
const GAME_CREDITS := ANCHOR_COUNT * ANCHOR_PRICE
## How the player's money is written: "40 CR".
const SUFFIX := "CR"


## A game's budget in points (what the skirmish's loader checks the garage's armies against): 3,500 since round 22.
static func game_points() -> int:
	return to_points(GAME_CREDITS)


## Points as credits, rounded UP to the credit (a shown price never undercharges; see the header).
static func of_points(points: int) -> int:
	return ceili(float(points * POINTS_PER_CREDIT_DEN) / float(POINTS_PER_CREDIT_NUM))


## Credits as points, rounded DOWN (the points an amount of money is sure to cover): 2000 CR = 3,500.
static func to_points(credits: int) -> int:
	return floori(float(credits * POINTS_PER_CREDIT_NUM) / float(POINTS_PER_CREDIT_DEN))


## What a unit costs the player, in credits.
static func of_unit(unit_id: String) -> int:
	return of_points(Units.cost_of({"unit": unit_id}))


## "40 CR"
static func text(credits: int) -> String:
	return "%d %s" % [credits, SUFFIX]
