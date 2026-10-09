extends TestCase
## Round 24 (brains R1, his bridge on the Locks): the ground a vehicle cannot cross, as SlotGround answers it from the
## arena's own terrain. The Locks: a canal 14 m deep across the whole map (z -7..7), the lock at x = 0 and the two
## swing bridges at x = +-92 (decks 24 m long, so z -12..12).

var _locks: Dictionary = Arena.load_layout("locks")["layout"]


func test_the_canal_is_wet_and_the_decks_over_it_are_not() -> void:
	assert_true(SlotGround.wet(Vector3(-50.0, 0.0, 0.0), _locks), "the middle of the canal is water")
	assert_true(SlotGround.wet(Vector3(-50.0, 0.0, 6.5), _locks), "just inside the north edge is water")
	assert_true(not SlotGround.wet(Vector3(-50.0, 0.0, 7.5), _locks), "the north quay is dry")
	assert_true(not SlotGround.wet(Vector3(0.0, 0.0, 0.0), _locks), "the lock's deck is dry")
	assert_true(not SlotGround.wet(Vector3(-92.0, 0.0, 3.0), _locks), "the west swing bridge's deck is dry")
	assert_true(not SlotGround.wet(Vector3(-50.0, 0.0, 0.0), Arena.load_layout("locks_dry")["layout"]),
			"the dry Locks has no water at all")


func test_a_leg_across_the_canal_is_wet_and_one_along_a_bank_or_over_a_bridge_is_not() -> void:
	assert_true(SlotGround.leg_wet(Vector3(-50.0, 0.0, 12.0), Vector3(-50.0, 0.0, -12.0), _locks), "straight across")
	assert_true(not SlotGround.leg_wet(Vector3(-80.0, 0.0, 12.0), Vector3(-20.0, 0.0, 12.0), _locks), "along the quay")
	assert_true(not SlotGround.leg_wet(Vector3(0.0, 0.0, 14.0), Vector3(0.0, 0.0, -14.0), _locks), "over the lock")


func test_a_combat_hop_over_the_water_stops_short_of_it() -> void:
	# His crews' hops: (-58, 12) toward (-48.8, -10). The leg meets water at z = 7; a 5.65 m margin (a tank's half
	# length plus two) leaves the hop ending about 5.6 m before the water along the leg.
	var from := Vector3(-58.0, 0.0, 12.2)
	var to := Vector3(-48.8, 0.0, -10.0)
	var end := SlotGround.dry_leg_end(from, to, 5.65, _locks)
	assert_true(not SlotGround.leg_wet(from, end, _locks), "the cut hop is dry: %s" % end)
	assert_true(from.distance_to(end) < 1.0, "a hop from 5 m off the water has almost nothing left: %s" % end)
	var far := Vector3(-58.0, 0.0, 30.0)
	var cut := SlotGround.dry_leg_end(far, to, 5.65, _locks)
	assert_true(cut.z > 7.0 + 5.0, "from further back the hop keeps its dry part, ending short of the water: %s" % cut)
	assert_true(not SlotGround.leg_wet(far, cut, _locks), "and that part is dry")
	var dry_hop := Vector3(-40.0, 0.0, 20.0)
	assert_eq(SlotGround.dry_leg_end(far, dry_hop, 5.65, _locks), dry_hop, "a dry hop is left alone")


func test_a_slot_stands_on_its_anchors_side_of_the_water() -> void:
	var anchor := Vector3(-59.5, 0.0, -9.3)  # his squad's anchor, just past the canal on the far quay
	# A wedge's rear seat laid on the near quay (dry, but across the water from its anchor): moved to the far quay.
	var behind := SlotGround.on_anchor_side(Vector3(-79.0, 0.0, 12.0), anchor, _locks)
	assert_true(behind.z < -7.0, "a seat on the near quay goes to the anchor's quay: %s" % behind)
	# A seat in the canal: the same.
	var wet_seat := SlotGround.on_anchor_side(Vector3(-70.0, 0.0, 2.0), anchor, _locks)
	assert_true(wet_seat.z < -7.0 and not SlotGround.wet(wet_seat, _locks), "a seat in the canal goes to the anchor's quay: %s" % wet_seat)
	# A seat on the anchor's own quay is not touched; nor is any seat when the anchor itself is in the water.
	var near := Vector3(-70.0, 0.0, -20.0)
	assert_eq(SlotGround.on_anchor_side(near, anchor, _locks), near, "a seat on the anchor's side stays")
	var clicked_in_water := Vector3(-50.0, 0.0, 0.0)
	assert_eq(SlotGround.on_anchor_side(Vector3(-50.0, 0.0, 12.0), clicked_in_water, _locks), Vector3(-50.0, 0.0, 12.0),
			"an anchor in the water keeps nothing")


func test_an_order_point_in_the_water_is_pulled_toward_where_it_is_reached_from() -> void:
	var toward := Vector3(-60.0, 0.0, 30.0)
	var pulled := SlotGround.pulled_dry(Vector3(-60.0, 0.0, -3.0), toward, _locks)
	assert_true(pulled.z > 7.0 and not SlotGround.wet(pulled, _locks), "onto the quay it is reached from: %s" % pulled)
	assert_eq(SlotGround.pulled_dry(Vector3(-60.0, 0.0, -20.0), toward, _locks), Vector3(-60.0, 0.0, -20.0),
			"a dry point (even across the water) is an order's to keep")


func test_the_control_arm_switches_the_grounding_off() -> void:
	SlotGround.WET_ENABLED = false
	var seat := Vector3(-79.0, 0.0, 12.0)
	assert_eq(SlotGround.on_anchor_side(seat, Vector3(-59.5, 0.0, -9.3), _locks), seat, "off: round 23's grounding")
	SlotGround.WET_ENABLED = true


func test_nobody_is_told_to_stand_on_a_bridge() -> void:
	var on_deck := Vector3(-89.6, 0.0, -4.3)  # the seat the series' seed 1 grounded onto the west swing bridge
	assert_true(not SlotGround.wet(on_deck, _locks) and SlotGround.over_water(on_deck, _locks), "a deck: dry, but over the water")
	var anchor := Vector3(-66.0, 0.0, -11.0)
	var seat := SlotGround.on_anchor_side(on_deck, anchor, _locks)
	assert_true(not SlotGround.over_water(seat, _locks) and seat.z < -7.0, "a seat on the deck goes to the anchor's quay: %s" % seat)
	var order := SlotGround.pulled_dry(on_deck, anchor, _locks)
	assert_true(not SlotGround.over_water(order, _locks) and order.z < -7.0, "and so does an order's goal: %s" % order)
	assert_eq(SlotGround.on_anchor_side(Vector3(-60.0, 0.0, 20.0), on_deck, _locks), Vector3(-60.0, 0.0, 20.0),
			"an anchor he put on the bridge moves nothing")
	assert_true(not SlotGround.leg_wet(Vector3(-92.0, 0.0, 14.0), Vector3(-92.0, 0.0, -14.0), _locks),
			"and a route over the deck is still dry")
	# The deck's far end, past the water (the series' second parked crew): still the bridge's mouth.
	var mouth := SlotGround.on_anchor_side(Vector3(-89.6, 0.0, -7.6), anchor, _locks)
	assert_true(not SlotGround.over_water(mouth, _locks) and mouth.x > -85.0, "a seat in the bridge's mouth goes onto the quay: %s" % mouth)
