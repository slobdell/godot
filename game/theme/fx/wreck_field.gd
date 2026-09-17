class_name WreckField
extends RefCounted
## Burned-out husks where vehicles died (render stretch, round 5): the Match hides a dead vehicle, so without this a
## finished fight left an empty floor. Each wreck is an instance of KitYard's `wreck` MultiMesh (the approved husk fit
## to its hull), so a battlefield of them is one draw. Visual only: no collision (the rules say wrecks don't block).
## The oldest go first past the tier's cap; a new match clears them.

const PER_TIER := {FxQuality.Tier.LOW: 12, FxQuality.Tier.MEDIUM: 24, FxQuality.Tier.HIGH: 48}
## The same death reported twice (a killing hit, then unit_destroyed) within this long leaves one wreck.
const DUPLICATE_SECONDS := 2.0

## [{id, unit, time}] oldest first.
var wrecks: Array[Dictionary] = []

var _yard: KitYard


func _init(yard: KitYard = null) -> void:
	_yard = yard


## Leave a wreck at `position` (ground), facing `forward`, sized to `hull_size` [width, height, length] when given.
func add(owner: Node, position: Vector3, forward: Vector3, hull_size: Variant, unit_name: String, now: float) -> void:
	for wreck in wrecks:
		if unit_name != "" and wreck["unit"] == unit_name and now - float(wreck["time"]) < DUPLICATE_SECONDS:
			return
	if _yard == null or not is_instance_valid(_yard):
		_yard = KitYard.for_node(owner)
	var ahead := Vector3(forward.x, 0.0, forward.z)
	var basis := Basis.looking_at(ahead.normalized()) if ahead.length() > 0.01 else Basis.IDENTITY
	var xform := Transform3D(basis * Basis.from_scale(WreckField.scale_for(hull_size)), Vector3(position.x, 0.0, position.z))
	wrecks.append({"id": _yard.add("wreck", xform), "unit": unit_name, "time": now})
	while wrecks.size() > int(PER_TIER[FxQuality.tier()]):
		_yard.remove(int(wrecks.pop_front()["id"]))


func clear() -> void:
	if _yard != null and is_instance_valid(_yard):
		for wreck in wrecks:
			_yard.remove(int(wreck["id"]))
	wrecks.clear()


func count() -> int:
	return wrecks.size()


## The husk (built to KitYard.WRECK) scaled to a hull's footprint, never stretched more than 40% between axes.
static func scale_for(hull_size: Variant) -> Vector3:
	if not (hull_size is Array) or (hull_size as Array).size() < 3:
		return Vector3(0.75, 0.75, 0.6)
	var sx := float(hull_size[0]) / KitYard.WRECK.x
	var sz := float(hull_size[2]) / KitYard.WRECK.z
	sx = clampf(sx, sz / 1.4, sz * 1.4)
	var sy := minf(sx, sz)
	return Vector3(sx, sy, sz)
