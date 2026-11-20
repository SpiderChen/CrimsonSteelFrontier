extends RefCounted
## A persistent free-roaming sortie. Locations are revealed only by the physical mech.
const DATA = preload("res://scripts/region_data.gd")
var clears: Array = [0,0,0,0]
var samples: Array = [0,0,0,0]
var sequence: int = 0
var run: Dictionary = {}
var report: Dictionary = {}
var locations: Array = []
var legacy_return: Dictionary = {}

func active() -> bool: return not run.is_empty()
func layout_version() -> int: return int(run.get("layout",1)) if active() else DATA.CURRENT_LAYOUT
func bounds() -> Rect2: return DATA.map_bounds(layout_version())
func fog_bounds() -> Rect2i: return DATA.layout_fog_bounds(layout_version())
func unlocked(region: int) -> bool:
	if region<0 or region>=4: return false
	for previous in range(region):
		if int(clears[previous])<=0: return false
	return true
func blueprint_unlocked(blueprint: int) -> bool: return blueprint>=17 and blueprint<=20 and unlocked(blueprint-17) and int(clears[blueprint-17])>0

func begin(world: Node, region: int, focus: int = -1) -> bool:
	if active() or not world.docked or not unlocked(region): return false
	if focus!=-1 and focus not in DATA.REGIONS[region].pool: return false
	if State.recovery>0 or not State.mech_configuration().valid: return false
	var overworld: Dictionary = world.export_save().duplicate(true)
	if not world.launch(): return false
	sequence += 1
	run = {"schema":2,"layout":DATA.CURRENT_LAYOUT,"id":sequence,"seed":randi_range(1,100000000),"region":region,"focus":focus,"phase":"explore","alert":0,"bounty":0,"cooling_seconds":0.0,"elapsed":0.0,"secured":[],"used":[],"discovered":[],"visited":{},"overworld":overworld,"support":State.carrier.initial_support()}
	locations = DATA.map_sites(region,int(run.seed),int(run.id),layout_version())
	State.carrier.ops.flashes.clear()
	world.boss.stop(); world.encounter_id = ""
	world.enemy_units.clear(); world.enemy_health.clear(); world.cleared = {}; world.explored = {}
	world.path.clear(); world.path_index = 0; world.steering = Vector2.ZERO
	world.position = DATA.LANDING; world.destination = world.position
	world.patrol = true; world.grace = 0; world.tactical.reset(); world.tactical_path = false
	world.hostile.projectiles.clear(); world.attacks.reset(); State.rig.reset_clocks()
	for site in locations:
		if site.kind!="enemy": continue
		var stats: Dictionary = DATA.enemy(site.role,region,site.elite)
		world.enemy_health[site.id] = {"hp":stats.hp,"max":stats.hp}
	State.energy = 25; State.auto = true
	reveal(world.position)
	State.story_event("launch",region)
	State.save_game(); State.changed.emit(); world.changed.emit()
	return true

func fog_key(point: Vector2) -> String:
	return "%d:%d" % [floori(point.x/DATA.FOG_CELL),floori(point.y/DATA.FOG_CELL)]
func revealed(point: Vector2) -> bool:
	return active() and run.visited.has(fog_key(point))
func known(id: String) -> bool: return active() and id in run.discovered
func location(id: String) -> Dictionary:
	for site in locations:
		if site.id==id: return site
	return {}
func boss_site() -> Dictionary:
	return locations[0] if not locations.is_empty() else {}
func boss_discovered() -> bool:
	return active() and not locations.is_empty() and known(locations[0].id)
func sites() -> Array:
	return locations.filter(func(site): return known(site.id)) if active() else []
func explored_percent() -> int:
	return mini(100,int(run.visited.size()*100.0/fog_bounds().get_area())) if active() else 0

func reveal(point: Vector2) -> void:
	if not active(): return
	var cell := Vector2i(floori(point.x/DATA.FOG_CELL),floori(point.y/DATA.FOG_CELL))
	for y in range(cell.y-2,cell.y+3):
		for x in range(cell.x-2,cell.x+3):
			var center := Vector2(x,y)*DATA.FOG_CELL+Vector2.ONE*DATA.FOG_CELL/2.0
			if bounds().has_point(center) and point.distance_to(center)<=DATA.VISION: run.visited[fog_key(center)] = true
	for site in locations:
		if point.distance_to(site.p)>DATA.VISION or known(site.id): continue
		run.discovered.append(site.id); run.visited[fog_key(site.p)] = true
		if site.kind!="enemy": State.field_effect.emit("discover",site.p,Vector2.ZERO)
		if site.kind=="boss_site":
			State.message.emit("发现大型机体 · 靠近后可自主挑战首领")
			State.story_event("discovery")

func advance(world: Node, delta: float) -> void:
	if not active() or world.docked: return
	run.elapsed += delta
	run.cooling_seconds = maxf(0,float(run.cooling_seconds)-delta)
	reveal(world.position)

func nearest_interaction(world: Node) -> Dictionary:
	if not active() or world.docked or run.phase!="explore": return {}
	var result: Dictionary = {}
	for site in sites():
		if site.kind=="enemy" or site.id in run.used: continue
		var distance: float = world.position.distance_to(site.p)
		if distance>(240 if site.kind=="boss_site" else 115): continue
		if result.is_empty() or distance<world.position.distance_to(result.p): result = site
	return result

func can_interact(world: Node, id: String) -> bool:
	if not active() or world.docked or State.recovery>0 or run.phase!="explore" or not known(id) or id in run.used: return false
	var site := location(id)
	return not site.is_empty() and site.kind!="enemy" and world.position.distance_to(site.p)<=(240 if site.kind=="boss_site" else 115)

func options(id: String) -> Array:
	var site := location(id)
	if site.is_empty(): return []
	match site.kind:
		"cache": return ["回收样本 · 样本 +1","开启武器库 · 定向稀有 / 警戒 +1"]
		"cooling": return ["回收设施 · 赏金 +50","接入冷却 · 90秒散热 +40% / 移速 -20%"]
		"supply": return ["维修机体 · 装甲 +40 / 排热50" if State.selected==2 else "维修机体 · 装甲 +30 / 排热60" if State.selected==5 else "维修机体 · 装甲 +30 / 排热40","回收物资 · 合金 +12 / 赏金 +80"]
		"boss_site": return ["挑战首领"]
	return []

func interact(world: Node, id: String, option: int, mission: int) -> bool:
	if not active() or int(run.id)!=mission or not can_interact(world,id) or option<0 or option>=options(id).size(): return false
	var site := location(id)
	if site.kind=="boss_site": return start_boss(world,id)
	run.used.append(id); world.cleared[id] = true
	match site.kind:
		"cache":
			if option==0: samples[int(run.region)] += 1
			else:
				State.parts.roll(loot_blueprint(),1,true); run.alert = mini(3,int(run.alert)+1); run.bounty += 100+(40 if State.selected==0 else 60 if State.selected==3 else 0)
				if State.selected in [1,4]: State.parts.research_materials += 1 if State.selected==1 else 2
		"cooling":
			if option==0: run.bounty += 50
			else: run.cooling_seconds = 90.0
		"supply":
			if option==0: State.defense.heal(40 if State.selected==2 else 30); State.rig.heat = maxf(0,State.rig.heat-(50 if State.selected==2 else 60 if State.selected==5 else 40))
			else: State.cores += 12; run.bounty += 80
	State.record_pilot("nodes",1)
	if site.kind=="supply" and option==0:
		State.field_effect.emit("repair",world.position,Vector2.ZERO)
		State.field_effect.emit("vent",world.position,Vector2.ZERO)
	elif site.kind=="cooling" and option==1: State.field_effect.emit("vent",site.p,Vector2.ZERO)
	else: State.field_effect.emit("loot",site.p,world.position)
	State.story_event("facility")
	State.message.emit(site.name+" · 已完成回收")
	State.changed.emit(); State.save_game(); world.changed.emit()
	return true

func start_boss(world: Node, id: String) -> bool:
	if not can_interact(world,id) or location(id).kind!="boss_site": return false
	run.phase = "boss"
	world.drop_target(); world.path.clear(); world.path_index = 0; world.destination = world.position
	world.tactical.reset(); world.tactical_path = false
	world.attacks.reset(); world.hostile.projectiles.clear(); State.rig.reset_clocks()
	world.boss.start(int(run.region),int(run.alert),location(id).p)
	world.encounter_id = world.boss.BODY; world.encounter_position = world.boss.target_position()
	State.enemy_hp = world.boss.hp; State.enemy_max = world.boss.maximum
	world.patrol = true
	State.story_event("boss",int(run.region))
	State.save_game(); State.changed.emit(); world.changed.emit()
	return true

func check_clear(world: Node) -> void:
	if not active(): return
	var changed := false
	for site in locations:
		if site.kind!="enemy" or not world.cleared.has(site.id) or site.id in run.secured: continue
		run.secured.append(site.id); samples[int(run.region)] += 1
		changed = true
		if site.elite:
			State.parts.roll(loot_blueprint(),1,true); State.record_pilot("nodes",1)
			State.message.emit("精英击破 · 定向稀有部件与样本已入库")
	if changed: State.save_game()

func loot_blueprint() -> int:
	return int(run.focus) if int(run.focus)>=0 else DATA.REGIONS[int(run.region)].pool.pick_random()
func reward_enemy() -> void:
	var region: int = run.region
	State.credits += 30+region*15; State.cores += 1; State.wins += 1; State.stage += 1
	run.bounty += 40+region*20
	if randf()<0.2: State.parts.roll(DATA.REGIONS[region].pool.pick_random(),-1,true)
func register_clear(region: int) -> bool:
	if not unlocked(region): return false
	var first: bool = int(clears[region])==0
	clears[region] = int(clears[region])+1; samples[region] += 8+(8 if first else 0)
	return first
func complete_boss(world: Node) -> void:
	if not active() or run.phase!="boss": return
	check_clear(world)
	var region: int = run.region
	State.record_pilot("bosses",1)
	var first := register_clear(region)
	State.credits += 900+region*200; State.cores += 30+region*5; State.gems += 200 if first else 100; State.wins += 1
	State.parts.roll(int(DATA.REGIONS[region].blueprint) if first else loot_blueprint(),2,true)
	finish(world,"cleared",true,true)
	State.message.emit(DATA.REGIONS[region].name+"首通 · 新区域与命名蓝图已解锁" if first else DATA.REGIONS[region].name+"首领击破 · 样本与定向史诗已入库")
func finish(world: Node, outcome: String, settle: bool, repair: bool) -> void:
	if not active(): return
	check_clear(world)
	var bounty: int = run.bounty
	if settle: State.credits += bounty
	report = {"region":run.region,"outcome":outcome,"bounty":bounty if settle else 0,"lost":0 if settle else bounty,"elapsed":run.elapsed,"discovered":run.discovered.size(),"secured":run.secured.size(),"explored":explored_percent()}
	report.carrier = {}
	report.id = int(run.id)
	for key in ["shots","damage","prevented","repaired","deployments"]: report.carrier[key] = run.support.ops[key]
	var overworld: Dictionary = run.overworld.duplicate(true)
	var boss_save: Dictionary = world.boss.export_save(); boss_save.active = false
	overworld.boss = boss_save; overworld.docked = true
	run.clear(); locations.clear()
	world.import_save(overworld); world.enter_base(repair)
	State.narrative.mark("return")
	State.story_event("clear" if outcome=="cleared" else "failed" if outcome=="failed" else "return",int(report.region))
	State.save_game()
func withdraw(world: Node) -> bool:
	if not active(): return false
	finish(world,"withdrawn",true,true)
	State.message.emit("已回母舰 · 赏金已结算，装备与样本保留")
	return true
func cooling_factor() -> float:
	return float(DATA.REGIONS[int(run.region)].cooling)*(1.4 if float(run.cooling_seconds)>0 else 1.0) if active() else 1.0
func speed_factor() -> float:
	return float(DATA.REGIONS[int(run.region)].speed)*(0.8 if float(run.cooling_seconds)>0 else 1.0) if active() else 1.0
func exchange(region: int, blueprint: int, named: bool) -> bool:
	if not unlocked(region) or not World.docked: return false
	var cost := 20 if named else 12
	if named and not blueprint_unlocked(blueprint): return false
	if (named and blueprint!=DATA.REGIONS[region].blueprint) or (not named and blueprint not in DATA.REGIONS[region].pool) or int(samples[region])<cost: return false
	samples[region] -= cost; State.parts.roll(blueprint,2 if named else 1,true)
	State.message.emit("区域样本兑换成功 · 满仓时部件保存在溢出仓")
	State.changed.emit(); State.save_game()
	return true
func export_save() -> Dictionary:
	return {"clears":clears.duplicate(),"samples":samples.duplicate(),"sequence":sequence,"run":run.duplicate(true),"report":report.duplicate(true)}
func integer(value: Variant, fallback: int, low: int, high: int) -> int:
	return clampi(int(value),low,high) if (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) else fallback
func valid_index(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
func finite_number(value: Variant, fallback: float, low: float, high: float) -> float:
	return clampf(float(value),low,high) if (value is float or value is int) and is_finite(float(value)) else fallback
func import_save(data: Variant) -> void:
	clears = [0,0,0,0]; samples = [0,0,0,0]; run.clear(); locations.clear(); report.clear(); legacy_return.clear(); sequence = 0
	if not data is Dictionary: return
	for key in ["clears","samples"]:
		var values = data.get(key,[])
		if values is Array and values.size()==4:
			for i in range(4):
				if key=="clears": clears[i] = integer(values[i],0,0,1000000)
				else: samples[i] = integer(values[i],0,0,1000000000)
	sequence = integer(data.get("sequence"),0,0,100000000)
	var result = data.get("report",{})
	if result is Dictionary and result.get("outcome") in ["cleared","withdrawn","failed"] and valid_index(result.get("region"),0,3):
		report = {"region":int(result.region),"outcome":result.outcome,"bounty":integer(result.get("bounty"),0,0,10000000),"lost":integer(result.get("lost"),0,0,10000000),"elapsed":finite_number(result.get("elapsed"),0,0,1000000),"discovered":integer(result.get("discovered"),0,0,DATA.MAX_LOCATIONS),"secured":integer(result.get("secured"),0,0,DATA.MAX_LOCATIONS),"explored":integer(result.get("explored"),0,0,100)}
		if result.get("carrier") is Dictionary:
			report.carrier = {}
			report.id = integer(result.get("id"),0,0,100000000)
			for key in ["shots","damage","prevented","repaired","deployments"]: report.carrier[key] = finite_number(result.carrier.get(key),0,0,1000000000)
	var raw = data.get("run",{})
	if not raw is Dictionary or raw.is_empty() or not valid_index(raw.get("region"),0,3) or not unlocked(int(raw.region)) or not raw.get("overworld") is Dictionary: return
	if raw.get("schema")!=2:
		# Removed linear sorties return to port with their already earned bounty.
		if not valid_index(raw.get("route"),0,1) or not valid_index(raw.get("step"),0,5): return
		legacy_return = {"overworld":raw.overworld.duplicate(true),"bounty":integer(raw.get("bounty"),0,0,10000000)}
		report = {"region":int(raw.region),"outcome":"withdrawn","bounty":legacy_return.bounty,"lost":0,"elapsed":finite_number(raw.get("elapsed"),0,0,1000000),"discovered":0,"secured":0,"explored":0}
		return
	if not valid_index(raw.get("id"),1,100000000) or not valid_index(raw.get("seed"),1,100000000) or raw.get("phase") not in ["explore","boss"]: return
	var region: int = raw.region
	var focus := integer(raw.get("focus"),-1,-1,100)
	if focus!=-1 and focus not in DATA.REGIONS[region].pool: return
	run = {"schema":2,"layout":integer(raw.get("layout"),1,1,DATA.CURRENT_LAYOUT),"id":int(raw.id),"seed":int(raw.seed),"region":region,"focus":focus,"phase":raw.phase,"alert":integer(raw.get("alert"),0,0,3),"bounty":integer(raw.get("bounty"),0,0,10000000),"cooling_seconds":finite_number(raw.get("cooling_seconds"),0,0,90),"elapsed":finite_number(raw.get("elapsed"),0,0,1000000),"secured":[],"used":[],"discovered":[],"visited":{},"overworld":raw.overworld.duplicate(true)}
	locations = DATA.map_sites(region,int(run.seed),int(run.id),layout_version()); sequence = maxi(sequence,int(run.id))
	for key in ["secured","used","discovered"]:
		var entries = raw.get(key,[])
		if not entries is Array: continue
		for id in entries.slice(0,locations.size()):
			if not id is String or id in run[key]: continue
			var site := location(id)
			if site.is_empty() or (key=="secured" and site.kind!="enemy") or (key=="used" and site.kind in ["enemy","boss_site"]): continue
			run[key].append(id)
	var cells = raw.get("visited",{})
	if cells is Dictionary:
		for y in range(fog_bounds().position.y,fog_bounds().end.y):
			for x in range(fog_bounds().position.x,fog_bounds().end.x):
				var key := "%d:%d" % [x,y]
				if cells.get(key)==true: run.visited[key] = true
	if run.phase=="boss" and not boss_discovered(): run.phase = "explore"
	run.support = State.carrier.import_support(raw.get("support"),int(run.id))
