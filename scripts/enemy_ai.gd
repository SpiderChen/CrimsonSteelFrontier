extends RefCounted
## Nearby enemy squads: guard -> chase/attack -> return. All positions are authoritative.
const DETECT_RANGE: float = 330.0
const LOSE_RANGE: float = 570.0
const HOME_LEASH: float = 900.0
const SPEED: float = 176.0
const STOP_RANGE: float = 170.0
const RESUME_RANGE: float = 205.0
const FIRE_INTERVAL: float = 1.2
const MAX_UNITS: int = 48
const REGION_DATA = preload("res://scripts/region_data.gd")

func new_unit(site: Dictionary) -> Dictionary:
	var unit := {"id":site.id,"home":site.p,"p":site.p,"mode":"guard","route":PackedVector2Array(),"index":0,"repath":0.0,"goal":site.p,"fire":0.6,"moving":false,"name":site.get("name","巡逻机兵"),"elite":site.get("elite",false)==true,"role":site.get("role",""),"region":site.get("region",-1)}
	if int(unit.region)>=0 and int(unit.region)<4 and unit.role in ["guard","rusher","cannon"]:
		unit.merge(REGION_DATA.enemy(unit.role,int(unit.region),unit.elite))
	return unit

func advance(world: Node, delta: float) -> void:
	var step := minf(delta,0.25)
	for site in world.nearby(world.position,2):
		if site.kind!="enemy" or world.cleared.has(site.id) or world.enemy_units.has(site.id): continue
		if world.position.distance_to(site.p)>DETECT_RANGE+100: continue
		if world.enemy_units.size()>=MAX_UNITS: break
		world.enemy_units[site.id] = new_unit(site)
		if site.get("elite",false) and not world.enemy_health.has(site.id) and site.id!=world.encounter_id:
			var maximum: float = (100.0+world.combat_state().stage*32.0)*(2 if world.combat_state().stage%5==0 else 1)*1.6
			world.enemy_health[site.id] = {"hp":maximum,"max":maximum}
	var remove: Array = []
	for id in world.enemy_units:
		var unit: Dictionary = world.enemy_units[id]
		if world.cleared.has(id):
			remove.append(id)
			continue
		unit.fire = maxf(0,float(unit.fire)-delta)
		unit.repath = maxf(0,float(unit.repath)-delta)
		var p: Vector2 = unit.p
		var home: Vector2 = unit.home
		var distance: float = p.distance_to(world.position)
		if world.combat_state().recovery>0 or world.grace>1:
			if unit.mode=="chase" or unit.mode=="attack": set_mode(unit,"return")
		elif unit.mode=="guard" and distance<=DETECT_RANGE:
			set_mode(unit,"chase")
			world.alerts += 1
		if unit.mode=="chase" or unit.mode=="attack":
			if distance>LOSE_RANGE or world.position.distance_to(home)>HOME_LEASH or p.distance_to(home)>HOME_LEASH:
				set_mode(unit,"return")
			else:
				var sight: bool = world.line_clear(p,world.position)
				if distance<=float(unit.get("stop",STOP_RANGE)) and sight: unit.mode = "attack"
				elif distance>float(unit.get("stop",STOP_RANGE))+35 or not sight: unit.mode = "chase"
				if unit.mode=="chase":
					var before: Vector2 = unit.p
					walk(world,unit,world.position,step)
					world.chase_distance += before.distance_to(unit.p)
				p = unit.p
				if p.distance_to(world.position)<=float(unit.get("range",world.ENEMY_RANGE)) and world.line_clear(p,world.position) and unit.fire<=0 and world.combat_state().recovery<=0:
					unit.fire = float(unit.get("interval",FIRE_INTERVAL))
					var damage := maxi(2,4+world.combat_state().stage-int(world.combat_state().total_attack()/22.0))
					if unit.has("damage"): damage = int(unit.damage)
					elif unit.elite: damage = ceili(damage*1.35)
					if world.combat_state().recovery<=0 and not world.docked:
						world.hostile.launch(p,world.position,damage)
						world.enemy_shots += 1
						world.enemy_fired.emit(p,damage)
		if unit.mode=="return":
			walk(world,unit,home,step)
			if unit.p.distance_to(home)<5:
				unit.p = home
				set_mode(unit,"guard")
				world.returns_completed += 1
		if unit.mode=="guard" and unit.p.distance_to(world.position)>1300:
			remove.append(id)
	for id in remove: world.enemy_units.erase(id)
	if world.encounter_id!="" and world.enemy_units.has(world.encounter_id):
		world.encounter_position = world.enemy_units[world.encounter_id].p

func set_mode(unit: Dictionary, mode: String) -> void:
	unit.mode = mode
	unit.route = PackedVector2Array()
	unit.index = 0
	unit.repath = 0.0
	unit.moving = false

func walk(world: Node, unit: Dictionary, goal: Vector2, delta: float) -> void:
	if unit.repath<=0 and (unit.route.is_empty() or unit.index>=unit.route.size() or goal.distance_to(unit.goal)>70):
		unit.route = world.build_path(unit.p,goal)
		unit.index = 0
		unit.goal = goal
		unit.repath = 0.5
	var remaining: float = float(unit.get("speed",SPEED))*delta
	var before: Vector2 = unit.p
	while remaining>0 and unit.index<unit.route.size():
		var next: Vector2 = unit.route[unit.index]
		var distance: float = unit.p.distance_to(next)
		var amount := minf(remaining,distance)
		var candidate: Vector2 = unit.p.move_toward(next,amount)
		if world.is_obstacle(world.cell_at(candidate)):
			unit.route = PackedVector2Array()
			unit.index = 0
			unit.repath = 0
			break
		unit.p = world.bounded(candidate)
		remaining -= amount
		if distance<=amount+0.001: unit.index += 1
		if unit.mode=="chase" and unit.p.distance_to(world.position)<=float(unit.get("stop",STOP_RANGE)) and world.line_clear(unit.p,world.position): break
	unit.moving = before.distance_to(unit.p)>0.01
