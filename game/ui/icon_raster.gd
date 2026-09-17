class_name IconRaster
extends RefCounted
## Control X4 (CP1: the HUD ≤ 130 draw calls): a stand-in canvas that paints CommandIcons' draw calls into an Image, so a
## pictogram can be drawn once into a texture and then shown as one batched rect instead of five vector draw calls.
## Implements only the calls CommandIcons uses, with one pixel of antialiasing from distance to each shape's edge.

var image: Image
var size: int


func _init(p_size: int) -> void:
	size = p_size
	image = Image.create(size, size, false, Image.FORMAT_RGBA8)


func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
	_paint(_bounds(points, 1.0), color, func(p: Vector2) -> float:
		var edge := INF
		for i in points.size():
			edge = minf(edge, _segment_distance(p, points[i], points[(i + 1) % points.size()]))
		return edge if Geometry2D.is_point_in_polygon(p, points) else -edge)


func draw_polyline(points: PackedVector2Array, color: Color, width := -1.0, _antialiased := false) -> void:
	for i in points.size() - 1:
		draw_line(points[i], points[i + 1], color, width)


func draw_line(from: Vector2, to: Vector2, color: Color, width := -1.0, _antialiased := false) -> void:
	var half := maxf(width, 1.0) / 2.0
	_paint(_bounds(PackedVector2Array([from, to]), half + 1.0), color, func(p: Vector2) -> float:
		return half - _segment_distance(p, from, to))


func draw_circle(center: Vector2, radius: float, color: Color, _filled := true, _width := -1.0, _antialiased := false) -> void:
	_paint(Rect2(center - Vector2.ONE * (radius + 1.0), Vector2.ONE * (radius + 1.0) * 2.0), color, func(p: Vector2) -> float:
		return radius - p.distance_to(center))


func draw_rect(rect: Rect2, color: Color, _filled := true, _width := -1.0, _antialiased := false) -> void:
	draw_colored_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]), color)


func texture() -> ImageTexture:
	return ImageTexture.create_from_image(image)


## Blend `color` over every pixel in `area`, weighted by how far inside the shape it is (`inside` > 0 is inside, in px).
func _paint(area: Rect2, color: Color, inside: Callable) -> void:
	var from := Vector2i(maxi(0, floori(area.position.x)), maxi(0, floori(area.position.y)))
	var to := Vector2i(mini(size, ceili(area.end.x)), mini(size, ceili(area.end.y)))
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			var coverage := clampf(float(inside.call(Vector2(x + 0.5, y + 0.5))) + 0.5, 0.0, 1.0)
			if coverage <= 0.0:
				continue
			var under := image.get_pixel(x, y)
			var alpha := color.a * coverage
			var out_alpha := alpha + under.a * (1.0 - alpha)
			var rgb := (Color(color.r, color.g, color.b) * alpha + Color(under.r, under.g, under.b) * under.a * (1.0 - alpha)) \
					/ maxf(out_alpha, 0.0001)
			image.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, out_alpha))


static func _bounds(points: PackedVector2Array, grow: float) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box.grow(grow)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
