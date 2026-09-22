class_name ArenaKit
extends RefCounted
## The arena kit as GAMEPLAY sees it (arena X1, round 5, contract M2): what each prop placed by a layout's `props`
## list is physically, so Arena can build its collision, the AI can read it as cover, and render can dress it through
## the `prop.<type>` visual slot. Pure data plus footprint math; no nodes. The design vocabulary is _agents/arenas.md.
##
## Heights are the lever (Perception.EYE_HEIGHT is 1.3 m, muzzles sit 1.05-1.27 m, hulls are 1.4-1.6 m tall):
## - "hard" cover is taller than eye level: it blocks sight, shells and hulls. One container is already that.
## - "low" cover (barricades, 0.9 m) stops hulls but not eyes or guns: it shapes movement while leaving fire lanes open,
##   and only catches shells aimed low at a vehicle hugging it.
## - decoration (`collides: false`) has no gameplay at all, so it is exempt from point symmetry.

## type → size [x, height, z] for ONE level (meters, before rotation; long axis along x), cover, and optional
## max_stack (stackable), collides (default true), fallback (a visual slot to scale when the theme lacks prop.<type>;
## a kit prop with neither shows nothing until render adds its slot).
const PROPS := {
	# ISO 668 shipping containers; the visual (theme/arena_kit/containers) has its long axis along x too.
	"container_20": {"size": [6.06, 2.59, 2.44], "cover": "hard", "max_stack": 3},
	"container_40": {"size": [12.19, 2.59, 2.44], "cover": "hard", "max_stack": 3},
	# The 7 x 14 m LED wall stands on legs over a concrete plinth (7.4 x 1.4). R3 (round 10): the panel's housing,
	# drawn from 5.71 m up, is 7.80 x 1.92 m, and the tallest hull (6.18 m) can reach it, so the box is 7.8 x 2.0,
	# not the plinth's footprint (tests/test_arena_prop_parity.gd measures it; the test decides, not this comment).
	# If feel raises the housing above the tallest roof, the box can return to the plinth.
	"ad_screen": {"size": [7.8, 1.4, 2.0], "cover": "hard"},
	# Jersey-barrier runs: stop a hull, not a shell or a sightline.
	"barricade": {"size": [6.0, 0.9, 0.8], "cover": "low", "fallback": "prop.wall"},
	# A burned-out husk left as permanent cover (theme prop.wreck, scaled to this box by render).
	"wreck": {"size": [3.2, 2.0, 6.4], "cover": "hard"},
	# A floodlight tower's concrete footing; the mast above it is too thin to matter.
	"floodlight": {"size": [2.4, 3.0, 2.4], "cover": "hard", "fallback": "prop.crate"},
	# A neon sign on a post: spectacle only.
	"sign": {"size": [0.4, 6.0, 0.4], "cover": "none", "collides": false},
	# Round 7 (feel, agreed with arena): a city block, theme prop.block (CityBlock). One box of `size`; the art fills its
	# footprint at ground level and steps in only above the shopfronts, so this box is what you see where it matters.
	"block": {"size": [40.0, 24.0, 40.0], "cover": "hard"},
}
## **Adding a type here is not an additive change.** `test_every_kit_prop_type_has_a_visual_slot` requires a
## `prop.<type>` slot in the theme for every entry, with no stand-in — so a new kind must land in the SAME COMMIT
## as its slot and its scene, which means whoever owns the art adds both. Round 7: `block` (feel's cityscape kit,
## agreed at 40 x 24 x 40 m, `cover: "hard"`) is waiting on that, deliberately, rather than being added here first
## and breaking render's check for every stream.
##
## Keys a prop may carry for its look (read by the visual's setup(prop)); they never affect gameplay or symmetry.
const LOOK_KEYS := ["faction", "paint", "stencil", "rust", "doors", "channel", "sign", "color", "variant",
		"tiers", "setback", "neon", "seed"]  # the last four: a city block's look (CityBlock), never its footprint
## Region kinds the AI and the measurements understand (_agents/arenas.md defines each).
const REGION_KINDS := ["centre", "open_ground", "cover_cluster", "chokepoint", "flank", "overlook"]


static func is_kit(type: String) -> bool:
	return PROPS.has(type)


static func collides(type: String) -> bool:
	return bool(PROPS[type].get("collides", true))


static func max_stack(type: String) -> int:
	return int(PROPS[type].get("max_stack", 1))


## The collision box of a placed prop: one level's footprint, as tall as its stack.
static func size_of(prop: Dictionary) -> Vector3:
	var one: Array = PROPS[prop["type"]]["size"]
	return Vector3(one[0], float(one[1]) * int(prop.get("stack", 1)), one[2])


static func cover_of(type: String) -> String:
	return String(PROPS[type]["cover"])


## Distance from `point` (x, z) to the rotated rectangle of an obstacle with ground `center`, `size` (x, _, z) and
## `rotation_deg`; 0 inside.
static func distance_to_footprint(point: Vector2, center: Vector2, size: Vector3, rotation_deg: float) -> float:
	var angle := deg_to_rad(rotation_deg)
	# Basis(UP, angle): local x maps to world (cos, -sin), local z to world (sin, cos) in (x, z).
	var d := point - center
	var local := Vector2(d.x * cos(angle) - d.y * sin(angle), d.x * sin(angle) + d.y * cos(angle))
	var outside := Vector2(maxf(absf(local.x) - size.x / 2.0, 0.0), maxf(absf(local.y) - size.z / 2.0, 0.0))
	return outside.length()
