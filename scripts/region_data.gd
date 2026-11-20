extends RefCounted
const REGIONS = [
	{"name":"赤锈军工区","theme":"生产线、重装守卫与装甲回收场","pool":[0,1,4,8,22,23,24],"blueprint":17,"boss":"掘墓者·矿战平台","color":"624432","cooling":1.0,"speed":1.0,"condition":"标准战区","roles":["guard","cannon"]},
	{"name":"白噪冷却站","theme":"冷却管线、能量设施与试验反应炉","pool":[15,3,5,10,12,21],"blueprint":18,"boss":"白噪·冷却卫士","color":"254454","cooling":1.2,"speed":0.95,"condition":"冷却管网：散热+20%，移速-5%","roles":["cannon","rusher"]},
	{"name":"沙海试验场","theme":"开阔沙地、移动平台与推进试验区","pool":[16,6,7,13,22],"blueprint":19,"boss":"沙海·追猎平台","color":"655038","cooling":0.9,"speed":1.1,"condition":"高温疾风：散热-10%，移速+10%","roles":["rusher","guard"]},
	{"name":"坠落轨道港","theme":"舰体残骸、无人哨戒与电能回收区","pool":[1,2,9,10,14,21,23],"blueprint":20,"boss":"轨道·回收主机","color":"283246","cooling":1.0,"speed":1.0,"condition":"装甲哨戒：注意敌军伤害抗性","roles":["cannon","rusher"]}
]
const ARENA := Vector2(1536,384)
const LEGACY_MAP_HALF := Vector2(1792,1408)
const MAP_HALF := Vector2(3584,2816)
const MAP_CENTER := ARENA+Vector2(1792,-1408)
const CURRENT_LAYOUT: int = 2
const MAX_LOCATIONS: int = 160
const EXPANDED_LAIRS = [Vector2(640,-3072),Vector2(6144,-3072),Vector2(6144,1024),Vector2(3328,-3200)]
const LANDING := ARENA+Vector2(-1344,1216)
const VISION: float = 448.0
const FOG_CELL: int = 256

static func map_bounds(layout: int = CURRENT_LAYOUT) -> Rect2:
	return Rect2(ARENA-LEGACY_MAP_HALF,LEGACY_MAP_HALF*2) if layout==1 else Rect2(MAP_CENTER-MAP_HALF,MAP_HALF*2)

static func layout_fog_bounds(layout: int = CURRENT_LAYOUT) -> Rect2i:
	var bounds := map_bounds(layout)
	return Rect2i(Vector2i(bounds.position/FOG_CELL),Vector2i(bounds.size/FOG_CELL))

static func map_sites(region: int, map_seed: int, ident: int, layout: int = CURRENT_LAYOUT) -> Array:
	var result := legacy_map_sites(region,map_seed,ident)
	if layout==1: return result
	# The original landing neighborhood stays familiar; new sectors extend north/east.
	var rng := RandomNumberGenerator.new(); rng.seed = map_seed ^ 94217
	var lair: Vector2 = EXPANDED_LAIRS[rng.randi_range(0,EXPANDED_LAIRS.size()-1)]
	result[0].p = lair
	var sectors: Array[Vector2] = []
	for y in [-3328,-2432,-1536]:
		for x in [256,1152,2048,2944,3840,4736,5632,6528]: sectors.append(Vector2(x,y))
	for y in [-640,256,1152]:
		for x in [3840,4736,5632,6528]: sectors.append(Vector2(x,y))
	for i in range(sectors.size()):
		var center: Vector2 = sectors[i]+Vector2(rng.randi_range(-1,1),rng.randi_range(-1,1))*64
		if center.distance_to(lair)<700: continue
		for j in range(2):
			var role: String = REGIONS[region].roles[(i+j)%2]
			result.append({"id":"map:%d:enemy:outer:%d:%d"%[ident,i,j],"kind":"enemy","p":center+Vector2(j*90,0),"role":role,"region":region,"elite":i%9==6 and j==0,"name":{"guard":"装甲守卫","rusher":"突击机兵","cannon":"远程炮台"}[role]})
		if i%2!=0: continue
		var point: Vector2 = sectors[i]+Vector2(-192,256)
		if point.distance_to(lair)<700: continue
		var kind: String = ["supply","cache","cooling"][(i/2)%3]
		result.append({"id":"map:%d:poi:outer:%d"%[ident,i],"kind":kind,"p":point,"name":{"cache":"封存武器库","supply":"补给残骸","cooling":"冷却设施"}[kind]})
	return result

static func legacy_map_sites(region: int, map_seed: int, ident: int) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = map_seed
	var lairs := [Vector2(1216,-1088),Vector2(1216,704),Vector2(-960,-1088)]
	var lair: Vector2 = ARENA+lairs[rng.randi_range(0,lairs.size()-1)]
	var result: Array = [{"id":"map:%d:boss" % ident,"kind":"boss_site","p":lair,"name":"未知大型机体"}]
	var camps := [Vector2(-1024,768),Vector2(-448,896),Vector2(384,960),Vector2(1152,256),Vector2(1024,-512),Vector2(256,-960),Vector2(-640,-896),Vector2(-1152,-128),Vector2(-256,128),Vector2(448,-256)]
	for i in range(camps.size()):
		var center: Vector2 = ARENA+camps[i]+Vector2(rng.randi_range(-1,1),rng.randi_range(-1,1))*64
		if center.distance_to(lair)<620: continue
		for j in range(2):
			var role: String = REGIONS[region].roles[(i+j)%2]
			result.append({"id":"map:%d:enemy:%d:%d" % [ident,i,j],"kind":"enemy","p":center+Vector2(j*90,0),"role":role,"region":region,"elite":i in [3,7] and j==0,"name":{ "guard":"装甲守卫","rusher":"突击机兵","cannon":"远程炮台"}[role]})
	var supplies := [Vector2(-1088,1088),Vector2(64,832),Vector2(-1088,-576),Vector2(768,-960),Vector2(960,960),Vector2(-320,-448)]
	for i in range(supplies.size()):
		var kind: String = ["supply","cache","cooling","supply","cache","cooling"][i]
		result.append({"id":"map:%d:poi:%d" % [ident,i],"kind":kind,"p":ARENA+supplies[i],"name":{"cache":"封存武器库","supply":"补给残骸","cooling":"冷却设施"}[kind]})
	return result

static func map_obstacle(cell: Vector2i, region: int, map_seed: int, sites: Array, layout: int = CURRENT_LAYOUT) -> bool:
	var point := Vector2(cell)*128+Vector2.ONE*64
	if not map_bounds(layout).has_point(point): return true
	if point.distance_to(LANDING)<260: return false
	for site in sites:
		if point.distance_to(site.p)<(620 if site.kind=="boss_site" else 170): return false
	# Crossing roads keep every sector connected while each map has distinct ruins.
	if posmod(cell.x,4)==0 or posmod(cell.y,4)==0: return false
	return absi(cell.x*73856093 ^ cell.y*19349663 ^ map_seed ^ region*83492791)%11>=8

static func enemy(role: String, region: int, elite: bool) -> Dictionary:
	var valid_region := clampi(region,0,3)
	var stats: Dictionary = {
		"guard":{"speed":176.0,"stop":170.0,"range":230.0,"interval":1.2,"hp":150.0,"damage":6,"resistances":{"kinetic":10.0}},
		"rusher":{"speed":210.0,"stop":105.0,"range":180.0,"interval":0.9,"hp":115.0,"damage":5,"resistances":{"thermal":-10.0}},
		"cannon":{"speed":115.0,"stop":240.0,"range":310.0,"interval":1.8,"hp":175.0,"damage":9,"resistances":{"electric":-15.0}}
	}.get(role,{}).duplicate(true)
	if stats.is_empty(): return {}
	stats.hp *= (1+valid_region*0.45)*(1.6 if elite else 1.0)
	stats.damage = ceili((float(stats.damage)+valid_region*2)*(1.35 if elite else 1.0))
	if elite: stats.resistances.kinetic = float(stats.resistances.get("kinetic",0))+15
	return stats
