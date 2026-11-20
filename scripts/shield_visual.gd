extends RefCounted
## The shield uses the same silhouette, deformation and transform as the hull.
const IDLE_ALPHA: float = 0.16
const HIT_SECONDS: float = 0.22
static var contours: Dictionary = {}

static func contour(texture: Texture2D, source: Rect2) -> PackedVector2Array:
	var key := texture.get_instance_id()
	if contours.has(key): return contours[key]
	var image := texture.get_image().get_region(Rect2i(source))
	var polygon := preload("res://scripts/production_art.gd").solid_outline(image,0.45)
	var points := PackedVector2Array()
	for point in polygon: points.append(point/source.size)
	if not points.is_empty(): points.append(points[0])
	contours[key] = points
	return points

static func fitted_points(texture: Texture2D, source: Rect2, rect: Rect2, warp: Callable) -> PackedVector2Array:
	var result := PackedVector2Array()
	for uv in contour(texture,source):
		var point: Vector2 = rect.position+uv*rect.size
		# A small local offset follows the armor rather than expanding a world-space circle.
		point += rect.get_center().direction_to(point)*1.5
		result.append(warp.call(point))
	return result

static func render_body(canvas: CanvasItem, defense: RefCounted, texture: Texture2D, source: Rect2, rect: Rect2, warp: Callable, elapsed: float, hit_angle: float) -> void:
	var active: bool = defense.total_shield()>0
	var hit: float = clampf(defense.shield_flash/HIT_SECONDS,0,1)
	if not active and hit<=0: return
	var points := fitted_points(texture,source,rect,warp)
	if points.size()<3: return
	if active:
		canvas.draw_polyline(points,Color(0.47,0.83,0.93,IDLE_ALPHA+sin(elapsed*1.7)*0.02),2.2,true)
	if hit>0:
		var direction := Vector2.from_angle(hit_angle)
		for i in range(1,points.size()):
			var outward: Vector2 = rect.get_center().direction_to((points[i-1]+points[i])*0.5)
			if outward.dot(direction)<0.55: continue
			canvas.draw_line(points[i-1],points[i],Color(0.7,0.95,1,hit*0.7),3.5,true)
