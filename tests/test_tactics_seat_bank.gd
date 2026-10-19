extends TestCase
## Round 34 (C34.11; planner's O5 probe, his bridge case on the Locks): a seat that falls in the canal is grounded on
## the bank its ANCHOR stands on, whichever bank the element is coming from. The probe: Green_Echo_3's goal (39.4, 12.2)
## became (39.4, -12.2), Echo_1 crossed the east bridge and back, the squad "arrived" and then shuffled 78.5 m.

const ANCHOR := Vector3(39.4, 0, 17.5)


func _grounded(lab: TacticsLab, probe: Node3D, asked: Vector3, from: Vector3) -> Vector3:
	var plan := {"anchor": ANCHOR, "slots": {"Green_P_1": asked}, "orders": {}}
	Element.ground(plan, probe, {"Green_P_1": 3.0}, from)
	return plan["slots"]["Green_P_1"]


func test_a_seat_in_the_canal_stands_on_its_anchors_bank() -> void:
	var lab := TacticsLab.create(self, 1, "locks")
	var probe := lab.unit(Match.Team.GREEN, "Green_P_1", Vector3(39.4, 0, 40.0), 0.0)
	await lab.start()
	for asked: Vector3 in [Vector3(39.4, 0, 4.0), Vector3(39.4, 0, -2.0), Vector3(39.4, 0, -6.0)]:
		for from: Vector3 in [Vector3(39.4, 0, 60.0), Vector3(39.4, 0, -60.0), Vector3(20.0, 0, 30.0)]:
			var at := _grounded(lab, probe, asked, from)
			print("SEAT_BANK asked %s from %s -> %s" % [asked, from, at])
			assert_true(at.z > 7.0, "a seat asked at %s (from %s) stands on the anchor's north bank, not %s" % [asked, from, at])


func test_a_transit_station_in_the_canal_stands_on_its_seats_bank() -> void:
	var lab := TacticsLab.create(self, 1, "locks")
	var probe := lab.unit(Match.Team.GREEN, "Green_P_1", Vector3(39.4, 0, 40.0), 0.0)
	await lab.start()
	var seat := Vector3(39.4, 0, 17.5)  # its final seat, on the anchor's north bank
	for asked: Vector3 in [Vector3(39.4, 0, 4.0), Vector3(39.4, 0, -2.0), Vector3(39.4, 0, -5.0)]:
		var stations := {"Green_P_1": asked}
		Element.ground_stations(stations, probe, {"Green_P_1": 3.0}, {"Green_P_1": seat})
		print("STATION_BANK asked %s -> %s" % [asked, stations["Green_P_1"]])
		assert_true((stations["Green_P_1"] as Vector3).z > 7.0, "a station in the canal at %s stands on its seat's bank (%s)" % [asked, stations["Green_P_1"]])
		var plain := {"Green_P_1": asked}
		Element.ground_stations(plain, probe, {"Green_P_1": 3.0})
		if asked.z < 0.0:
			assert_true((plain["Green_P_1"] as Vector3).z < -7.0, "setup: without its seat, the nearest bank is the far one (%s)" % plain["Green_P_1"])


func test_a_dry_station_on_the_near_bank_is_kept_while_its_squad_really_crosses() -> void:
	var lab := TacticsLab.create(self, 1, "locks")
	await lab.start()
	var near := Vector3(39.4, 0, 30.0)
	var far_seat := Vector3(39.4, 0, -30.0)
	assert_eq(SlotGround.station_on_goal_side(near, far_seat), near, "a dry station stands: the route takes it over the bridge")
	assert_eq(SlotGround.station_on_goal_side(Vector3(39.4, 0, 2.0), null), Vector3(39.4, 0, 2.0), "no seat: unchanged")
