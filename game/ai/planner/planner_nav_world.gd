class_name PlannerNavWorld
extends PlannerWorld
## Round 30 (planner P3): the world as the GAME knows it: walls from the navigation mesh (bake radius minus the
## distance off the mesh, `Movement._outline_offs`' arithmetic, cached on the lazy grid), other hulls from the match's
## tanks. A point on the mesh reads the bake radius (2.0 m): the mesh promises at least that to every face.

var map := RID()
var bake_radius := 2.0


static func for_tank(me: Tank, tanks_root: Node) -> PlannerNavWorld:
	var w := PlannerNavWorld.new()
	w.map = me.get_world_3d().navigation_map
	w.bake_radius = Movement.bake_radius(me)
	w.refresh_hulls(me, tanks_root)
	return w


func refresh_hulls(me: Tank, tanks_root: Node) -> void:
	hulls.clear()
	if tanks_root == null:
		return
	for node: Node in tanks_root.get_children():
		var other := node as Tank
		if other == null or other == me or not other.is_alive():
			continue
		var box: Array = Movement.hull_box(other.unit_id)
		var f := -other.global_basis.z
		add_hull(other.global_position.x, other.global_position.z, f.x, f.z, float(box[0]) * 0.5, float(box[2]) * 0.5, String(other.name))


func native_view() -> Dictionary:
	var view := super.native_view()
	view["map"] = map
	view["bake_radius"] = bake_radius
	if NativeBridge.available and NativeBridge.nav != null:
		view["nav"] = NativeBridge.nav  # the game's one polygon index (native's review): the C++ field reads through it
	return view


func _wall_distance(x: float, z: float) -> float:
	var at := Vector3(x, 0.0, z)
	var closest := NavigationServer3D.map_get_closest_point(map, at)
	return bake_radius - Vector2(closest.x - x, closest.z - z).length()
