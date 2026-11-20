extends RefCounted
## Complete scenery sprites; collision and interaction rules remain owned by the world.
const CONTENT = preload("res://scripts/production_art.gd")
static func building(canvas: CanvasItem,p: Vector2,region: int,variation: int) -> void:
	var width := 110.0+posmod(variation,3)*6.0
	CONTENT.object(canvas,"buildings",region,p+Vector2(64,62),Vector2(width,116),Color.WHITE.lerp(Color("a5b8c5"),0.10 if variation%2==0 else 0.0))
static func vegetation(canvas: CanvasItem,p: Vector2,region: int,variation: int) -> void:
	CONTENT.object(canvas,"props",region,p+Vector2(36+posmod(variation,45),55+posmod(variation,30)),Vector2(60,64))
static func site(canvas: CanvasItem,p: Vector2,kind: String,_color: Color,region: int=0) -> void:
	if kind=="boss_site":
		preload("res://scripts/rig/unit_art.gd").render(canvas,p-Vector2(0,6),Vector2.ONE*110,"boss","boss_site",region)
	else:
		var index: int={"resource":0,"supply":0,"cache":1,"cooling":2,"beacon":3}.get(kind,3)
		CONTENT.object(canvas,"facilities",index,p-Vector2(0,8),Vector2(78,78))
static func hangar(canvas: CanvasItem,dimensions: Vector2) -> void:
	CONTENT.draw(canvas,"hangar",0,Rect2(Vector2.ZERO,dimensions),Color.WHITE,false)
