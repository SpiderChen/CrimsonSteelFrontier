extends Range
## A small gauge without font-driven minimum height.
var color := Color("8cdec3")
const FRAME = preload("res://assets/free/ui/meter_frame.png")
const FILL = preload("res://assets/free/ui/meter_fill.png")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_changed.connect(func(_value): queue_redraw())
	resized.connect(queue_redraw)
func _draw() -> void:
	var background := StyleBoxTexture.new()
	background.texture = FRAME
	background.texture_margin_left = minf(6,size.x*0.5); background.texture_margin_right = minf(6,size.x*0.5)
	background.texture_margin_top = minf(6,size.y*0.5); background.texture_margin_bottom = minf(6,size.y*0.5)
	background.modulate_color = Color("405264")
	draw_style_box(background,Rect2(Vector2.ZERO,size))
	var fraction := get_as_ratio()
	if fraction>0:
		var inset := minf(2,size.y*0.2)
		var area := Rect2(Vector2.ONE*inset,Vector2(maxf(0,size.x-inset*2)*fraction,maxf(0,size.y-inset*2)))
		draw_texture_rect(FILL,area,false,color)
