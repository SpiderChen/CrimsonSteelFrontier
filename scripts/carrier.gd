extends Control
## Shared live 3D capital ship for the bridge, base and exploration map.
const ART = preload("res://scripts/rig/unit_art.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

static func render(canvas: CanvasItem, center: Vector2, scale_value: float) -> void:
	ART.render(canvas,center,Vector2.ONE*460*scale_value,"carrier","carrier")

func _draw() -> void:
	render(self,size/2,minf(size.x/460.0,size.y/210.0))
