extends RefCounted
## Real production sprites. Cell geometry is retained for VFX anchors; object alpha margins are fitted once.
const SHEETS = {
	"enemies":preload("res://assets/generated/production/enemies.png"),
	"bosses":preload("res://assets/generated/production/bosses.png"),
	"buildings":preload("res://assets/generated/production/buildings.png"),
	"facilities":preload("res://assets/generated/production/facilities.png"),
	"props":preload("res://assets/generated/production/props.png"),
	"terrain":preload("res://assets/generated/production/terrain.png"),
	"equipment":preload("res://assets/generated/production/equipment.png"),
	"fx-kinetic":preload("res://assets/generated/production/fx-kinetic.png"),
	"fx-energy":preload("res://assets/generated/production/fx-energy.png"),
	"fx-shield":preload("res://assets/generated/production/fx-shield.png"),
	"fx-repair":preload("res://assets/generated/production/fx-repair.png"),
	"fx-scarlet":preload("res://assets/generated/production/fx-scarlet.png"),
	"fx-overcharge":preload("res://assets/generated/production/fx-overcharge.png"),
	"hangar":preload("res://assets/generated/production/hangar.png")
}
const GRIDS = {"enemies":Vector2i(2,2),"bosses":Vector2i(2,2),"buildings":Vector2i(2,2),"facilities":Vector2i(2,2),"props":Vector2i(2,2),"terrain":Vector2i(4,4),"equipment":Vector2i(5,5),"fx-kinetic":Vector2i(4,4),"fx-energy":Vector2i(4,4),"fx-shield":Vector2i.ONE,"fx-repair":Vector2i.ONE,"fx-scarlet":Vector2i.ONE,"fx-overcharge":Vector2i.ONE,"hangar":Vector2i.ONE}
const SUPPORT_KEYS = ["fx-shield","fx-repair","fx-scarlet","fx-overcharge"]
const WEAPONS = {"standard":0,"burst":0,"rail":1,"plasma":2,"laser":15,"pulse":18,"missile":16,"blade":21,"gauntlet":22,"hammer":23,"hand_shield":24}
static var cells: Dictionary = {}
static var fitted: Dictionary = {}
static var atlases: Dictionary = {}
static var drawn: Dictionary = {}

static func solid_outline(image: Image, threshold: float = 0.2) -> PackedVector2Array:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image,threshold)
	var largest := PackedVector2Array()
	var largest_area := 0.0
	for polygon in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),1.5):
		var area := 0.0
		for i in range(polygon.size()): area += polygon[i].cross(polygon[(i+1)%polygon.size()])
		if absf(area)>largest_area:
			largest_area = absf(area); largest = polygon
	return largest

static func prepare(key: String) -> void:
	if cells.has(key): return
	var grid: Vector2i = GRIDS[key]
	var image: Image = SHEETS[key].get_image()
	var full: Array[Rect2] = []
	var cropped: Array[Rect2] = []
	for index in range(grid.x*grid.y):
		var x: int = index%grid.x
		var y: int = index/grid.x
		var start := Vector2i(floori(float(x)*image.get_width()/grid.x),floori(float(y)*image.get_height()/grid.y))
		var end := Vector2i(floori(float(x+1)*image.get_width()/grid.x),floori(float(y+1)*image.get_height()/grid.y))
		var rect := Rect2i(start,end-start)
		var used: Rect2i = image.get_region(rect).get_used_rect()
		if key=="equipment":
			# Ignore almost-transparent atlas residue and neighboring isolated specks.
			var outline := solid_outline(image.get_region(rect))
			if not outline.is_empty():
				var bounds := Rect2(outline[0],Vector2.ZERO)
				for point in outline: bounds = bounds.expand(point)
				used = Rect2i(bounds.grow(2)).intersection(Rect2i(Vector2i.ZERO,rect.size))
		full.append(Rect2(rect))
		cropped.append(Rect2(Rect2i(rect.position+used.position,used.size)) if used.has_area() else Rect2(rect))
	cells[key] = full; fitted[key] = cropped

static func source(key: String,index: int,trim: bool = true) -> Rect2:
	prepare(key)
	var count: int = cells[key].size()
	return fitted[key][clampi(index,0,count-1)] if trim else cells[key][clampi(index,0,count-1)]

static func texture(key: String,index: int,trim: bool = true) -> AtlasTexture:
	var id := "%s:%d:%s"%[key,index,trim]
	if not atlases.has(id):
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEETS[key]; atlas.region = source(key,index,trim)
		atlas.filter_clip = true
		atlases[id] = atlas
	return atlases[id]

static func draw(canvas: CanvasItem,key: String,index: int,rect: Rect2,color: Color = Color.WHITE,trim: bool = true) -> void:
	canvas.draw_texture_rect_region(SHEETS[key],rect,source(key,index,trim),color)
	drawn[key] = int(drawn.get(key,0))+1

static func object(canvas: CanvasItem,key: String,index: int,center: Vector2,bounds: Vector2,color: Color = Color.WHITE) -> void:
	var region := source(key,index)
	var factor := minf(bounds.x/region.size.x,bounds.y/region.size.y)
	var dimensions := region.size*factor
	draw(canvas,key,index,Rect2(center-dimensions*0.5,dimensions),color)

static func quad(canvas: CanvasItem,key: String,index: int,center: Vector2,dimensions: Vector2,angle: float = 0,color: Color = Color.WHITE,trim: bool = false,flip: bool = false) -> void:
	var region := source(key,index,trim)
	var image_size: Vector2 = SHEETS[key].get_size()
	var uv := Rect2(region.position/image_size,region.size/image_size)
	var corners := PackedVector2Array([Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)])
	var points := PackedVector2Array()
	for corner in corners: points.append(center+(corner*dimensions).rotated(angle))
	var left: float = uv.end.x if flip else uv.position.x
	var right: float = uv.position.x if flip else uv.end.x
	var uvs := PackedVector2Array([Vector2(left,uv.position.y),Vector2(right,uv.position.y),Vector2(right,uv.end.y),Vector2(left,uv.end.y)])
	canvas.draw_polygon(points,PackedColorArray([color,color,color,color]),uvs,SHEETS[key])
	drawn[key] = int(drawn.get(key,0))+1

static func item(canvas: CanvasItem,index: int,center: Vector2,bounds: Vector2,angle: float = 0,flip: bool = false) -> void:
	var region := source("equipment",index)
	var dimensions := region.size*minf(bounds.x/region.size.x,bounds.y/region.size.y)
	quad(canvas,"equipment",index,center,dimensions,angle,Color.WHITE,true,flip)

static func enemy(canvas: CanvasItem,point: Vector2,role: String,elite: bool,scale_value: float = 1,flip: bool = false,instance_key: String = "",direction: Vector2 = Vector2.ZERO,moving: bool = false,elapsed: float = 0) -> void:
	if role not in ["guard","rusher","cannon","drone"]: role = "guard"
	if direction==Vector2.ZERO: direction = Vector2(-0.7,1) if flip else Vector2(0.7,1)
	preload("res://scripts/rig/unit_art.gd").render(canvas,point-Vector2(0,16)*scale_value,Vector2.ONE*112*scale_value,role,"enemy:"+instance_key if instance_key!="" else "enemy:%s:%s:%s"%[role,elite,flip],0,elite,direction,moving,elapsed)

static func frame(progress: float) -> int:
	return clampi(int(progress*4),0,3)

static func fx(canvas: CanvasItem,key: String,row: int,center: Vector2,dimensions: Vector2,progress: float,angle: float = 0,opacity: float = 1) -> void:
	if key=="fx-support":
		var source_key: String = SUPPORT_KEYS[clampi(row,0,3)]
		var region := source(source_key,0)
		var fitted_size := region.size*minf(dimensions.x/region.size.x,dimensions.y/region.size.y)
		quad(canvas,source_key,0,center,fitted_size*(0.92+sin(progress*PI)*0.08),angle,Color(1,1,1,opacity),true)
	else:
		quad(canvas,key,row*4+frame(progress),center,dimensions,angle,Color(1,1,1,opacity))
