extends RefCounted
## Viewports belong to their canvas; stale/offscreen instances are retired during drawing.
const VIEW = preload("res://scripts/rig/unit_viewport.gd")

static func view_for(canvas: CanvasItem, key: String) -> SubViewport:
	var views: Dictionary = canvas.get_meta("unit_3d_views",{})
	var frame := Engine.get_process_frames()
	for id in views.keys():
		if not is_instance_valid(views[id]): views.erase(id)
		elif frame-views[id].touched_frame>120 and id!=key:
			views[id].queue_free(); views.erase(id)
	if not views.has(key):
		var view = VIEW.new(); canvas.add_child(view); views[key] = view
	canvas.set_meta("unit_3d_views",views)
	return views[key]

static func render(canvas: CanvasItem, center: Vector2, dimensions: Vector2, kind: String, key: String, variant: int = 0, elite: bool = false, direction: Vector2 = Vector2(0.7,1), moving: bool = false, elapsed: float = 0, state: Dictionary = {}) -> void:
	var view = view_for(canvas,key)
	view.update_model(kind,variant,elite,direction,moving,elapsed,state)
	canvas.draw_texture_rect(view.get_texture(),Rect2(center-dimensions*0.5,dimensions),false)
