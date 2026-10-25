extends TestCase
## Round 40 (settle, R40.14; `--cap-deal=street`; the dry deal read, builder2 main 9d5907ddd + trace, terminus 5 route
## s8206: Delta's cap deploy sent Delta_2 36 m and Delta_4 29 m). Pure: ElementPlan._cap_deal on a squad strung along a line
## where it stopped. No arena here (no street reads): the halt stays on the ordered heading and is dealt least-total, so the
## deploy carries the deal (`keep`) and its worst drive is no longer than the travel-index seating's.

var _cap := ElementPlan.CAP_DEAL


func teardown() -> void:
	ElementPlan.CAP_DEAL = _cap
	super.teardown()


static func _member(n: String, at: Vector3) -> Dictionary:
	return {"name": n, "unit": "tank", "role": "tank", "position": at}


func test_a_cap_deploy_carries_the_least_total_deal() -> void:
	var members: Array = []
	for i in 4:
		members.append(_member("Green_D_%d" % (i + 1), Vector3(-15.0 + 10.0 * i, 0, 0)))
	var situation := {"members": members, "tick": 0}
	var deploy := {"heading": Vector3.FORWARD, "anchor": Vector3.ZERO, "cause": "cap"}
	ElementPlan._cap_deal(deploy, situation, Vector3.ZERO, "line", 10.0)
	var keep: Dictionary = deploy.get("keep", {})
	assert_eq(keep.size(), 4, "every crew dealt")
	var deal := ElementPlan._fit_deal(members, "line", Vector3.ZERO, Vector3.FORWARD, 10.0, situation)
	assert_eq(keep, deal["keep"], "the least-total deal")
	assert_true(not bool((deploy["cap_deal"] as Dictionary)["street"]), "no street here: the ordered heading")
	assert_true(float(deal["worst"]) <= 10.5, "strung 10 m apart on a 10 m line: short drives (%.1f)" % float(deal["worst"]))


func test_off_by_default() -> void:
	var asked: bool = Array(OS.get_cmdline_user_args()).has("--cap-deal=street") or OS.get_environment("CAP_DEAL") == "street"
	assert_true(asked or not ElementPlan.CAP_DEAL, "OFF until its bar passes")
