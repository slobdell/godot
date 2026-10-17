extends "res://tests/nav/terminus_drive.gd"
## Round 32 (manoeuvre H1b, C32.2): the Terminus drive exactly as `make nav-terminus-drive` runs it, plus one line at
## the end with H1b's counters (`H1B_DRIVE <json>`: ManoeuvreCensus.h1b_report() and the escape's arms). Nothing it adds
## touches the sim. `make manoeuvre-h1b-drive` runs it in two arms.
##
## C32.10's guard line (6) also reads the elements' re-seats: `H1B_SEATS {reseats, make_room_swaps}` summed over every
## element the match formed (sampled each physics frame, so a disbanded element keeps its last count).

var _seat_counts := {}


func _initialize() -> void:
	physics_frame.connect(_sample_seats)
	super()


func _sample_seats() -> void:
	var elements := Elements.of_match(game_match)
	if elements == null:
		return
	for element: Element in elements.all():
		_seat_counts[element.id] = [element.reseats, element.swaps]


func _report() -> void:
	print("H1B_DRIVE %s" % JSON.stringify({"seed": int(_flag("seed", "1")), "squad": squad_kind, "h1b_on": Movement.h1b_on(),
			"h1b": ManoeuvreCensus.h1b_report(), "escape": Movement.escape_arms()}))
	ManoeuvreCensus.print_new_far_rows()  # the ones MANOEUVRE_TURNS has not printed already
	var reseats := 0
	var swaps := 0
	for counts: Array in _seat_counts.values():
		reseats += int(counts[0])
		swaps += int(counts[1])
	print("H1B_SEATS %s" % JSON.stringify({"seed": int(_flag("seed", "1")), "squad": squad_kind, "elements": _seat_counts.size(),
			"reseats": reseats, "make_room_swaps": swaps}))
	super()
