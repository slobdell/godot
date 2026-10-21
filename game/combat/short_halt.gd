class_name ShortHalt
extends RefCounted
## Round 37 (rules R2, ruling R37.2 (b)): WHO may make the short halt (Tank._short_halt). Not a crew under the player's
## plain MOVE: he told it to drive, and a crew that stops to shoot reads as disobeying ("units look smart and under my
## control"). Attack-move, hold, parked and every CPU crew may. Asked only at the moment a halt would start (rare), so
## the lookups below cost nothing per tick.

## Whether `tank` is the player's and under a plain move: his own order to it (Orders, game/control) has the verb "move", or
## its squad's task (Elements) is a plain move ({"verb": "move", "drills": false}: rts_controls' right-click; attack-move
## is the same verb with drills ON). A team the CPU commands (an ElementCommander_<team> under the match) has no player.
static func plain_player_move(tank: Tank) -> bool:
	var tanks_root := tank.get_parent()
	var game_match := tanks_root.get_parent() as Match if tanks_root != null else null
	if game_match == null or game_match.has_node("ElementCommander_%d" % tank.team):
		return false
	var unit := String(tank.name)
	var orders := Orders.of(game_match)
	var order: Dictionary = orders.current(unit) if orders != null else {}
	if String(order.get("verb", "")) == "move" and String(order.get("source", "")) != "element":
		return true  # his own order to this crew (a squad leader's orders say source "element": its task decides)
	var elements := Elements.of_match(game_match)
	var element: Element = elements.of(unit) if elements != null else null
	return element != null and String(element.task.get("verb", "")) == "move" and not bool(element.task.get("drills", true))
