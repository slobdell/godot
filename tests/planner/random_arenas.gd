extends SceneTree
## Round 34 (planner, R34.15): which map `--arena=random` deals for each seed (Arena.resolve_name: Godot's hash and RNG,
## not reproducible in Python), one line a seed: `RANDOM_ARENA <seed> <name>`. tools/judge/seed_twins.py reads the file
## this writes, so a series can drop a random-arena fight that is a byte-identical twin of a fixed-arena fight of the
## same seed (traffic: 14 of the 48 random seeds in 1200-1247 dealt the Locks or the Terminus).
##
##   godot --headless --path . --script res://tests/planner/random_arenas.gd -- --from=0 --to=3000 > random_arenas.txt


func _initialize() -> void:
	var from := 0
	var to := 3000
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--from="):
			from = int(String(arg).split("=")[1])
		elif String(arg).begins_with("--to="):
			to = int(String(arg).split("=")[1])
	print("# Arena.ROTATION %s" % str(Arena.ROTATION))
	for seed_value in range(from, to + 1):
		print("RANDOM_ARENA %d %s" % [seed_value, Arena.resolve_name("random", seed_value)])
	quit(0)
