extends SceneTree
## `make native-bench` (round 23, native): the price of ONE call across the GDScript/native seam, the floor every port
## pays per call and the number that sizes a seam (N0's finding: a sub-microsecond function loses to its own call).
## Prints NATIVE_BENCH lines: usec per call for the GDScript body, the seam as the game calls it, a direct dynamic
## call on the instance, Object.call(), a Callable, and an empty GDScript static call for scale. One process, one
## thread; pin it (taskset -c 0-3 on builder0) and say the commit and machine with the numbers.

const N := 300000


static func _nothing(_a: Vector3, _b: Vector3, _c: Vector3, _d: Vector3, _e: float) -> float:
	return 0.0


func _init() -> void:
	var here := Vector3(1.0, 0.0, 2.0)
	var velocity := Vector3(3.0, 0.0, -1.0)
	var round_position := Vector3(40.0, 1.0, 25.0)
	var round_velocity := Vector3(-60.0, 0.0, -40.0)
	var seconds := 0.1
	var sink := 0.0
	var rows: Array = []
	# The GDScript body (the switch off).
	BrainSwitches.native = false
	var t0 := Time.get_ticks_usec()
	for i in N:
		sink += IncomingFire.closest_approach(here, velocity, round_position, round_velocity, seconds)
	rows.append(["gdscript body via IncomingFire (switch off)", Time.get_ticks_usec() - t0])
	t0 = Time.get_ticks_usec()
	for i in N:
		sink += _nothing(here, velocity, round_position, round_velocity, seconds)
	rows.append(["empty gdscript static call (scale)", Time.get_ticks_usec() - t0])
	if NativeBridge.available:
		var impl: Object = NativeBridge.impl
		BrainSwitches.native = true
		t0 = Time.get_ticks_usec()
		for i in N:
			sink += IncomingFire.closest_approach(here, velocity, round_position, round_velocity, seconds)
		rows.append(["the seam as the game calls it (switch on)", Time.get_ticks_usec() - t0])
		t0 = Time.get_ticks_usec()
		for i in N:
			sink += impl.closest_approach(here, velocity, round_position, round_velocity, seconds)
		rows.append(["impl.closest_approach() dynamic", Time.get_ticks_usec() - t0])
		t0 = Time.get_ticks_usec()
		for i in N:
			sink += impl.call(&"closest_approach", here, velocity, round_position, round_velocity, seconds)
		rows.append(["impl.call(&name, ...)", Time.get_ticks_usec() - t0])
		var callable := Callable(impl, &"closest_approach")
		t0 = Time.get_ticks_usec()
		for i in N:
			sink += callable.call(here, velocity, round_position, round_velocity, seconds)
		rows.append(["Callable.call(...)", Time.get_ticks_usec() - t0])
		t0 = Time.get_ticks_usec()
		for i in N:
			sink += impl.build_info().length() * 0.0
		rows.append(["impl.build_info() (no args, a String back)", Time.get_ticks_usec() - t0])
		# Round 24 (N3c's design): moving a mover's state across the seam. 60 members of a Movement, read by C++
		# through Object::get (and written back through set), against GDScript packing the same 60 into a
		# PackedFloat64Array by index and unpacking it.
		var mover := Movement.new(null)
		var members := PackedStringArray()
		for prop: Dictionary in mover.get_property_list():
			var kind: int = prop["type"]
			if (kind == TYPE_FLOAT or kind == TYPE_INT or kind == TYPE_BOOL) and members.size() < 60 \
					and (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				members.append(prop["name"])
		var rounds := 5000
		t0 = Time.get_ticks_usec()
		sink += impl.bench_members(mover, members, rounds, false)
		rows.append(["C++ Object::get of %d members (per member)" % members.size(), (Time.get_ticks_usec() - t0) * N / (rounds * members.size())])
		t0 = Time.get_ticks_usec()
		sink += impl.bench_members(mover, members, rounds, true)
		rows.append(["C++ get + set of each member (per member)", (Time.get_ticks_usec() - t0) * N / (rounds * members.size())])
		var packed := PackedFloat64Array()
		packed.resize(members.size())
		t0 = Time.get_ticks_usec()
		for r in rounds:
			for i in members.size():
				packed[i] = float(mover.get(members[i]))
		rows.append(["GDScript mover.get(name) into a packed array (per member)", (Time.get_ticks_usec() - t0) * N / (rounds * members.size())])
		t0 = Time.get_ticks_usec()
		for r in rounds:
			packed[0] = mover._repath_left
			packed[1] = mover._remaining
			packed[2] = mover.stalled_ticks
			packed[3] = mover._path_index
			packed[4] = mover._kturn_left_m
			packed[5] = mover._order_ticks
			packed[6] = mover._arrive
			packed[7] = mover._ask_left
			packed[8] = mover._unstick_left
			packed[9] = mover._stuck_time
		rows.append(["GDScript packed[i] = mover.field, written out (per member)", (Time.get_ticks_usec() - t0) * N / (rounds * 10)])
	else:
		print("NATIVE_BENCH native absent: only the GDScript rows")
	for row: Array in rows:
		print("NATIVE_BENCH %-48s %7.3f usec/call (%d calls)" % [row[0], float(row[1]) / N, N])
	print("NATIVE_BENCH %s | sink %f" % [NativeBridge.describe(), sink])
	BrainSwitches.native = NativeBridge.available
	quit(0)
