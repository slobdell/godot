class_name ArenaShape
extends RefCounted
## The arena's PERIMETER as data (arena, round 7): the wall's inner face, and what stands behind each stretch of it.
##
## The lead: *"Our environment is very clearly a simple square… the arena could also take on octagon or hexagon-like
## shapes."* The shape is arena's; the wall-cutaway maths that uses it is control's; the stands behind it are
## feel's. This class is the seam, handed over **once at load** rather than called per frame — a per-frame call
## across a stream boundary would be a standing performance obligation, and would make the shape answerable to
## control's frame budget. **The shape is ours, the maths is theirs.**
##
## HEXAGON is the shipping choice (see round7_contract.md): at the 120 m inner face it is the shape that VARIES
## most — **277 m of lateral room at midfield against 208 m at the approaches** — so it gives an open middle and two
## natural funnels before a single prop is placed. An octagon is the most uniform arena available (240 m at
## midfield, 8.2% variation in reach, 135° corners that shelter almost nothing), and uniformity is the failure mode
## we are answering.
##
## (feel's tiling figures are quoted at a 121 m apothem — the wall's CENTRE LINE — and so read 139.7 m a side where
## this file says 138.6 m. Both are right for what they measure: feel builds the wall, we bound the play. The 1.1 m
## costs feel about 5 cm per grandstand module, which its 0.65 m of slack absorbs.)
##
## SPANS, not one value per edge. control needs to know what is behind a *bit* of wall, because its occlusion test
## judges sight lines against the stands' profile and a gate has no stands behind it. A single `behind` per edge
## could not describe the very first layout anyone tried to write with it — feel's base side is stands, then a
## gate in the middle, then stands — and a scalar that needs an exception on its first real use will need more.
## Each edge therefore carries an ordered list.
##
## A span is authored as `{kind, to_m}` — where it ENDS along its edge — so a gap between spans is not expressible
## rather than merely invalid, and the last `to_m` is the edge's length. `edges()` hands consumers the explicit
## `{kind, from_m, to_m}` form, derived once. One source of truth, two shapes of it, no drift.

## kind -> number of sides. The perimeter is always regular and always contains a 180° rotation, because the
## navmesh is baked as one half plus its mirror and that is what keeps the two bases fair (trip-up 21).
const KINDS := {"square": 4, "hexagon": 6, "octagon": 8}
## What can sit behind a stretch of wall. `stands` occludes along feel's seating profile; `gate` is the tunnel an
## army enters through and has nothing behind it; `none` is bare wall.
const SPAN_KINDS := ["stands", "gate", "none"]
const DEFAULT_KIND := "square"
## The perimeter wall's height, and the value control's cutaway must clear. **3 m, not a round number I picked:**
## the perimeter colliders in arena.tscn are 3 m tall and feel's `ArenaDressing.WALL_HEIGHT` is 3.0 to match. An
## earlier draft of this file said 8.0, which would have had control cutting five metres above the wall it is
## trying to see over. If the visual wall ever diverges from the collider, the layout's `wall_height_m` is the
## contract value and both sides read it from here.
const DEFAULT_WALL_HEIGHT := 3.0


static func sides(kind: String) -> int:
	return int(KINDS.get(kind, 4))


## The wall's INNER FACE, counter-clockwise in world x/z, for a regular `kind` whose apothem is `apothem`.
##
## The apothem is the layout's `half_size` (120 m) and that is deliberate, not an off-by-one: the perimeter
## colliders are 2 m thick centred at ±121, so their inner face lands exactly on ±120. Do not "fix" this to 121 —
## that is the wall's centre line, and control is cutting against the face a vehicle can touch.
##
## Oriented with a FLAT SIDE facing each base, so the bases stay on a wall as they always have. A vertex-to-base
## hexagon would invert the shape's character — pinched middle, wide approaches — and put each spawn in a corner.
## `bound` is `half_size`, and it means **the arena's widest reach along an axis** — the same thing for every
## shape, which is what lets the radar, the fog and `ThreatField` keep sizing from one number.
##
## That mapping is not the same as "circumradius" or "apothem", and saying so cost me a bug: built with the
## circumradius equal to the bound, a SQUARE came out with half-width 85 m instead of 120 and
## `Arena.contains(110, 110)` started refusing a corner every existing arena owns. Scaling so the widest axis
## extent equals the bound reproduces today's square exactly (corners at bound·√2, sides at ±bound) and puts a
## flat-to-base hexagon's side vertices at ±bound on the x axis.
static func vertices(kind: String, bound: float) -> PackedVector2Array:
	var n := sides(kind)
	var widest := 0.0
	for k in n:
		widest = maxf(widest, absf(sin(TAU * float(k) / float(n) + PI / float(n))))
	var radius := bound / maxf(widest, 0.0001)
	var out := PackedVector2Array()
	for k in n:
		var a := TAU * float(k) / float(n) + PI / float(n)
		out.append(Vector2(radius * sin(a), radius * cos(a)))
	return out


## The circumradius the polygon is actually built at, for callers that need the real reach (the perimeter builder,
## and anything asking "how far out does a corner go").
static func circumradius(kind: String, bound: float) -> float:
	var n := sides(kind)
	var widest := 0.0
	for k in n:
		widest = maxf(widest, absf(sin(TAU * float(k) / float(n) + PI / float(n))))
	return bound / maxf(widest, 0.0001)


## The side length of the polygon `vertices()` builds.
static func edge_length(kind: String, bound: float) -> float:
	return 2.0 * circumradius(kind, bound) * sin(PI / float(sides(kind)))


## Every edge as {from, to, length_m, wall_height_m, spans: [{kind, from_m, to_m}]}, spans running along the edge
## from `from` to `to`. Always contiguous and always covering the whole edge.
static func edges(shape: Dictionary, apothem: float) -> Array:
	var kind := String(shape.get("kind", DEFAULT_KIND))
	var points := vertices(kind, apothem)
	var length := edge_length(kind, apothem)
	var height := float(shape.get("wall_height_m", DEFAULT_WALL_HEIGHT))
	var authored: Array = shape.get("edges", [])
	var out: Array = []
	for i in points.size():
		var spans: Array = []
		var cursor := 0.0
		var listed: Array = authored[i].get("spans", []) if i < authored.size() else []
		for span: Dictionary in listed:
			var to: float = float(span["to_m"])
			spans.append({"kind": String(span["kind"]), "from_m": cursor, "to_m": to})
			cursor = to
		if spans.is_empty():
			spans.append({"kind": "stands", "from_m": 0.0, "to_m": length})
		out.append({"from": points[i], "to": points[(i + 1) % points.size()], "length_m": length,
				"wall_height_m": height, "spans": spans})
	return out


## Is `point` inside the shape? Convex, so a point is inside when it is on the inner side of every edge.
static func contains(kind: String, bound: float, point: Vector2, margin := 0.0) -> bool:
	var v := vertices(kind, bound)
	for i in v.size():
		var a: Vector2 = v[i]
		var b: Vector2 = v[(i + 1) % v.size()]
		var edge := b - a
		# vertices() is counter-clockwise in x/z, so the interior is to the RIGHT of each edge in this basis.
		if edge.x * (point.y - a.y) - edge.y * (point.x - a.x) > -margin * edge.length():
			return false
	return true


## The nearest point on or inside the shape. **Nearest point on the boundary, not "along the ray to the centre"** —
## chosen with control, whose reason is the one to remember: *"a centre-ray point near a corner lands somewhere he
## didn't point at."* Clicking past the wall should put the unit against the wall nearest the click. Said here
## because the next caller will assume the other one, and both are defensible in the abstract.
static func clamp_into(kind: String, bound: float, point: Vector2, margin := 0.0) -> Vector2:
	if contains(kind, bound, point, margin):
		return point
	var v := vertices(kind, bound)
	var best := point
	var best_distance := INF
	for i in v.size():
		var a: Vector2 = v[i]
		var b: Vector2 = v[(i + 1) % v.size()]
		var edge := b - a
		var t := clampf((point - a).dot(edge) / maxf(edge.length_squared(), 0.0001), 0.0, 1.0)
		# Pull in by `margin` along the inward normal so a clamped point is inside, not exactly on the line.
		var inward := Vector2(edge.y, -edge.x).normalized()
		var on_edge := a + edge * t + inward * margin
		var distance := point.distance_to(on_edge)
		if distance < best_distance:
			best_distance = distance
			best = on_edge
	return best


## "" when the shape is well formed, else why not. Point symmetry is the whole reason this is checked at all: an
## asymmetric perimeter is an asymmetric navmesh bake, and that is worth 64% of matches to whichever base it
## favours.
static func validate(shape: Variant, apothem: float) -> String:
	if typeof(shape) != TYPE_DICTIONARY:
		return "'shape' must be an object like {\"kind\": \"hexagon\"}"
	var kind := String(shape.get("kind", DEFAULT_KIND))
	if not KINDS.has(kind):
		return "unknown arena shape '%s' (have %s)" % [kind, ", ".join(PackedStringArray(KINDS.keys()))]
	if shape.has("wall_height_m") and float(shape["wall_height_m"]) <= 0.0:
		return "shape.wall_height_m must be positive"
	var n := sides(kind)
	var authored: Variant = shape.get("edges", [])
	if typeof(authored) != TYPE_ARRAY:
		return "shape.edges must be a list"
	if not authored.is_empty() and authored.size() != n:
		return "shape.edges has %d entries; a %s has %d sides" % [authored.size(), kind, n]
	var length := edge_length(kind, apothem)
	for i in authored.size():
		if typeof(authored[i]) != TYPE_DICTIONARY:
			return "shape.edges[%d] must be an object" % i
		var spans: Variant = authored[i].get("spans", [])
		if typeof(spans) != TYPE_ARRAY or spans.is_empty():
			return "shape.edges[%d] needs a non-empty 'spans' list" % i
		var cursor := 0.0
		for span in spans:
			if typeof(span) != TYPE_DICTIONARY or not String(span.get("kind", "")) in SPAN_KINDS:
				return "shape.edges[%d]: every span needs a kind from %s" % [i, ", ".join(SPAN_KINDS)]
			if not (typeof(span.get("to_m")) in [TYPE_INT, TYPE_FLOAT]) or float(span["to_m"]) <= cursor:
				return "shape.edges[%d]: span 'to_m' must increase along the edge (after %.1f m)" % [i, cursor]
			cursor = float(span["to_m"])
		if absf(cursor - length) > 0.05:
			return "shape.edges[%d]: spans end at %.2f m but the edge is %.2f m long" % [i, cursor, length]
	# Rotating the arena 180° maps edge k onto edge k + n/2 with its direction preserved, so their spans must be
	# identical. That makes symmetry a list comparison rather than a geometric argument.
	for i in range(authored.size() / 2):
		var here: Array = authored[i].get("spans", [])
		var across: Array = authored[i + n / 2].get("spans", [])
		if here.size() != across.size():
			return "not point-symmetric: shape.edges[%d] and [%d] have different spans" % [i, i + n / 2]
		for j in here.size():
			if String(here[j]["kind"]) != String(across[j]["kind"]) \
					or absf(float(here[j]["to_m"]) - float(across[j]["to_m"])) > 0.05:
				return "not point-symmetric: shape.edges[%d] span %d differs from edge [%d]'s" % [i, j, i + n / 2]
	return ""
