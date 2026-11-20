extends RefCounted
## Stationary carrier fire control and fleet commands share sortie persistence.
const COSTS = {"barrage":40,"barrier":30,"rally":45}
const TITLES = {"barrage":"舰队齐射","barrier":"护航屏障","rally":"驻舰补给站"}
const DOCTRINES = {"assault":"火力警戒","guard":"近舰防护","silent":"静默待命"}
const ATTACK_RANGE: float = 650.0
var flashes: Array = []

func initial() -> Dictionary:
	var landing: Vector2 = State.expedition.DATA.LANDING
	return {"energy":60.0,"ship":[landing.x,landing.y],"goal":[landing.x,landing.y],"flight_speed":0.0,"mode":"escort","clock":0.0,"auto_clock":6.0,"salvos":[],"field":{},"shots":0,"damage":0.0,"prevented":0.0,"repaired":0.0,"deployments":0}

func data() -> Dictionary:
	return State.expedition.run.support.ops if State.expedition.active() else {}

func position() -> Vector2:
	var current := data()
	return Vector2(current.ship[0],current.ship[1]) if not current.is_empty() else World.START

func set_doctrine(value: String) -> bool:
	if not DOCTRINES.has(value): return false
	State.carrier.doctrine = value
	State.story_event("fleet")
	State.changed.emit(); State.save_game()
	return true

func follow() -> bool:
	if not State.expedition.active() or World.docked: return false
	data().mode = "escort"
	State.message.emit("绯红方舟恢复定点警戒")
	State.changed.emit(); State.save_game()
	return true

func targets(world: Node) -> Array:
	if world.boss.active: return world.boss.targets()
	var candidates: Dictionary = {}
	# Search around the ship, independently of the player's encounter and camera.
	for site in world.nearby(position(),2):
		if site.kind=="enemy" and not world.cleared.has(site.id):
			candidates[site.id] = {"id":site.id,"p":world.site_position(site)}
	for id in world.enemy_units:
		if not world.cleared.has(id): candidates[id] = {"id":id,"p":world.enemy_units[id].p}
	return candidates.values()

func target(world: Node) -> Dictionary:
	var best: Dictionary = {}
	var ship := position()
	for candidate in targets(world):
		if candidate.id in ["boss:tracks","boss:cannon"] or candidate.p.distance_to(ship)>ATTACK_RANGE: continue
		if best.is_empty() or candidate.p.distance_to(ship)<best.p.distance_to(ship): best = candidate
	return best

func blocked(world: Node, command: String) -> String:
	if not COSTS.has(command): return "无效指令"
	if world!=World or world.docked or not State.expedition.active() or State.recovery>0: return "进入副本后可下达指令"
	var current := data()
	if float(current.clock)>0: return "指挥链路冷却 %.0f 秒"%ceilf(current.clock)
	if float(current.energy)<COSTS[command]: return "需要舰能 %d，正在充能"%COSTS[command]
	if command=="barrage" and target(world).is_empty(): return "附近没有可锁定目标"
	if command=="rally" and world.boss.active: return "首领交战中无法部署补给站"
	return ""

func command(world: Node, kind: String) -> bool:
	if blocked(world,kind)!="": return false
	var current := data()
	current.energy = maxf(0,float(current.energy)-COSTS[kind]); current.clock = 10.0
	match kind:
		"barrage":
			var enemy := target(world)
			for i in range(3):
				current.salvos.append({"point":[enemy.p.x,enemy.p.y],"t":0.8+i*0.55,"damage":35+10*(int(State.carrier.levels.cannon)-1),"radius":150.0,"area":true})
		"barrier": current.field = {"point":[world.position.x,world.position.y],"ttl":8.0,"radius":190.0}
		"rally":
			current.mode = "station"; current.goal = current.ship.duplicate()
			current.deployments = int(current.deployments)+1
	State.message.emit(TITLES[kind]+" · 指令已执行")
	State.pilot_radio.emit("carrier",State.selected)
	State.changed.emit(); State.save_game()
	return true

func protected(point: Vector2) -> bool:
	var current := data()
	if current.is_empty() or current.field.is_empty(): return false
	return float(current.field.ttl)>0 and point.distance_to(Vector2(current.field.point[0],current.field.point[1]))<=float(current.field.radius)

func mitigate(point: Vector2, incoming: int) -> int:
	if not protected(point): return incoming
	var reduced := maxi(1,ceili(incoming*0.65)) if incoming>0 else 0
	data().prevented = float(data().prevented)+incoming-reduced
	return reduced

func supplying(world: Node) -> bool:
	var current := data()
	if current.is_empty() or current.mode!="station" or world.boss.active: return false
	if position().distance_to(Vector2(current.goal[0],current.goal[1]))>12 or world.position.distance_to(position())>160: return false
	for enemy in world.attack_targets():
		if enemy.p.distance_to(world.position)<420: return false
	return true

func move_ship(current: Dictionary, _delta: float) -> void:
	# Keep old save fields compatible, but discard any outstanding travel order.
	current.goal = current.ship.duplicate()
	current.flight_speed = 0.0

func advance(world: Node, delta: float) -> void:
	for flash in flashes: flash.ttl -= delta
	flashes = flashes.filter(func(flash): return flash.ttl>0)
	if world!=World or world.docked or not State.expedition.active(): return
	var current := data()
	current.energy = minf(100,float(current.energy)+delta*(3.0+0.25*(int(State.carrier.levels.logistics)-1)))
	current.clock = maxf(0,float(current.clock)-delta)
	current.auto_clock = maxf(0,float(current.auto_clock)-delta)
	var ship := position()
	move_ship(current,delta)
	if not current.field.is_empty():
		current.field.ttl = maxf(0,float(current.field.ttl)-delta)
		if current.field.ttl<=0: current.field = {}
	if supplying(world) and (State.hp<100 or State.rig.heat>0) and current.energy>0:
		var supply_time := minf(delta,float(current.energy)/2.0)
		var before: float = State.hp
		State.defense.heal(supply_time*(2.0+0.5*(int(State.carrier.levels.repair)-1)))
		State.rig.heat = maxf(0,State.rig.heat-supply_time*4)
		current.repaired = float(current.repaired)+State.hp-before; current.energy -= supply_time*2
	if current.auto_clock<=0 and current.energy>=6:
		var enemy := target(world)
		if State.carrier.doctrine=="assault" and not enemy.is_empty():
			current.salvos.append({"point":[enemy.p.x,enemy.p.y],"t":0.5,"damage":24+8*(int(State.carrier.levels.cannon)-1),"radius":90.0,"area":false})
			current.auto_clock = 6.0; current.energy -= 6
		elif State.carrier.doctrine=="guard" and ship.distance_to(world.position)<=ATTACK_RANGE and State.defense.temporary_shield<12:
			State.defense.grant_temporary(12,6); current.auto_clock = 8.0; current.energy -= 6
			flashes.append({"from":ship,"to":world.position,"ttl":0.6,"guard":true})
	var ready: Array = []
	var waiting: Array = []
	for salvo in current.salvos:
		salvo.t = maxf(0,float(salvo.t)-delta)
		if salvo.t<=0: ready.append(salvo)
		else: waiting.append(salvo)
	# Commit removal before damage: the last hit may settle and save the sortie.
	current.salvos = waiting
	for salvo in ready:
		if world.docked or not State.expedition.active(): break
		var point := Vector2(salvo.point[0],salvo.point[1])
		current.shots = int(current.shots)+1
		flashes.append({"from":ship,"to":point,"ttl":0.5,"guard":false})
		world.attacks.effects.append({"p":point,"radius":salvo.radius,"t":0.35,"mode":"missile","ion":true})
		for enemy in targets(world).duplicate(true):
			if enemy.id in ["boss:tracks","boss:cannon"] or enemy.p.distance_to(point)>float(salvo.radius): continue
			var health: float = world.remaining_target_health(enemy.id)
			world.apply_projectile_hit(enemy.id,int(salvo.damage),"carrier",enemy.p)
			current.damage = float(current.damage)+maxf(0,health-world.remaining_target_health(enemy.id))
			if world.docked and State.expedition.report.has("carrier"):
				State.expedition.report.carrier.damage = current.damage
			if not bool(salvo.area) or world.docked: break
	if not ready.is_empty(): State.save_game()

func import_save(raw: Variant) -> Dictionary:
	var result := initial()
	if not raw is Dictionary: return result
	result.flight_speed = 0.0
	for key in ["energy","clock","auto_clock","damage","prevented","repaired"]:
		result[key] = State.expedition.finite_number(raw.get(key),result[key],0,100 if key=="energy" else 10 if key in ["clock","auto_clock"] else 1000000000)
	for key in ["shots","deployments"]: result[key] = State.expedition.integer(raw.get(key),0,0,1000000)
	if raw.get("mode") in ["escort","station"]: result.mode = raw.mode
	for key in ["ship","goal"]:
		var point: Variant = raw.get(key)
		if valid_point(point): result[key] = point.duplicate()
	result.goal = result.ship.duplicate()
	var field: Variant = raw.get("field")
	if field is Dictionary and valid_point(field.get("point")):
		result.field = {"point":field.point.duplicate(),"ttl":State.expedition.finite_number(field.get("ttl"),0,0,8),"radius":190.0}
	if raw.get("salvos") is Array:
		for salvo in raw.salvos.slice(0,4):
			if not salvo is Dictionary or not valid_point(salvo.get("point")): continue
			result.salvos.append({"point":salvo.point.duplicate(),"t":State.expedition.finite_number(salvo.get("t"),0.5,0,2),"damage":State.expedition.integer(salvo.get("damage"),24,1,75),"radius":150.0 if salvo.get("area")==true else 90.0,"area":salvo.get("area")==true})
	return result

func valid_point(point: Variant) -> bool:
	if not point is Array or point.size()!=2: return false
	for value in point:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	return State.expedition.bounds().has_point(Vector2(point[0],point[1]))
