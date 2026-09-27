extends SceneTree
## Round 12, squad S1/S5: what the doctrine's terrain classifier (`ElementSituation.terrain_at`, cover features within
## 45 m) says at each map's spawns and along the squad's first 80 m move -- the input that decides whether a plain move
## under AUTO forms a column (`dense`) or a wedge (`lanes`, `open`). The brief assumed both maps he plays classify as
## dense; this is the measurement. No physics, no nav: the layout's obstacles only.
##
##   make tactics-terrain  ->  TERRAIN {"arena", "team", "slot", "at": [x, z], "forward": [...classes every 10 m...],
##                                      "side": [...], "pick_forward": {faction: shape}, "pick_side": ...}


func _initialize() -> void:
	DoctrineTable.clear_cache()
	# A squad fights by its units' FACTION table (Elements._table_for); `standard` is only the fallback for no faction.
	var tables := {}
	for faction: String in ["standard", "condemned", "law", "syndicate", "gangs"]:
		tables[faction] = DoctrineTable.load_table(faction).get("table")
	for arena_name: String in Arena.ROTATION:
		var loaded := Arena.load_layout(arena_name)
		if loaded.has("error"):
			print("TERRAIN_ERROR %s %s" % [arena_name, loaded["error"]])
			continue
		Arena.active = loaded["layout"]
		ElementSituation.forget_terrain()
		for team in [Match.Team.GREEN, Match.Team.RUST]:
			for slot in 3:
				var home := Match.spawn_position(team, slot)
				var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
				var right := Vector3(-toward.z, 0.0, toward.x)
				var row := {"arena": arena_name, "team": team, "slot": slot, "at": [snappedf(home.x, 0.1), snappedf(home.z, 0.1)]}
				for leg: Array in [["forward", toward], ["side", right]]:
					var classes: Array = []
					for step in 9:
						classes.append(ElementSituation.terrain_at(home + (leg[1] as Vector3) * 10.0 * step))
					row[leg[0]] = classes
					# What AUTO picks for a heavy squad with nothing known, at the ORDER (the classifier at the start), per table.
					var picks := {}
					for faction: String in tables:
						picks[faction] = String((tables[faction] as DoctrineTable).select({"task": "move", "threat": "none",
								"terrain": String(classes[0]), "composition": "heavy"})["formation"])
					row["pick_%s" % leg[0]] = picks
				print("TERRAIN " + JSON.stringify(row))
	quit(0)
