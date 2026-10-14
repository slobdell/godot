extends TestCase
## Round 29 (traffic I1, builder0 throughput): `make test` balances its shards by each file's measured time
## (tests/run_tests.gd shard_owners over tests/shard_times.txt). The plan must be deterministic (every shard computes
## it alone), put every file in exactly one shard, and with no times be round 9's round-robin exactly.

const RUNNER := preload("res://tests/run_tests.gd")


func _files(count: int) -> PackedStringArray:
	var files := PackedStringArray()
	for i in count:
		files.append("res://tests/test_%03d.gd" % i)
	return files


func test_no_times_is_the_round_robin() -> void:
	var files := _files(11)
	var owner: PackedInt32Array = RUNNER.shard_owners(files, 4, {})
	for i in files.size():
		assert_eq(owner[i], i % 4, "file %d keeps round 9's shard" % i)


func test_every_file_in_exactly_one_shard_at_every_count() -> void:
	var files := _files(40)
	var times := {}
	for i in 30:  # ten files have no time yet
		times[files[i]] = 1000 + (i * 7919) % 50000
	for shards in [1, 2, 4, 5, 6]:
		var owner: PackedInt32Array = RUNNER.shard_owners(files, shards, times)
		for i in files.size():
			assert_true(owner[i] >= 0 and owner[i] < shards, "%d shards: file %d has a shard (%d)" % [shards, i, owner[i]])


func test_longest_first_balances_the_shards() -> void:
	# One 60 s file and twelve 5 s files on 4 shards: round-robin puts the 60 s file with three 5 s files (75 s); by
	# time it sits alone and the twelve share the other three shards (20 s each), a 60 s wall.
	var files := _files(13)
	var times := {files[0]: 60000}
	for i in range(1, 13):
		times[files[i]] = 5000
	var owner: PackedInt32Array = RUNNER.shard_owners(files, 4, times)
	var load_ms := [0, 0, 0, 0]
	for i in files.size():
		load_ms[owner[i]] += int(times[files[i]])
	assert_eq(load_ms.max(), 60000, "the longest shard is the one long file: %s" % [load_ms])
	var rr := [0, 0, 0, 0]
	for i in files.size():
		rr[i % 4] += int(times[files[i]])
	assert_eq(rr.max(), 75000, "round-robin's longest shard, for comparison: %s" % [rr])


func test_the_plan_is_deterministic() -> void:
	var files := _files(25)
	var times := {}
	for i in files.size():
		times[files[i]] = 3000 if i % 3 == 0 else 3000  # all ties: the order must still be fixed
	var first: PackedInt32Array = RUNNER.shard_owners(files, 5, times)
	var second: PackedInt32Array = RUNNER.shard_owners(files, 5, times.duplicate())
	assert_eq(first, second, "same files and times, same plan")
