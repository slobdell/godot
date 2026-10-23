extends TestCase
## Round 38 (settle, R38.19: S2 v4): THE LATCH HOLDS THE TERRAIN AT THE HALT'S ANCHOR (ElementPlan.DEPLOY_LATCH_ANCHOR).
## 1. S2 v3's context case (builder2 91a681712 and laptop 57feb5e17, locks 3 click s3906 squad 3, the deploy's own trace): three
##    scouts stood in on a lane's last metres, their centroid read lanes, and the halt's anchor (41.86, 19.15) was open. The
##    centroid latch deploys and holds a herringbone in the open (the counter); the anchor latch reads open and stands a coil.
## 2. R37.42's geometry (test_settle_deploy_latch's first test) must still stand in a herringbone.

const MAP := "locks"
const ANCHOR := Vector3(41.86, 0, 19.15)
const CREWS := {"Green_Charlie_1": [36.52, 19.79], "Green_Charlie_2": [35.73, 10.77], "Green_Charlie_3": [45.39, 18.77]}
const HEADING := Vector3(0.0482, 0, -0.9988)

var _latch := ElementPlan.DEPLOY_LATCH
var _anchor := ElementPlan.DEPLOY_LATCH_ANCHOR
var _terrain := ElementSituation.HALT_TERRAIN


func teardown() -> void:
	ElementPlan.DEPLOY_LATCH = _latch
	ElementPlan.DEPLOY_LATCH_ANCHOR = _anchor
	ElementSituation.HALT_TERRAIN = _terrain
	super.teardown()


## The traced squad at its all-in: {"deploy", "shape"} as the deploy step lays it.
func _deploy(anchor_latch: bool) -> Dictionary:
	ElementPlan.DEPLOY_LATCH = true
	ElementPlan.DEPLOY_LATCH_ANCHOR = anchor_latch
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("standard")["table"]
	var members: Array = []
	var issued := {}
	var center := Vector3.ZERO
	for n: String in CREWS:
		var at := Vector3(float(CREWS[n][0]), 0, float(CREWS[n][1]))
		members.append({"name": n, "unit": "scout", "role": "scout", "position": at})
		issued[n] = at
		center += at
	center /= float(members.size())
	var situation := {"tick": 480, "center": center, "heading": HEADING, "leader": "Green_Charlie_1", "members": members,
			"terrain": ElementSituation.terrain_at(center), "threat": "none", "composition": "light"}
	var state := {"task": {"verb": "move", "to": [ANCHOR.x, ANCHOR.z], "drills": false, "lay": [HEADING.x, HEADING.z]},
			"deploy": {}, "issued_slots": issued, "arrived_tick": 400}
	var deploy := ElementPlan._deploy_state({"arrived": true}, situation, state, ANCHOR, center, null, table)
	var latched := ElementPlan._deploy_latched(situation, {"deploy": deploy})
	return {"deploy": deploy, "shape": ElementPlan._deploy_shape(latched, state, table), "centre_read": situation["terrain"]}


func test_a_squad_standing_in_on_a_lanes_last_metres_holds_the_anchors_open() -> void:
	var lab := TacticsLab.create(self, 7, MAP)
	ElementSituation.forget_terrain()
	var centroid := _deploy(false)
	var anchored := _deploy(true)
	lab.dispose()
	print("MEASURE deploy latch at the anchor: centroid %s %s | anchor %s %s (ground at the anchor %s)" % [
			centroid["deploy"].get("terrain"), centroid["shape"], anchored["deploy"].get("terrain"), anchored["shape"],
			ElementSituation.terrain_at(anchored["deploy"]["anchor"])])
	assert_eq(String(centroid["centre_read"]), "lanes", "setup: the crews' centroid reads lanes")
	assert_true(bool(anchored["deploy"].get("deployed", false)), "setup: deployed at the all-in")
	assert_eq(String(centroid["deploy"]["terrain"]), "lanes", "counter: the centroid latch holds lanes")
	assert_eq(String(centroid["shape"]), "herringbone", "counter: a herringbone at an open anchor")
	assert_eq(String(anchored["deploy"]["terrain"]), "open", "the anchor latch holds the anchor's open")
	assert_eq(String(anchored["shape"]), "coil", "and stands a coil")


func test_r37_42s_lane_still_stands_in_a_herringbone() -> void:
	ElementSituation.HALT_TERRAIN = "centre"
	ElementPlan.DEPLOY_LATCH = true
	ElementPlan.DEPLOY_LATCH_ANCHOR = true
	var latched: Dictionary = await TacticsScenarios.task_posture(self, "move", 30.0)
	print("MEASURE deploy latch at the anchor, R37.42: %s" % latched)
	assert_eq(String(latched["formation"]), "herringbone", "herringbone in the lane")
	assert_true(int(latched["orders_last_10s"]) <= 2, "and quiet (%d orders in the last 10 s)" % latched["orders_last_10s"])
	assert_true(float(latched["worst_off_slot_m"]) <= 8.0, "every vehicle in its slot (%.1f m)" % latched["worst_off_slot_m"])
