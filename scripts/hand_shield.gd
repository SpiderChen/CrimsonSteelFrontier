extends RefCounted
## A physical held shield; the separate energy shield keeps its existing rules.
const TRAIT = "hand_shield"
const ARC = 2.094395
const BLOCK = 0.6
const RECOVERY_DELAY = 2.0
const RECOVERY_RATE = 12.0
const BREAK_SECONDS = 2.0

static func draw_weapon(canvas: CanvasItem, grip: Vector2, direction: Vector2, scale_value: float = 1.0) -> void:
	preload("res://scripts/production_art.gd").item(canvas,24,grip+direction*12*scale_value,Vector2(44,66)*scale_value,0,direction.x<0)

static func render_guard(canvas: CanvasItem, defense: RefCounted, center: Vector2, scale_value: float) -> void:
	if defense.max_guard<=0: return
	var color := Color("ff7272") if defense.guard_break>0 else Color("8cdec3")
	var angle: float = defense.guard_facing.angle()
	canvas.draw_arc(center,43*scale_value,angle-ARC*0.5,angle+ARC*0.5,28,Color(color,0.35 if defense.guard_break>0 else 0.85),4*scale_value,true)
	canvas.draw_rect(Rect2(center+Vector2(-22,34)*scale_value,Vector2(44,4)*scale_value),Color("273545"))
	canvas.draw_rect(Rect2(center+Vector2(-22,34)*scale_value,Vector2(44*clampf(defense.guard/defense.max_guard,0,1),4)*scale_value),color)
