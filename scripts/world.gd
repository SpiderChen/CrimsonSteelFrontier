extends Node
## Deterministic streamed overworld. Only queried chunks are cached, never the entire map.
const BOSS_ENCOUNTER = preload("res://scripts/boss_encounter.gd")
var boss = BOSS_ENCOUNTER.new()
var combatant: Node = null
var certification_region: int = -1
var certification_foes: Array = []
const REGION_DATA = preload("res://scripts/region_data.gd")

func combat_state() -> Node:
	return combatant if is_instance_valid(combatant) else State

signal base_entered
signal changed
signal enemy_fired(from: Vector2, damage: int)
const HOSTILE_ATTACKS = preload("res://scripts/hostile_attacks.gd")
var hostile = HOSTILE_ATTACKS.new()
const ATTACK_SYSTEM = preload("res://scripts/attack_system.gd")
var attacks = ATTACK_SYSTEM.new()
const TACTICS = preload("res://scripts/tactics.gd")
var tactical = TACTICS.new()
var tactical_path: bool = false
const ENEMY_BRAIN = preload("res://scripts/enemy_ai.gd")
const EXTENT: float = 32768.0
const CHUNK: int = 512
const CELL: int = 128
const START := Vector2(384,384)
const ACQUIRE_RANGE: float = 270.0
const ATTACK_RANGE: float = 300.0
const RELEASE_RANGE: float = 420.0
const ENEMY_RANGE: float = 230.0
var docked: bool = false
var enabled: bool = true
var position := START
var destination := START
var steering := Vector2.ZERO
var path := PackedVector2Array()
var path_index: int = 0
var patrol: bool = false
var encounter_id: String = ""
var encounter_position := Vector2.ZERO
var enemy_health: Dictionary = {}
var enemy_units: Dictionary = {}
var brain = ENEMY_BRAIN.new()
var alerts: int = 0
var enemy_shots: int = 0
var chase_distance: float = 0
var returns_completed: int = 0
var drive_clock: float = 0
var blocked_cells: Array[Vector2i] = []
var movement_blocked: bool = false
var actual_velocity := Vector2.ZERO
var shots_fired: int = 0
var moving_shots: int = 0
var cleared: Dictionary = {}
var explored: Dictionary = {}
var cache: Dictionary = {}
var grace: float = 0
var patrol_clock: float = 0
var distance_travelled: float = 0
var noise := FastNoiseLite.new()

func _ready() -> void:
	noise.seed = 19737
	noise.frequency = 0.00072
	import_save(combat_state().world_save)
	combat_state().shot.connect(record_shot)

func record_shot(friendly: bool, _damage: int) -> void:
	if friendly and enabled:
		shots_fired += 1
		if actual_velocity.length()>1: moving_shots += 1

func bounded(p: Vector2) -> Vector2:
	if certification_region>=0: return p.clamp(REGION_DATA.ARENA-Vector2(520,430),REGION_DATA.ARENA+Vector2(520,430))
	if combat_state().expedition.active(): return p.clamp(combat_state().expedition.bounds().position+Vector2.ONE*8,combat_state().expedition.bounds().end-Vector2.ONE*8)
	return p.clamp(Vector2(-EXTENT+CELL,-EXTENT+CELL),Vector2(EXTENT-CELL,EXTENT-CELL))

func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/CELL),floori(p.y/CELL))

func chunk_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/CHUNK),floori(p.y/CHUNK))

func key(c: Vector2i) -> String:
	return "%d:%d" % [c.x,c.y]

func cell_hash(c: Vector2i) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663) ^ 19737)

func biome(p: Vector2) -> int:
	if certification_region>=0: return [0,2,1,0][certification_region]
	if combat_state().expedition.active(): return [0,2,1,0][int(combat_state().expedition.run.region)]
	var n := noise.get_noise_2dv(p)
	return 1 if n > 0.24 else 2 if n < -0.24 else 0

func region_name(p: Vector2) -> String:
	if certification_region>=0: return REGION_DATA.REGIONS[certification_region].name
	if combat_state().expedition.active(): return combat_state().expedition.DATA.REGIONS[int(combat_state().expedition.run.region)].name
	return ["灰烬都市","赤砂荒原","寒霜裂谷"][biome(p)]

func is_obstacle(c: Vector2i) -> bool:
	if certification_region>=0:
		var offset := c-cell_at(REGION_DATA.ARENA)
		return abs(offset.x)>5 or abs(offset.y)>4 or offset in [Vector2i(-2,-2),Vector2i(2,2)]
	if boss.active and not combat_state().expedition.active() and (Vector2(c)*CELL+Vector2.ONE*CELL/2).distance_to(boss.center)<780: return false
	if combat_state().expedition.active():
		var expedition = combat_state().expedition
		return REGION_DATA.map_obstacle(c,int(expedition.run.region),int(expedition.run.seed),expedition.locations,expedition.layout_version())
	var p := Vector2(c)*CELL+Vector2.ONE*CELL/2.0
	if absf(p.x)>EXTENT-CELL or absf(p.y)>EXTENT-CELL: return true
	if p.distance_to(START) < 410: return false
	if posmod(c.x,8)==0 or posmod(c.y,8)==0: return false
	return cell_hash(c) % 11 >= 8

func free_cell(c: Vector2i) -> Vector2i:
	if not is_obstacle(c): return c
	for radius in range(1,5):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var candidate := c+Vector2i(x,y)
				if not is_obstacle(candidate): return candidate
	return c

func sites(c: Vector2i) -> Array:
	if certification_region>=0: return certification_foes.filter(func(site): return chunk_at(site.p)==c)
	if combat_state().expedition.active(): return combat_state().expedition.sites().filter(func(site): return chunk_at(site.p)==c)
	var id := key(c)
	if cache.has(id): return cache[id]
	var result: Array = []
	if c==Vector2i.ZERO:
		result = [
			{"id":"resource:0:0","kind":"resource","p":START+Vector2(190,-30),"name":"合金补给"},
			{"id":"enemy:0:0","kind":"enemy","p":START+Vector2(320,170),"name":"巡逻机兵"},
			{"id":"beacon:0:0","kind":"beacon","p":Vector2(160,220),"name":"前线据点"}
		]
	else:
		for i in range(2):
			var cell := free_cell(c*4+Vector2i(1+i*2,1+int(cell_hash(c+Vector2i(i,0))%3)))
			var p := Vector2(cell)*CELL+Vector2.ONE*CELL/2.0
			if p.distance_to(START)<400: continue
			var kind := "enemy" if i==0 else "beacon" if cell_hash(c)%7==0 else "resource"
			var elite: bool = kind=="enemy" and cell_hash(c)%5==0
			result.append({"id":kind+":"+id,"kind":kind,"p":p,"elite":elite,"name":"重装精英" if elite else "巡逻机兵" if kind=="enemy" else "通讯据点" if kind=="beacon" else "物资残骸"})
	if cache.size()>=128: cache.erase(cache.keys()[0])
	cache[id] = result
	return result

func nearby(p: Vector2, radius: int = 2) -> Array:
	if certification_region>=0: return certification_foes
	if boss.active:
		var sites: Array = []
		for target in boss.targets(): sites.append({"id":target.id,"kind":"enemy","p":target.p,"name":"掘墓者"})
		return sites
	if combat_state().expedition.active(): return combat_state().expedition.sites().filter(func(site): return p.distance_to(site.p)<=CHUNK*(radius+1))
	var out: Array = []
	var center := chunk_at(p)
	for y in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			out.append_array(sites(center+Vector2i(x,y)))
	var known: Dictionary = {}
	for site in out: known[site.id] = true
	for id in enemy_units:
		if not known.has(id):
			out.append({"id":id,"kind":"enemy","p":enemy_units[id].home,"name":enemy_units[id].name})
	return out

func site_position(site: Dictionary) -> Vector2:
	if site.kind=="enemy" and enemy_units.has(site.id): return enemy_units[site.id].p
	return site.p

func enemy_mode(id: String) -> String:
	return enemy_units[id].mode if enemy_units.has(id) else "guard"

func threat_count() -> int:
	var count := 0
	for unit in enemy_units.values():
		if unit.mode=="chase" or unit.mode=="attack": count += 1
	return count

func line_clear(a: Vector2,b: Vector2) -> bool:
	var steps := maxi(1,ceili(a.distance_to(b)/28.0))
	for i in range(1,steps):
		if is_obstacle(cell_at(a.lerp(b,float(i)/steps))): return false
	return true

func on_player_down() -> void:
	enter_base(false)

func enter_base(repair: bool = true) -> void:
	if combat_state().expedition.active():
		combat_state().expedition.finish(self,"withdrawn" if repair else "failed",repair,repair)
		return
	boss.stop()
	drop_target()
	for unit in enemy_units.values(): brain.set_mode(unit,"return")
	attacks.reset()
	tactical.reset(); tactical_path = false
	hostile.projectiles.clear()
	combat_state().defense.configure(combat_state().equipment_stats(),true)
	position = START
	destination = START
	path.clear()
	path_index = 0
	steering = Vector2.ZERO
	actual_velocity = Vector2.ZERO
	blocked_cells.clear()
	movement_blocked = false
	patrol = false
	drive_clock = 0
	docked = true
	grace = 8
	combat_state().rig.reset_clocks()
	combat_state().rig.heat = 0
	combat_state().rig.overheated = false
	combat_state().rig.cooling_hold = false
	if repair and combat_state().recovery<=0: combat_state().hp = 100
	base_entered.emit()
	changed.emit()
	combat_state().save_game()

func begin_boss() -> bool:
	if not docked or not launch(): return false
	boss.start()
	position = boss.CENTER-Vector2(260,0)
	destination = position
	encounter_id = boss.BODY
	encounter_position = boss.target_position()
	combat_state().enemy_hp = boss.hp; combat_state().enemy_max = boss.maximum
	combat_state().energy = 25
	combat_state().auto = true; combat_state().auto_skill = true
	patrol = true
	grace = 0
	combat_state().save_game()
	changed.emit()
	return true

func launch() -> bool:
	var configuration: Dictionary = combat_state().mech_configuration()
	if not configuration.valid:
		combat_state().message.emit(configuration.reason+"，请先在机库调整配装")
		return false
	if combat_state().recovery>0 or combat_state().hp<=0:
		combat_state().message.emit("母舰修复中，完成后即可出击")
		return false
	docked = false
	position = START
	destination = START
	steering = Vector2.ZERO
	path.clear()
	patrol = false
	grace = 8
	changed.emit()
	combat_state().save_game()
	return true

func navigate(target: Vector2) -> bool:
	if combat_state().recovery>0:
		combat_state().message.emit("装甲修复中，请稍候")
		return false
	var cell := free_cell(cell_at(bounded(target)))
	destination = bounded(target)
	if is_obstacle(cell_at(destination)):
		destination = bounded(Vector2(cell)*CELL+Vector2.ONE*CELL/2.0)
	steering = Vector2.ZERO
	var ok := plan_segment()
	if not ok: combat_state().message.emit("该位置暂时不可达，请选择附近地面")
	changed.emit()
	return ok

func plan_segment() -> bool:
	path = build_path(position,destination)
	path_index = 0
	return not path.is_empty()

func build_path(from: Vector2, target: Vector2) -> PackedVector2Array:
	var delta := target-from
	var goal := from+delta.limit_length(1300)
	var start := cell_at(from)
	var end := free_cell(cell_at(goal))
	var low := Vector2i(mini(start.x,end.x)-5,mini(start.y,end.y)-5)
	var high := Vector2i(maxi(start.x,end.x)+6,maxi(start.y,end.y)+6)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(low,high-low)
	grid.cell_size = Vector2.ONE*CELL
	grid.offset = Vector2.ONE*CELL/2.0
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(low.y,high.y):
		for x in range(low.x,high.x):
			grid.set_point_solid(Vector2i(x,y),is_obstacle(Vector2i(x,y)))
	grid.set_point_solid(start,false)
	grid.set_point_solid(end,false)
	var route := grid.get_point_path(start,end)
	if route.is_empty(): return route
	route.remove_at(0)
	# Boundary cells can have centers outside the playable rectangle. Every actual
	# waypoint must remain reachable after locomotion applies the same bounds.
	for i in range(route.size()): route[i] = bounded(route[i])
	if delta.length()<=1300: route.append(bounded(target))
	return route

func is_moving() -> bool:
	return path_index < path.size() or steering.length_squared()>0.01

func move_speed() -> float:
	var build: Dictionary = combat_state().mech_configuration()
	var speed: float = build.base_speed*(1+combat_state().equipment_stats().speed/100.0)*build.speed_factor*combat_state().expedition.speed_factor()
	if certification_region>=0: speed *= float(REGION_DATA.REGIONS[certification_region].speed)
	if drive_mode()=="dash" and drive_clock>=2.4: speed *= 2
	return speed

func drive_mode() -> String:
	for mode in ["hover","dash","treads"]:
		if combat_state().parts.has_trait(combat_state().selected_mech,mode): return mode
	return "walk"

func advance(delta: float) -> void:
	blocked_cells.clear()
	movement_blocked = false
	actual_velocity = Vector2.ZERO
	if not enabled or docked: return
	grace = maxf(0,grace-delta)
	explored[key(chunk_at(position))] = true
	if combat_state().recovery>0:
		brain.advance(self,delta)
		return
	combat_state().expedition.advance(self,delta)
	if combat_state()==State: State.carrier.advance(self,delta)
	if docked: return
	if patrol and combat_state().auto and steering==Vector2.ZERO:
		if tactical.update_survival(combat_state().hp,combat_state().defense.total_shield(),combat_state().defense.max_shield,combat_state().active_tactics()):
			combat_state().message.emit("自动战术：装甲低于 30%，已撤离回舰整备")
			enter_base()
			return
		if not boss.active: plan_tactical_movement(delta)
	if is_moving(): drive_clock = fmod(drive_clock+minf(delta,0.5),3.0)
	else: drive_clock = 0
	var was_moving := is_moving()
	var previous := position
	if steering.length_squared()>0.01:
		path.clear()
		var travel := steering.limit_length(1)*move_speed()*minf(delta,0.5)
		var steps := maxi(1,ceili(travel.length()/32.0))
		var step := travel/steps
		for i in range(steps):
			var candidate := bounded(position+Vector2(step.x,0))
			if not is_obstacle(cell_at(candidate)): position = candidate
			elif not cell_at(candidate) in blocked_cells: blocked_cells.append(cell_at(candidate))
			candidate = bounded(position+Vector2(0,step.y))
			if not is_obstacle(cell_at(candidate)): position = candidate
			elif not cell_at(candidate) in blocked_cells: blocked_cells.append(cell_at(candidate))
		destination = position
	elif path_index<path.size():
		var remaining := move_speed()*minf(delta,0.25)
		while remaining>0 and path_index<path.size():
			var amount := position.distance_to(path[path_index])
			if amount <= remaining:
				position = bounded(path[path_index])
				remaining -= amount
				path_index += 1
			else:
				position = bounded(position.move_toward(path[path_index],remaining))
				remaining = 0
		if path_index>=path.size() and position.distance_to(destination)>12: plan_segment()
	actual_velocity = (position-previous)/maxf(delta,0.001)
	movement_blocked = steering.length_squared()>0.01 and position.distance_to(previous)<0.01
	distance_travelled += previous.distance_to(position)
	if combat_state()==State and steering.length_squared()>0.01:
		State.record_story_movement(previous.distance_to(position))
	if drive_mode()=="dash" and drive_clock>=2.4: combat_state().rig.add_heat(previous.distance_to(position)*0.035)
	if was_moving and not is_moving() and previous.distance_to(position)>0:
		combat_state().save_game()
	if boss.active:
		boss.advance(self,delta)
		if not docked:
			hostile.advance(self,delta)
			if not docked: attacks.advance(self,delta)
		return
	brain.advance(self,delta)
	if not docked and combat_state().recovery<=0:
		hostile.advance(self,delta)
		if not docked: attacks.advance(self,delta)
	if combat_state().recovery>0: return
	combat_state().expedition.check_clear(self)
	if encounter_id!="" and position.distance_to(encounter_position)>maxf(RELEASE_RANGE,combat_state().attack_range()+80):
		drop_target()
	tactical.clock -= delta
	var acquire: bool = grace<=0 and (tactical.clock<=0 or encounter_id=="" or not target_in_range())
	if acquire: tactical.clock = 0.35
	for site in nearby(position,1):
		if cleared.has(site.id): continue
		if combat_state().expedition.active() and site.kind!="enemy": continue
		var distance := position.distance_to(site_position(site))
		if site.kind=="enemy":
			continue
		elif site.kind!="enemy" and distance<62:
			cleared[site.id] = true
			if site.kind=="resource":
				combat_state().credits += 180+combat_state().stage*20
				combat_state().cores += 8
				combat_state().message.emit("回收物资 · 信用点 +%d / 合金芯 +8" % (180+combat_state().stage*20))
			else:
				combat_state().gems += 30
				combat_state().hp = 100
				combat_state().message.emit("据点激活 · 装甲修复 / 星晶 +30")
			combat_state().feedback.emit("reward")
			combat_state().changed.emit()
			combat_state().save_game()
			changed.emit()
	var closest: Dictionary = {}
	if acquire:
		var candidates: Array = tactical_targets(maxf(ACQUIRE_RANGE,combat_state().attack_range()-30))
		closest = tactical.select_target(position,candidates,combat_state().active_tactics())
	if not closest.is_empty() and closest.id!=encounter_id:
		if encounter_id!="": drop_target()
		encounter_id = closest.id
		encounter_position = closest.p
		combat_state().reset_enemy()
		if enemy_health.has(encounter_id):
			combat_state().enemy_max = float(enemy_health[encounter_id].max)
			combat_state().enemy_hp = float(enemy_health[encounter_id].hp)
		combat_state().battle_clock = 0.8
		combat_state().auto = true
		changed.emit()
	patrol_clock += delta
	if patrol and not is_moving() and encounter_id=="" and patrol_clock>0.7 and not combat_state().expedition.active():
		patrol_clock = 0
		var candidates := nearby(position,3).filter(func(s): return not cleared.has(s.id))
		candidates.sort_custom(func(a,b): return position.distance_squared_to(a.p)<position.distance_squared_to(b.p))
		if not candidates.is_empty(): navigate(candidates[0].p)
		else: navigate(position+Vector2(1200,800))

func set_patrol(value: bool) -> void:
	if patrol==value: return
	patrol = value
	if value and combat_state()==State and not docked: State.story_event("auto")
	# Boss and legacy roaming routes also belong to autopilot, even when they
	# were not created by plan_tactical_movement().
	path.clear(); path_index = 0; destination = position
	tactical_path = false
	actual_velocity = Vector2.ZERO
	tactical.navigation_clock = 0
	boss.navigation_clock = 0
	changed.emit()
	combat_state().save_game()

func plan_tactical_movement(delta: float) -> void:
	if not patrol or steering!=Vector2.ZERO or encounter_id=="": return
	tactical.navigation_clock -= delta
	if tactical.navigation_clock>0: return
	tactical.navigation_clock = 0.35
	var settings: Dictionary = combat_state().movement_tactics()
	var weapon_range: float = combat_state().engagement_range()
	# Ranged combat keeps strafing at the chosen distance. Melee still closes
	# directly so short-range attacks can connect.
	var orbit: bool = bool(settings.orbit) and weapon_range>140 and settings.distance!="melee" and drive_mode()!="treads"
	var warnings: Array = combat_state().TACTICS.projectile_warnings(position,hostile.projectiles)
	var goal: Vector2 = tactical.destination(position,encounter_position,settings,weapon_range,warnings,orbit,bounded,func(point): return not is_obstacle(cell_at(point)))
	if tactical_path and is_moving() and destination.distance_to(goal)<35: return
	if position.distance_to(goal)>25:
		# Short strafes must not detour through cell centers: that can carry the
		# mech toward its enemy instead of maintaining the selected distance.
		if line_clear(position,goal):
			destination = goal; path = PackedVector2Array([goal]); path_index = 0
		else: navigate(goal)
		tactical_path = true
	elif is_moving(): path.clear(); path_index = 0; destination = position

func tactical_targets(radius: float) -> Array:
	return attack_targets().filter(func(target): return position.distance_to(target.p)<=radius and line_clear(position,target.p))

func auto_skill_allowed() -> bool:
	var elite: bool = boss.active
	for target in tactical_targets(combat_state().attack_range()):
		if target.get("elite",false): elite = true
	var danger: bool = combat_state().hp<=50 or tactical.shield_retreat
	for shot in hostile.projectiles:
		if shot.p.distance_to(position)<120: danger = true
	for warning in boss.warnings:
		if warning.p.distance_to(position)<warning.radius+42: danger = true
	return tactical.skill_allowed(combat_state().active_tactics(),elite,danger)

func target_in_range() -> bool:
	return encounter_id!="" and position.distance_to(encounter_position)<=combat_state().attack_range() and line_clear(position,encounter_position)

func current_target_id() -> String:
	return boss.target_id() if boss.active else encounter_id

func player_position() -> Vector2: return position
func player_alive() -> bool: return not docked and combat_state().hp>0
func guard_direction() -> Vector2:
	if encounter_id!="" and position.distance_squared_to(encounter_position)>0.01:
		combat_state().defense.guard_facing = position.direction_to(encounter_position)
	return combat_state().defense.guard_facing
func receive_directed_hit(damage: int, incoming: Vector2) -> bool:
	if docked or grace>1: return false
	return combat_state().receive_enemy_hit(damage,{"incoming":incoming,"facing":guard_direction()})
func receive_hostile_hit(damage: int) -> bool:
	if docked or grace>1: return false
	return combat_state().receive_enemy_hit(damage)

func attack_targets() -> Array:
	if boss.active: return boss.targets()
	var targets: Array = []
	for site in nearby(position,2):
		if site.kind=="enemy" and not cleared.has(site.id):
			var health: Dictionary = enemy_health.get(site.id,{"hp":combat_state().enemy_hp if site.id==encounter_id else 100.0+combat_state().stage*32,"max":combat_state().enemy_max if site.id==encounter_id else 100.0+combat_state().stage*32})
			targets.append({"id":site.id,"p":site_position(site),"hp":combat_state().enemy_hp if site.id==encounter_id else health.hp,"max":health.max,"elite":enemy_units.get(site.id,{}).get("elite",site.get("elite",false))})
	return targets

func remaining_target_health(id: String) -> float:
	if id.begins_with("boss:"):
		if id==boss.BODY: return maxf(0,boss.hp)
		if id=="boss:tracks": return float(boss.parts.tracks)
		if id=="boss:cannon": return float(boss.parts.cannon)
		for drone in boss.drones:
			if drone.id==id: return maxf(0,drone.hp)
		return 0
	if cleared.has(id): return 0
	if id==encounter_id: return maxf(0,combat_state().enemy_hp)
	return float(enemy_health.get(id,{"hp":(100.0+combat_state().stage*32.0)*(2 if combat_state().stage%5==0 else 1)}).hp)

func apply_attack_event(event: Dictionary) -> float:
	var pilot_factor: float = combat_state().pilot_runtime.multiplier(event)
	var resistance = boss.resistances() if boss.active and str(event.target).begins_with("boss:") else enemy_units.get(event.target,{}).get("resistances",{})
	if not resistance is Dictionary: resistance = {}
	var damage: float = 0
	event.resolved_components = {}
	for type in event.components:
		var component: float = float(event.components[type])*pilot_factor*(1-clampf(float(resistance.get(type,0)),-50,90)/100.0)
		event.resolved_components[type] = component; damage += component
	var before := remaining_target_health(event.target)
	if not apply_projectile_hit(event.target,maxi(1,int(round(damage))),event.mode,event.point): return 0
	var actual := maxf(0,before-remaining_target_health(event.target))
	combat_state().pilot_runtime.record_hit(event,actual,pilot_factor)
	combat_state().flush_pilot_progress()
	return actual

func apply_projectile_hit(id: String, damage: int, mode: String, point: Vector2) -> bool:
	if id.begins_with("boss:"): return boss.hit(self,id,damage,mode,point)
	if docked or combat_state().recovery>0 or cleared.has(id): return false
	combat_state().attack_hit.emit(point,damage,mode)
	if id==encounter_id:
		combat_state().damage_enemy(damage)
	else:
		var maximum: float = (100.0+combat_state().stage*32.0)*(2 if combat_state().stage%5==0 else 1)
		var health: Dictionary = enemy_health.get(id,{"hp":maximum,"max":maximum})
		health.hp -= damage
		if health.hp<=0:
			cleared[id] = true
			enemy_units.erase(id)
			enemy_health.erase(id)
			combat_state().reward_victory()
			combat_state().victory.emit()
			combat_state().save_game()
		else: enemy_health[id] = health
	combat_state().changed.emit()
	return true

func splash_damage(center: Vector2, exclude: String, damage: int) -> void:
	if boss.active:
		for target in boss.targets():
			if target.id!=exclude and target.p.distance_to(center)<=150: boss.hit(self,target.id,damage,"explosion",target.p)
		return
	var killed: Array = []
	var candidates: Dictionary = {}
	# Include guards at the edge of splash range even before their AI is activated.
	for site in nearby(center,1):
		if site.kind=="enemy": candidates[site.id] = site_position(site)
	for id in candidates:
		var point: Vector2 = candidates[id]
		if id==exclude or cleared.has(id) or point.distance_to(center)>150 or not line_clear(center,point): continue
		var health: Dictionary = enemy_health.get(id,{"hp":(100.0+combat_state().stage*32.0)*(2 if combat_state().stage%5==0 else 1),"max":(100.0+combat_state().stage*32.0)*(2 if combat_state().stage%5==0 else 1)})
		health.hp -= damage
		if health.hp<=0: killed.append(id)
		else: enemy_health[id] = health
	for id in killed:
		cleared[id] = true
		enemy_units.erase(id)
		enemy_health.erase(id)
		combat_state().reward_victory()
		combat_state().victory.emit()
	if not killed.is_empty():
		combat_state().changed.emit()
		combat_state().save_game()

func enemy_in_range() -> bool:
	return encounter_id!="" and position.distance_to(encounter_position)<=ENEMY_RANGE

func drop_target() -> void:
	if encounter_id!="":
		enemy_health[encounter_id] = {"hp":combat_state().enemy_hp,"max":combat_state().enemy_max}
	encounter_id = ""
	combat_state().rig.reset_clocks()
	changed.emit()

func finish_encounter() -> void:
	if encounter_id=="": return
	cleared[encounter_id] = true
	enemy_health.erase(encounter_id)
	enemy_units.erase(encounter_id)
	encounter_id = ""
	grace = 0.35
	changed.emit()

func retreat() -> void:
	if encounter_id=="": return
	var away := (position-encounter_position).normalized()
	if away==Vector2.ZERO: away = Vector2(-1,-1).normalized()
	var safe := free_cell(cell_at(bounded(position+away*260)))
	position = bounded(Vector2(safe)*CELL+Vector2.ONE*CELL/2.0)
	drop_target()
	path.clear()
	steering = Vector2.ZERO
	destination = position
	grace = 8
	patrol = false
	combat_state().message.emit("已撤离至安全位置")
	changed.emit()
	combat_state().save_game()

func export_save() -> Dictionary:
	var health := enemy_health.duplicate(true)
	if encounter_id!="": health[encounter_id] = {"hp":combat_state().enemy_hp,"max":combat_state().enemy_max}
	var ai: Dictionary = {}
	for id in enemy_units:
		var unit: Dictionary = enemy_units[id]
		ai[id] = {"position":[unit.p.x,unit.p.y],"home":[unit.home.x,unit.home.y],"mode":unit.mode,"name":unit.name,"elite":unit.get("elite",false),"role":unit.get("role",""),"region":unit.get("region",-1)}
	return {"expedition_autopilot":patrol if combat_state().expedition.active() else false,"boss_autopilot":patrol if boss.active else false,"boss":boss.export_save(),"docked":docked,"ai":ai,"chase_distance":chase_distance,"alerts":alerts,"enemy_shots":enemy_shots,"returns":returns_completed,"position":[position.x,position.y],"cleared":cleared,"explored":explored,"distance":distance_travelled,"enemies":health,"shots":shots_fired,"moving_shots":moving_shots}

func import_save(data: Dictionary) -> void:
	hostile.projectiles.clear()
	attacks.reset()
	tactical.reset(); tactical_path = false
	docked = bool(data.get("docked",false))
	boss.import_save(data.get("boss"))
	if docked: boss.stop()
	blocked_cells.clear()
	movement_blocked = false
	var saved = data.get("position",[START.x,START.y])
	if saved is Array and saved.size()==2 and (saved[0] is float or saved[0] is int) and (saved[1] is float or saved[1] is int):
		var p := Vector2(float(saved[0]),float(saved[1]))
		if p.is_finite(): position = bounded(p)
	if docked: position = START
	destination = position
	cleared = data.get("cleared",{}) if data.get("cleared",{}) is Dictionary else {}
	explored = data.get("explored",{}) if data.get("explored",{}) is Dictionary else {}
	shots_fired = maxi(0,int(data.get("shots",0)))
	moving_shots = maxi(0,int(data.get("moving_shots",0)))
	actual_velocity = Vector2.ZERO
	drive_clock = 0
	enemy_units.clear()
	alerts = maxi(0,int(data.get("alerts",0)))
	enemy_shots = maxi(0,int(data.get("enemy_shots",0)))
	returns_completed = maxi(0,int(data.get("returns",0)))
	chase_distance = maxf(0,float(data.get("chase_distance",0)))
	var saved_ai = data.get("ai",{})
	if saved_ai is Dictionary:
		for id in saved_ai:
			if enemy_units.size()>=ENEMY_BRAIN.MAX_UNITS: break
			var entry = saved_ai[id]
			if not entry is Dictionary: continue
			var point = entry.get("position",[])
			var home = entry.get("home",[])
			if not point is Array or not home is Array or point.size()!=2 or home.size()!=2: continue
			if not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int): continue
			if not (home[0] is float or home[0] is int) or not (home[1] is float or home[1] is int): continue
			var p := Vector2(float(point[0]),float(point[1]))
			var h := Vector2(float(home[0]),float(home[1]))
			if not p.is_finite() or not h.is_finite(): continue
			var role: String = entry.get("role","") if entry.get("role","") in ["guard","rusher","cannon"] else ""
			var enemy_region: int = clampi(int(entry.get("region",-1)),-1,3) if entry.get("region",-1) is float or entry.get("region",-1) is int else -1
			var unit: Dictionary = brain.new_unit({"id":id,"p":bounded(h),"name":entry.get("name","巡逻机兵"),"elite":entry.get("elite",false)==true,"role":role,"region":enemy_region})
			unit.elite = entry.get("elite",false)==true
			unit.p = bounded(p)
			unit.mode = entry.get("mode","guard") if entry.get("mode","guard") in ["guard","chase","attack","return"] else "guard"
			enemy_units[id] = unit
	enemy_health.clear()
	var saved_enemies = data.get("enemies",{})
	if saved_enemies is Dictionary:
		for id in saved_enemies:
			var health = saved_enemies[id]
			if health is Dictionary and (health.get("hp") is float or health.get("hp") is int) and (health.get("max") is float or health.get("max") is int):
				var maximum := maxf(1,float(health.get("max",100)))
				if is_finite(maximum) and is_finite(float(health.hp)):
					enemy_health[id] = {"hp":clampf(float(health.hp),1,maximum),"max":maximum}
	distance_travelled = maxf(0,float(data.get("distance",0)))
	path.clear()
	path_index = 0
	steering = Vector2.ZERO
	patrol = false
	encounter_id = ""

	if combat_state().expedition.active():
		patrol = bool(data.get("expedition_autopilot",true))
		if combat_state().expedition.run.phase!="boss": boss.stop()
		elif not boss.active: combat_state().expedition.run.phase = "explore"
		for id in combat_state().expedition.run.used: cleared[id] = true
		for id in combat_state().expedition.run.secured: cleared[id] = true
	if boss.active:
		patrol = bool(data.get("boss_autopilot",true))
		position = boss.point([position.x,position.y],boss.center-Vector2(260,0))
		encounter_id = boss.BODY
		encounter_position = boss.target_position()
		combat_state().enemy_hp = boss.hp; combat_state().enemy_max = boss.maximum
