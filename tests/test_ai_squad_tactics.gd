extends TestCase
## SquadTactics.plan(): the squad blackboard on hand-built members and contacts (game/ai/squad_tactics.gd). Pure.


func _member(member_name: String, position: Vector3, overrides: Dictionary = {}) -> Dictionary:
	var member := {"name": member_name, "position": position, "forward": Vector3.FORWARD, "weapon": Weapons.profile("cannon"),
			"role": "tank", "toughness": 1.0, "option": "ENGAGE"}
	member.merge(overrides, true)
	return member


func _enemy(enemy_name: String, position: Vector3, overrides: Dictionary = {}) -> Dictionary:
	var enemy := {"name": enemy_name, "position": position, "velocity": Vector3.ZERO, "forward": Vector3.BACK,
			"turret_forward": Vector3.BACK, "health": 300, "shield": 150, "visible": true}
	enemy.merge(overrides, true)
	return enemy


func _open() -> CoverMap:
	return CoverMap.from_features([])


func _squad() -> Array:
	return [_member("A", Vector3(-10, 0, 40)), _member("B", Vector3(0, 0, 40)), _member("C", Vector3(10, 0, 40))]


func test_the_squad_focuses_the_weakest_target_everyone_can_shoot() -> void:
	var contacts := [_enemy("Healthy", Vector3(-8, 0, 0)), _enemy("Wounded", Vector3(8, 0, 0), {"health": 90, "shield": 0})]
	assert_eq(SquadTactics.plan(_squad(), contacts, [], _open())["focus"], "Wounded", "pile onto the enemy that dies first")


func test_no_focus_when_only_one_member_can_shoot() -> void:
	var contacts := [_enemy("Far", Vector3(0, 0, -60))]
	var squad := [_member("A", Vector3(0, 0, 5)), _member("B", Vector3(80, 0, 90)), _member("C", Vector3(-80, 0, 90))]
	assert_eq(SquadTactics.plan(squad, contacts, [], _open())["focus"], "", "one gun in reach: no squad focus")


func test_a_focus_behind_a_wall_from_most_of_the_squad_is_not_chosen() -> void:
	var wall := CoverMap.from_features([{"position": Vector2(-8, 20), "size": [20.0, 1.5]}])
	var contacts := [_enemy("Hidden", Vector3(-8, 0, 0), {"health": 60, "shield": 0}), _enemy("Open", Vector3(30, 0, 0))]
	var squad := [_member("A", Vector3(-10, 0, 40)), _member("B", Vector3(-6, 0, 40)), _member("C", Vector3(-2, 0, 40)),
			_member("D", Vector3(34, 0, 40))]
	assert_eq(SquadTactics.plan(squad, contacts, [], wall)["focus"], "Open", "the weak enemy only one of us can see isn't the focus")


func test_the_focus_is_sticky() -> void:
	var contacts := [_enemy("First", Vector3(-8, 0, 0), {"health": 280}), _enemy("Second", Vector3(8, 0, 0), {"health": 260})]
	assert_eq(SquadTactics.plan(_squad(), contacts, [], _open())["focus"], "Second", "fresh: the slightly weaker one")
	assert_eq(SquadTactics.plan(_squad(), contacts, [], _open(), {"focus": "First"})["focus"], "First",
			"already shooting the first: don't switch for a small difference")


func test_one_member_flanks_a_stationary_focus() -> void:
	var contacts := [_enemy("Dug_In", Vector3(0, 0, 0))]
	var squad := [_member("A", Vector3(-30, 0, 30)), _member("B", Vector3(0, 0, 45)), _member("C", Vector3(5, 0, 45))]
	var result := SquadTactics.plan(squad, contacts, [], _open())
	assert_eq(result["focus"], "Dug_In", "setup: it is the focus")
	assert_eq(result["flanker"], "A", "the member already out to the side takes the flank")
	var moving := [_enemy("Dug_In", Vector3(0, 0, 0), {"velocity": Vector3(8, 0, 0)})]
	assert_eq(SquadTactics.plan(squad, moving, [], _open())["flanker"], "", "no flanking a moving target")
	assert_eq(SquadTactics.plan(squad.slice(0, 2), contacts, [], _open())["flanker"], "", "two members: both keep firing")


func test_a_healthy_member_covers_a_retreating_one() -> void:
	var shooter := _enemy("Shooter", Vector3(-10, 0, 0), {"turret_forward": (Vector3(-10, 0, 40) - Vector3(-10, 0, 0)).normalized()})
	var bystander := _enemy("Bystander", Vector3(12, 0, 0), {"turret_forward": Vector3.RIGHT})
	var squad := [_member("A", Vector3(-10, 0, 40), {"option": "RETREAT", "toughness": 0.2}), _member("B", Vector3(0, 0, 40)),
			_member("C", Vector3(40, 0, 40))]
	var result := SquadTactics.plan(squad, [shooter, bystander], [], _open())
	assert_eq(result["cover_for"], {"B": "Shooter"}, "the nearest healthy squad-mate targets whoever is shooting the retreater")


func test_enemies_near_our_artillery_are_flagged() -> void:
	var contacts := [_enemy("Raider", Vector3(0, 0, 90)), _enemy("Far", Vector3(0, 0, -20))]
	var result := SquadTactics.plan(_squad(), contacts, [Vector3(0, 0, 110)], _open())
	assert_eq(result["fragile_threats"], ["Raider"], "a raider 20 m from our battery is a priority")
