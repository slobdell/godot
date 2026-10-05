extends TestCase
## tests/support/watch.gd: a watcher connected through Watch.on is gone when the runner releases it (ship, round 18).


class Emitter extends RefCounted:
	signal pinged(n: int)


func test_a_watcher_hears_until_released_and_not_after() -> void:
	var emitter := Emitter.new()
	var heard: Array[int] = []
	Watch.on(emitter.pinged, func(n: int) -> void: heard.append(n))
	emitter.pinged.emit(1)
	assert_eq(heard, [1] as Array[int], "connected: it hears")
	assert_eq(Watch.release_all(), 1, "release_all disconnects the one watcher")
	emitter.pinged.emit(2)
	assert_eq(heard, [1] as Array[int], "released: it hears nothing more")
	assert_eq(emitter.pinged.get_connections().size(), 0, "and the emitter holds no connection")


func test_a_watcher_whose_emitter_is_gone_is_skipped() -> void:
	var node := Node.new()
	Watch.on(node.renamed, func() -> void: pass)
	node.free()
	assert_eq(Watch.release_all(), 0, "a freed emitter's watcher is dropped, not an error")
