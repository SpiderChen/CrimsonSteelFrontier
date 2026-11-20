extends RefCounted
## Gravedigger: independently breakable tracks/cannon, directional armor and timed AoE.
const CENTER := Vector2(1536,384)
const BODY = "boss:core"
const REGION_DATA = preload("res://scripts/region_data.gd")
var region: int = -1
var alert: int = 0
var active: bool = false
var victories: int = 0
var pending_epics: int = 0
var position := CENTER
var center := CENTER
var facing := Vector2.LEFT
var hp: float = 4200
var maximum: float = 4200
var phase: int = 1
var parts := {"tracks":700.0,"cannon":650.0}
var blasts: Array = []
var warnings: Array = []
var drones: Array = []
var selected: String = "auto"
var auto_target: String = ""
var fire_clock: float = 1.5
var drone_clock: float = 3
var navigation_clock: float = 0
var sequence: int = 0
var elapsed: float = 0
var dodged: int = 0

func start(region_id: int = -1, warning_level: int = 0, anchor: Vector2 = CENTER) -> void:
	center = anchor
	region = clampi(region_id,-1,3); alert = clampi(warning_level,0,3)
	maximum = 4200*(1+maxi(0,region)*0.25+alert*0.05)
	active = true; hp = maximum; position = center; facing = Vector2.LEFT; phase = 1
	parts = {"tracks":700.0,"cannon":650.0}
	blasts.clear(); warnings.clear(); drones.clear(); selected = "auto"; auto_target = ""
	fire_clock = 1.5; drone_clock = 3; navigation_clock = 0; sequence = 0; elapsed = 0; dodged = 0

func stop() -> void:
	active = false
	blasts.clear(); warnings.clear(); drones.clear()

func display_name() -> String:
	return "掘墓者" if region<0 else REGION_DATA.REGIONS[region].boss

func resistances() -> Dictionary:
	return {"thermal":20.0,"electric":-10.0} if region==1 else {"electric":20.0,"kinetic":-10.0} if region==3 else {}

func target_id() -> String:
	if selected=="tracks" and parts.tracks>0: return "boss:tracks"
	if selected=="cannon" and parts.cannon>0: return "boss:cannon"
	if selected=="core": return BODY
	if selected=="auto" and auto_target!="":
		for target in targets():
			if target.id==auto_target: return auto_target
	if phase==1 and parts.tracks>0: return "boss:tracks"
	if phase==2 and parts.cannon>0: return "boss:cannon"
	return BODY

func targets() -> Array:
	if not active: return []
	var out: Array = [{"id":BODY,"p":position,"hp":hp,"max":maximum,"elite":true}]
	if parts.tracks>0: out.append({"id":"boss:tracks","p":position+Vector2(-35,58).rotated(facing.angle()),"hp":parts.tracks,"max":700.0,"elite":true,"part":true,"part_priority":2 if phase==1 else 1})
	if parts.cannon>0: out.append({"id":"boss:cannon","p":position+Vector2(35,-58).rotated(facing.angle()),"hp":parts.cannon,"max":650.0,"elite":true,"part":true,"part_priority":2 if phase==2 else 1})
	for drone in drones:
		if drone.hp>0: out.append({"id":drone.id,"p":drone.p,"hp":drone.hp,"max":180.0,"elite":false})
	return out

func target_position() -> Vector2:
	for target in targets():
		if target.id==target_id(): return target.p
	return position

func hit(world: Node, id: String, damage: int, mode: String, point: Vector2) -> bool:
	if not active: return false
	for drone in drones:
		if drone.id==id and drone.hp>0:
			drone.hp -= damage
			State.attack_hit.emit(point,damage,mode)
			return true
	if id=="boss:tracks" or id=="boss:cannon":
		var name: String = "tracks" if id=="boss:tracks" else "cannon"
		if parts[name]<=0: return false
		damage = mini(damage,int(ceil(float(parts[name]))))
		parts[name] = maxf(0,float(parts[name])-damage)
		hp -= damage*0.4
		if parts[name]<=0:
			hp -= 300
			State.message.emit("履带已破坏 · 转向与机动受限" if name=="tracks" else "肩炮已破坏 · 炮击威力降低")
	elif id==BODY:
		var frontal: bool = position.direction_to(world.position).dot(facing)>0.6
		var factor := 1.35 if phase==3 else 0.8 if mode=="rail" else 0.55 if frontal else 1.2
		damage = maxi(1,int(damage*factor))
		hp -= damage
	else: return false
	State.attack_hit.emit(point,damage,mode)
	hp = maxf(0,hp)
	phase = maxi(phase,3 if hp<=maximum*0.35 else 2 if hp<=maximum*0.7 else 1)
	State.enemy_hp = maxf(0,hp); State.enemy_max = maximum
	world.encounter_position = target_position()
	if hp<=0:
		active = false; victories += 1
		blasts.clear(); warnings.clear(); drones.clear()
		if State.expedition.active() and State.expedition.run.phase=="boss":
			State.expedition.complete_boss(world)
			State.victory.emit(); State.changed.emit()
			return true
		State.record_pilot("bosses",1)
		State.credits += 900; State.cores += 30; State.gems += 200 if victories==1 else 100; State.wins += 1
		State.expedition.register_clear(0)
		pending_epics += 1
		claim_reward()
		world.enter_base()
		State.message.emit("掘墓者击破 · 已回舰 / 区域样本与蓝图已入库")
		State.victory.emit()
	State.changed.emit()
	return true

func claim_reward() -> bool:
	if pending_epics<=0: return false
	var item: Dictionary = State.parts.roll(1,2,true)
	if item.is_empty(): return false
	item.mechanism = "pierce"
	pending_epics -= 1
	State.save_game()
	return true

func advance(world: Node, delta: float) -> void:
	if not active: return
	var chosen: Dictionary = world.tactical.select_target(world.position,targets().filter(func(target): return world.position.distance_to(target.p)<=State.attack_range()),State.active_tactics())
	auto_target = chosen.get("id","")
	var remaining := minf(delta,2)
	while remaining>0 and active:
		var step := minf(remaining,0.05); remaining -= step; elapsed += step
		facing = facing.rotated(clampf(facing.angle_to(position.direction_to(world.position)),-step*(0.25 if parts.tracks<=0 else 1.0),step*(0.25 if parts.tracks<=0 else 1.0)))
		if position.distance_to(world.position)>210:
			position = position.move_toward(world.position,step*(12 if parts.tracks<=0 else 65 if region==2 else 45)).clamp(center-Vector2(230,230),center+Vector2(230,230))
		for blast in blasts: blast.t -= step
		blasts = blasts.filter(func(blast): return blast.t>0)
		drones = drones.filter(func(drone): return drone.hp>0)
		var next: Array = []
		for warning in warnings:
			warning.t -= step
			if warning.t<=0:
				blasts.append({"p":warning.p,"radius":warning.radius,"t":0.3})
				if world.position.distance_to(warning.p)<=warning.radius+16: world.receive_hostile_hit(int(warning.damage))
				else: dodged += 1
				if not active: return
			else: next.append(warning)
		warnings = next
		fire_clock -= step; drone_clock -= step; navigation_clock -= step
		if fire_clock<=0:
			fire_clock = (3.3 if phase==1 else 2.8 if phase==2 else 1.8)*(0.9 if region==1 else 1.0)
			var count: int = (1 if phase==1 else 3 if phase==2 else 4)+mini(1,alert)
			for i in range(count):
				var offset := Vector2.ZERO if i==0 else Vector2(i*90,0) if region==2 else Vector2.from_angle(i*TAU/count)*100
				warnings.append({"p":world.position+offset,"radius":85.0 if region==1 else 65.0 if phase==1 else 80.0,"t":1.6 if phase<3 else 1.15,"duration":1.6 if phase<3 else 1.15,"damage":(16 if phase==1 else 22 if phase==2 else 28)*(0.55 if parts.cannon<=0 else 1.0)})
		if (phase>=2 or region==3) and drone_clock<=0 and drones.filter(func(d): return d.hp>0).size()<(4 if region==3 else 3):
			drone_clock = 6
			sequence += 1
			drones.append({"id":"boss:drone:%d"%sequence,"p":position+Vector2(0,-100),"hp":180.0,"fire":1.0})
		for drone in drones:
			if drone.hp<=0: continue
			if drone.p.distance_to(position)<100: hp = minf(maximum,hp+step*3)
			if drone.p.distance_to(world.position)>180: drone.p = drone.p.move_toward(world.position,step*70)
			drone.fire -= step
			if drone.fire<=0:
				drone.fire = 1.6
				world.hostile.launch(drone.p,world.position,5)
		if world.patrol and world.steering==Vector2.ZERO and navigation_clock<=0:
			navigation_clock = 0.25
			var settings: Dictionary = State.movement_tactics()
			var threats: Array = warnings+State.TACTICS.projectile_warnings(world.position,world.hostile.projectiles)
			var destination: Vector2 = world.tactical.destination(world.position,position,settings,State.engagement_range(),threats,bool(settings.orbit) and world.drive_mode()!="treads",func(point): return world.bounded(point.clamp(center-Vector2(520,430),center+Vector2(520,430))),func(_point): return true)
			if destination.distance_to(world.position)>5:
				world.destination = destination; world.path = PackedVector2Array([destination]); world.path_index = 0
	world.encounter_id = BODY
	world.encounter_position = target_position()
	State.enemy_hp = hp; State.enemy_max = maximum

func export_save() -> Dictionary:
	var serialized_warnings: Array = []
	for warning in warnings:
		var item: Dictionary = warning.duplicate()
		item.p = [warning.p.x,warning.p.y]; serialized_warnings.append(item)
	var serialized_drones: Array = []
	for drone in drones:
		var item: Dictionary = drone.duplicate()
		item.p = [drone.p.x,drone.p.y]; serialized_drones.append(item)
	return {"center":[center.x,center.y],"region":region,"alert":alert,"active":active,"phase":phase,"victories":victories,"pending_epics":pending_epics,"hp":hp,"parts":parts.duplicate(true),"position":[position.x,position.y],"facing":[facing.x,facing.y],"selected":selected,"fire_clock":fire_clock,"drone_clock":drone_clock,"sequence":sequence,"elapsed":elapsed,"dodged":dodged,"warnings":serialized_warnings,"drones":serialized_drones}

func number(value: Variant, fallback: float, low: float, high: float) -> float:
	return clampf(float(value),low,high) if (value is float or value is int) and is_finite(float(value)) else fallback

func point(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size()==2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int):
		var result := Vector2(value[0],value[1])
		if result.is_finite(): return result.clamp(center-Vector2.ONE*700,center+Vector2.ONE*700)
	return fallback

func import_save(data: Variant) -> void:
	if data is Dictionary: start(int(number(data.get("region"),-1,-1,3)),int(number(data.get("alert"),0,0,3)))
	else: start()
	if State.expedition.active() and State.expedition.run.phase=="boss": center = State.expedition.boss_site().p
	active = false; victories = 0; pending_epics = 0
	if not data is Dictionary: return
	victories = int(number(data.get("victories"),0,0,1000000))
	pending_epics = int(number(data.get("pending_epics"),0,0,10000))
	hp = number(data.get("hp"),maximum,0,maximum)
	active = bool(data.get("active",false)) and hp>0
	position = point(data.get("position"),center)
	var direction = data.get("facing",[-1,0])
	facing = Vector2(number(direction[0],-1,-1,1),number(direction[1],0,-1,1)).normalized() if direction is Array and direction.size()==2 else Vector2.LEFT
	if facing==Vector2.ZERO: facing = Vector2.LEFT
	phase = maxi(int(number(data.get("phase"),1,1,3)),3 if hp<=maximum*0.35 else 2 if hp<=maximum*0.7 else 1)
	var saved_parts = data.get("parts")
	if saved_parts is Dictionary:
		parts.tracks = number(saved_parts.get("tracks"),700,0,700)
		parts.cannon = number(saved_parts.get("cannon"),650,0,650)
	selected = str(data.get("selected","auto"))
	if selected not in ["auto","core","tracks","cannon"]: selected = "auto"
	fire_clock = number(data.get("fire_clock"),1.5,0,4)
	drone_clock = number(data.get("drone_clock"),3,0,6)
	sequence = int(number(data.get("sequence"),0,0,1000000))
	elapsed = number(data.get("elapsed"),0,0,1000000)
	dodged = int(number(data.get("dodged"),0,0,1000000))
	var items = data.get("warnings",[])
	if items is Array:
		for raw in items.slice(0,12):
			if not raw is Dictionary: continue
			warnings.append({"p":point(raw.get("p"),position),"radius":number(raw.get("radius"),65,1,100),"t":number(raw.get("t"),1.6,0,2),"duration":number(raw.get("duration"),1.6,0.1,2),"damage":number(raw.get("damage"),16,1,30)})
	items = data.get("drones",[])
	if items is Array:
		for raw in items.slice(0,3):
			if not raw is Dictionary or not str(raw.get("id","")).begins_with("boss:drone:"): continue
			drones.append({"id":str(raw.id),"p":point(raw.get("p"),position),"hp":number(raw.get("hp"),180,0,180),"fire":number(raw.get("fire"),1,0,2)})
