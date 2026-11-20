extends RefCounted
## Cosmetic, world-anchored dressing. Never queries or changes navigation or discovery.
const CACHE_LIMIT: int = 384
const CELL: float = 128.0
const PALETTES = [
	{"wash":Color("c3a58c"),"patch":Color("382e28"),"edge":Color("b18b61"),"light":Color("efb96d"),"air":Color("bea086")},
	{"wash":Color("a6cbd8"),"patch":Color("517c8b"),"edge":Color("9bbfc9"),"light":Color("8cdddc"),"air":Color("bad2d8")},
	{"wash":Color("e8c59b"),"patch":Color("a38a62"),"edge":Color("e3c395"),"light":Color("e2cc9c"),"air":Color("d2b18b")},
	{"wash":Color("a3b5cf"),"patch":Color("1a293b"),"edge":Color("8c9bb7"),"light":Color("aab6e9"),"air":Color("8296b1")}
]
var cache: Dictionary = {}

func cell_data(cell: Vector2i, region: int, map_seed: int) -> Dictionary:
	var key := "%d:%d:%d:%d"%[cell.x,cell.y,region,map_seed]
	if cache.has(key): return cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(cell.x*73856093 ^ cell.y*19349663 ^ map_seed ^ region*83492791)
	var center := Vector2(rng.randf_range(34,94),rng.randf_range(34,94))
	var patch := PackedVector2Array()
	for i in range(10):
		var angle := i*TAU/10.0
		patch.append((center+Vector2(cos(angle),sin(angle))*Vector2(36,24)*rng.randf_range(0.65,1.35)).clamp(Vector2(2,2),Vector2(126,126)))
	var grit: Array[Vector2] = []
	for i in range(6): grit.append(Vector2(rng.randf_range(10,118),rng.randf_range(10,118)))
	var data := {"region":region,"shade":rng.randf_range(0.86,1.04),"turn":rng.randi_range(0,3),"variant":rng.randi_range(0,7),"center":center,"patch":patch,"grit":grit,"phase":rng.randf_range(0,TAU)}
	if cache.size()>=CACHE_LIMIT: cache.erase(cache.keys()[0])
	cache[key] = data
	return data

func ground(canvas: CanvasItem, cell: Vector2i, region: int, seed_value: int, road: bool, detail: bool) -> void:
	if not detail: return
	var data := cell_data(cell,region,seed_value)
	var palette: Dictionary = PALETTES[region]
	var p := Vector2(cell)*CELL
	var points := PackedVector2Array()
	for point in data.patch: points.append(p+point)
	canvas.draw_colored_polygon(points,Color(palette.patch,0.22 if region==2 else 0.16))
	var center: Vector2 = p+data.center
	match region:
		0: # Oil stains, scorched impacts and broken production-line markings.
			if int(data.variant)%3==0:
				ellipse(canvas,center,Vector2(21,12),Color("1e2629"),0.38)
				canvas.draw_arc(center,13,0.3,2.7,12,Color(0.7,0.57,0.4,0.26),2,true)
			elif not road:
				for i in range(3):
					var a := p+Vector2(18+i*10,99)
					canvas.draw_line(a,a+Vector2(8,-12),Color(palette.edge,0.27),4,true)
		1: # Crystalline seams and frost catching the cool light.
			var seam := PackedVector2Array([p+Vector2(12,36),center,center+Vector2(12,22),p+Vector2(108,110)])
			canvas.draw_polyline(seam,Color(palette.edge,0.22),2,true)
			canvas.draw_line(center,center+Vector2(-18,24),Color(palette.edge,0.18),1,true)
			if not road and int(data.variant)%2==0:
				canvas.draw_line(p+Vector2(8,114),p+Vector2(110,114),Color("1c3945"),7,true)
				canvas.draw_line(p+Vector2(8,112),p+Vector2(110,112),Color(palette.light,0.22),2,true)
		2: # Long wind-shaped ripples, rather than a regular second tile grid.
			for row in range(3):
				var ripple := PackedVector2Array()
				for i in range(7): ripple.append(p+Vector2(9+i*17,30+row*22+sin(i*0.7+float(data.phase))*7))
				canvas.draw_polyline(ripple,Color(palette.edge,0.18 if road else 0.28),2,true)
		3: # Deck access covers and cable runs.
			if not road and int(data.variant)%2==0:
				canvas.draw_rect(Rect2(p+Vector2(19,22),Vector2(82,62)),Color(palette.patch,0.2))
				canvas.draw_rect(Rect2(p+Vector2(19,22),Vector2(82,62)),Color(palette.edge,0.18),false,2)
				for i in range(3): canvas.draw_line(p+Vector2(25,32+i*7),p+Vector2(53,32+i*7),Color(palette.edge,0.25),2)
			else: canvas.draw_line(p+Vector2(16,20),p+Vector2(16,111),Color(palette.light,0.16),2)
	for i in range(data.grit.size()):
		var at: Vector2 = p+data.grit[i]
		canvas.draw_line(at,at+Vector2(2+i%3,1),Color(palette.edge,0.22),1.5,true)

static func ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color, opacity: float) -> void:
	var points := PackedVector2Array()
	for i in range(20): points.append(center+Vector2(cos(i*TAU/20.0)*radii.x,sin(i*TAU/20.0)*radii.y))
	canvas.draw_colored_polygon(points,Color(color,opacity))

func road_edge(canvas: CanvasItem, cell: Vector2i, region: int, vertical: bool, horizontal: bool, detail: bool) -> void:
	if not detail or vertical==horizontal: return
	var p := Vector2(cell)*CELL
	var color: Color = PALETTES[region].light
	for side in [-1,1]:
		var center := p+(Vector2(64+side*48,64) if vertical else Vector2(64,64+side*48))
		var extent := Vector2(3,13) if vertical else Vector2(13,3)
		canvas.draw_rect(Rect2(center-extent*1.8,extent*3.6),Color(color,0.035))
		canvas.draw_rect(Rect2(center-extent,extent*2),Color(color,0.32))

func foundation(canvas: CanvasItem, cell: Vector2i, region: int, detail: bool) -> void:
	var p := Vector2(cell)*CELL
	var base := Rect2(p+Vector2(5,12),Vector2(118,110))
	canvas.draw_colored_polygon(PackedVector2Array([base.position+Vector2(18,10),base.position+Vector2(103,0),base.end+Vector2(26,20),base.position+Vector2(34,126)]),Color(0.015,0.025,0.035,0.31))
	canvas.draw_rect(base,Color("263139"))
	canvas.draw_rect(base.grow(-2),Color(PALETTES[region].edge,0.35),false,2)
	if detail:
		for i in range(5):
			var at := p+Vector2(14+i*20,119)
			canvas.draw_line(at,at+Vector2(7,-8),Color(PALETTES[region].edge,0.45),4,true)

func obstacle_details(canvas: CanvasItem, cell: Vector2i, region: int, seed_value: int, elapsed: float, detail: bool) -> void:
	if not detail: return
	var p := Vector2(cell)*CELL
	var data := cell_data(cell,region,seed_value)
	var light_color: Color = PALETTES[region].light
	for side in [12,113]:
		canvas.draw_rect(Rect2(p+Vector2(side-3,99),Vector2(8,12)),Color("15232a"))
		canvas.draw_rect(Rect2(p+Vector2(side,100),Vector2(3,7)),Color(light_color,0.68+sin(elapsed*0.8+float(data.phase))*0.10))
	if region==1:
		for i in range(3):
			var drift := fmod(elapsed*5+i*13+float(data.phase)*4,44.0)
			ellipse(canvas,p+Vector2(90-drift*0.4,65-drift),Vector2(15+drift*0.4,5+drift*0.15),PALETTES[region].air,0.055*(1-drift/44))
	elif region==3 and int(data.variant)==0:
		var glow := 0.15+maxf(0,sin(elapsed*1.4+float(data.phase)))*0.22
		canvas.draw_polyline(PackedVector2Array([p+Vector2(25,102),p+Vector2(35,94),p+Vector2(31,103),p+Vector2(45,99)]),Color(light_color,glow),1.5,true)

func apron(canvas: CanvasItem, center: Vector2, kind: String, region: int, font: Font) -> void:
	var landing := kind=="landing"
	var boss := kind=="boss_site"
	var extent := Vector2(186,134) if landing else Vector2(152,112) if boss else Vector2(66,49)
	var outline := PackedVector2Array()
	for point in [Vector2(-1,-0.7),Vector2(-0.8,-1),Vector2(0.8,-1),Vector2(1,-0.7),Vector2(1,0.7),Vector2(0.8,1),Vector2(-0.8,1),Vector2(-1,0.7)]: outline.append(center+point*extent)
	canvas.draw_colored_polygon(outline,Color(0.055,0.095,0.12,0.72 if landing else 0.35))
	outline.append(outline[0]); canvas.draw_polyline(outline,Color(PALETTES[region].edge,0.48),3,true)
	for side in [-1,1]:
		var x: float = center.x+side*(extent.x-12)
		canvas.draw_line(Vector2(x,center.y-extent.y*0.5),Vector2(x,center.y+extent.y*0.5),Color(PALETTES[region].light,0.55),4,true)
	if landing:
		canvas.draw_line(center-Vector2(78,0),center+Vector2(78,0),Color("667f86"),11,true)
		for side in [-1,1]: canvas.draw_line(center+Vector2(side*78,-45),center+Vector2(side*78,45),Color("667f86"),11,true)
		canvas.draw_string(font,center+Vector2(-62,100),"ARK  /  07",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("889b99"))
		for side in [-1,1]:
			for i in range(4):
				var at := center+Vector2(side*(90+i*18),-112)
				canvas.draw_line(at,at+Vector2(8,12),Color(PALETTES[region].edge,0.65),5,true)
	elif boss:
		for side in [-1,1]:
			for i in range(6): canvas.draw_line(center+Vector2(-85+i*30,side*96),center+Vector2(-72+i*30,side*96),Color(PALETTES[region].edge,0.38),4,true)

func air(canvas: CanvasItem, view: Rect2, region: int, elapsed: float, known: Callable) -> void:
	# Fixed world cells prevent the dust from sliding with the camera. At most 48 wisps.
	var low := Vector2i((view.position/256).floor())
	var high := Vector2i((view.end/256).floor())
	var count := 0
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			if count>=48: return
			var hash_value := absi(x*73856093 ^ y*19349663)
			if hash_value%3!=0: continue
			var at := Vector2(x,y)*256+Vector2(fposmod(hash_value*0.17+elapsed*(9 if region==2 else 3),256),fposmod(hash_value*0.31-elapsed*2,256))
			if not known.call(at): continue
			count+=1
			var color: Color = PALETTES[region].air
			var wide := 64.0 if region==2 else 38.0
			ellipse(canvas,at,Vector2(wide,10),color,0.025)
			ellipse(canvas,at+Vector2(12,-3),Vector2(wide*0.6,5),color,0.025)
			for i in range(2):
				var mote := at+Vector2(i*23,sin(elapsed*0.5+x+i)*12)
				canvas.draw_line(mote,mote+Vector2(3,-1),Color(color,0.24),1,true)

func fog(canvas: CanvasItem, low: Vector2i, high: Vector2i, known: Callable) -> void:
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell := Vector2i(x,y)
			var origin := Vector2(cell)*CELL
			if known.call(origin+Vector2.ONE*64): continue
			canvas.draw_rect(Rect2(origin,Vector2.ONE*CELL),Color("0a151e"))
			# Generic survey marks carry no information about hidden terrain or locations.
			if posmod(x,2)==0 and posmod(y,2)==0:
				var center := origin+Vector2.ONE*64
				canvas.draw_line(center-Vector2(4,0),center+Vector2(4,0),Color("172733"),1)
				canvas.draw_line(center-Vector2(0,4),center+Vector2(0,4),Color("172733"),1)
	# Feather inward into explored tiles, never disclose imagery in unknown cells.
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var origin := Vector2(x,y)*CELL
			if not known.call(origin+Vector2.ONE*64): continue
			for side in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				if known.call(origin+Vector2.ONE*64+side*CELL): continue
				for i in range(4):
					var start := origin+Vector2(0 if side.x<0 else CELL-4-i*4 if side.x>0 else 0,0 if side.y<0 else CELL-4-i*4 if side.y>0 else 0)
					if side.x<0: start.x+=i*4
					if side.y<0: start.y+=i*4
					canvas.draw_rect(Rect2(start,Vector2(4,CELL) if side.x!=0 else Vector2(CELL,4)),Color(0.039,0.082,0.118,0.68-i*0.16))
