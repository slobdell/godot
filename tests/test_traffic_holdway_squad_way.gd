extends TestCase
## Round 46 (manoeuvre M3, A6 v5): under `holdway` a crew's ordered way is its SQUAD's route direction where the crew stands
## (Movement.route_way over Element.transit's route), not the crew's next station. Bar A6 v4 (R45.20) read the station: at an order's
## first ticks a crew driving to a seat beside it "went" across the street, which flipped near-tie verdicts and tilted the waiting
## squad's spot line into the passer's path (11460, 11466).


func test_the_way_is_the_nearest_segment_of_the_route() -> void:
	# A route south down a street, then east at its end.
	var route: Array = [Vector3(0, 0, 0), Vector3(0, 0, 50), Vector3(40, 0, 50)]
	var down := Movement.route_way(route, Vector3(6.0, 0.0, 20.0))  # 6 m beside the street, as a crew dealt a seat to its west
	assert_near(down.x, 0.0, 0.001, "beside the first leg: the squad goes south (x)")
	assert_near(down.y, 1.0, 0.001, "beside the first leg: the squad goes south (z)")
	var east := Movement.route_way(route, Vector3(30.0, 0.0, 47.0))
	assert_near(east.x, 1.0, 0.001, "near the second leg: east")


func test_a_crew_behind_the_route_start_reads_the_first_leg() -> void:
	var route: Array = [Vector3(0, 0, 0), Vector3(0, 0, 50)]
	var way := Movement.route_way(route, Vector3(-3.0, 0.0, -20.0))
	assert_near(way.y, 1.0, 0.001, "a crew 20 m behind the start still reads the squad's way")


func test_no_route_is_no_way() -> void:
	assert_eq(Movement.route_way([], Vector3.ZERO), Vector2.ZERO, "no route")
	assert_eq(Movement.route_way([Vector3(1, 0, 1), Vector3(1, 0, 1)], Vector3.ZERO), Vector2.ZERO, "a route with no length")


func test_on_by_default_off_on_the_web() -> void:
	assert_true(not Traffic.DEFAULT_OFF.has("holdway"), "round 46 (R46.27): holdway is not listed OFF by default")
	assert_true(Traffic.WEB_OFF.has("holdway"), "round 46 (R46.35): ...but OFF in the web export (a round-47 freeze)")
	if not OS.has_feature("web") and not OS.get_cmdline_user_args().has("--traffic-off=holdway"):
		assert_true(not Traffic.off("holdway"), "the native / desktop game runs it ON; --traffic-off=holdway the escape")
