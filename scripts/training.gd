extends Control
const CONTENT = preload("res://scripts/production_art.gd")
const MECH_ART = preload("res://scripts/mech_art.gd")
const PILOT = preload("res://scripts/pilot_runtime.gd")
var pilot_runtime = PILOT.new()
var previous_origin := Vector2.ZERO
const DEFENSE = preload("res://scripts/defense_runtime.gd")
const HOSTILE = preload("res://scripts/hostile_attacks.gd")
var defense = DEFENSE.new()
var hostile = HOSTILE.new()
var energy: float = 25
var skills: int = 0
var dragging: bool = false
var manual_control: bool = false
var retreated: bool = false
var target_id: String = ""
const TACTICS = preload("res://scripts/tactics.gd")
var tactical = TACTICS.new()
var policy: Dictionary = {}
const ATTACK_VISUALS = preload("res://scripts/attack_visuals.gd")
const ENGINE = preload("res://scripts/attack_system.gd")
const RIG = preload("res://scripts/rig_runtime.gd")
var rig = RIG.new()
var profiles: Array = []
var configuration: Dictionary = {}
const FONT = preload("res://assets/fonts/NotoSansSC.otf")
var engine = ENGINE.new()
var units: Array = []
var elapsed: float = 0
var clock: float = 0
var burst_clock: float = 0
var pending: int = 0
var incoming: float = 0
var scenario: int = 0
var profile: Dictionary = {}
var origin := Vector2(90,220)
var mech_motion = preload("res://scripts/mech_motion.gd").new()
var visual_loadout: Dictionary = {}
var field_feedback = preload("res://scripts/field_feedback.gd").new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	profiles = State.weapon_profiles().duplicate(true)
	configuration = State.mech_configuration().duplicate(true)
	policy = State.movement_tactics()
	profile = {"pilot":State.selected,"attack":State.total_attack(),"stats":State.equipment_stats().duplicate(true),"barrier":State.parts.has_trait(State.selected_mech,"barrier"),"nanite":State.parts.has_trait(State.selected_mech,"nanite"),"auto_skill":State.auto_skill,"ion":State.parts.equipped(State.selected_mech,3).get("mechanism","")=="ion","skill_damage":State.total_attack()*5,"armor_id":State.parts.equipped(State.selected_mech,1).get("id",0),"guard_slot":0 if State.weapon_mode(0)=="hand_shield" else 4}
	profile["mech_model"] = int(State.mechs.units[State.selected_mech].model)
	visual_loadout = MECH_ART.appearance()
	profile["visual_parts"] = [int(State.parts.equipped(State.selected_mech,0).get("blueprint",0)),int(State.parts.equipped(State.selected_mech,4).get("blueprint",0))]
	reset(scenario)

func reset(kind: int) -> void:
	scenario = kind
	elapsed = 0; clock = 0; pending = 0; incoming = 0
	manual_control = false; retreated = false; target_id = ""; tactical.reset()
	mech_motion = preload("res://scripts/mech_motion.gd").new()
	field_feedback = preload("res://scripts/field_feedback.gd").new()
	pilot_runtime = PILOT.new()
	rig = RIG.new()
	defense = DEFENSE.new()
	defense.configure(profile.stats,true)
	hostile = HOSTILE.new(); energy = 25; skills = 0
	origin = Vector2(90,220); previous_origin = origin
	engine.reset()
	units = [{"id":"main","p":Vector2(380,220),"hp":240 if kind==2 else 100000000,"max":240 if kind==2 else 100000000,"respawn":0.0,"fire":0.6,"elite":false}]
	if kind>0:
		for i in range(5): units.append({"id":"group%d"%i,"p":Vector2(430+(i%2)*65,155+i*45),"hp":240 if kind==2 else 100000000,"max":240 if kind==2 else 100000000,"elite":i==4,"respawn":0.0,"fire":0.6})

func attack_targets() -> Array: return units.filter(func(unit): return unit.hp>0)
func line_clear(_a: Vector2,_b: Vector2) -> bool: return true
func cell_at(p: Vector2) -> Vector2i: return Vector2i(p/128)
func is_obstacle(_cell: Vector2i) -> bool: return false
func apply_projectile_hit(id: String, damage: int, _mode: String, _point: Vector2) -> bool:
	for unit in units:
		if unit.id==id and unit.hp>0:
			unit.hp -= damage
			if unit.hp<=0: unit.respawn = 3.0
			return true
	return false

func apply_attack_event(event: Dictionary) -> float:
	for unit in units:
		if unit.id==event.target and unit.hp>0:
			var factor: float = pilot_runtime.multiplier(event)
			var amount := maxi(1,int(round(event.damage*factor)))
			var actual := minf(unit.hp,amount)
			apply_projectile_hit(event.target,amount,event.mode,event.point)
			field_feedback.push("destroy" if unit.hp<=0 else "hit",event.point)
			pilot_runtime.record_hit(event,actual,factor)
			return actual
	return 0

func fire(weapon: Dictionary) -> void:
	var critical: bool = randf()*100<profile.stats.crit
	var targets := attack_targets()
	if targets.is_empty(): return
	var target := tactical.select_target(origin,targets.filter(func(unit): return origin.distance_to(unit.p)<=weapon.range),policy)
	if target.is_empty(): return
	var meta := weapon.duplicate(true)
	meta.target_id = target.id
	if weapon.mechanism=="swarm": meta.candidates = targets
	engine.launch(origin,target.p,maxi(1,int((weapon.attack+randi_range(0,8))*weapon.multiplier*(2 if critical else 1))),weapon.mode,weapon.mechanism,weapon.id,meta)

func _process(delta: float) -> void:
	if elapsed>=30 or defense.hp<=0 or retreated: return
	delta = minf(delta,30-elapsed)
	elapsed += delta
	mech_motion.advance(delta,(origin-previous_origin)/maxf(delta,0.001),int(profile.mech_model),str(visual_loadout.drive),false,guard_direction())
	field_feedback.advance(delta)
	for foot in mech_motion.take_contacts(): field_feedback.push("step",origin+Vector2(foot*12,20),origin-previous_origin)
	var manually_moved: bool = origin.distance_to(previous_origin)>0.01
	pilot_runtime.advance(delta,profile.pilot,rig,defense,manually_moved,true)
	previous_origin = origin
	var cooling_config := configuration.duplicate()
	cooling_config.cooling += pilot_runtime.cooling_bonus(profile.pilot,rig.heat)
	var granted := rig.cool(delta,cooling_config)
	if granted>0:
		defense.grant_temporary(granted,3); engine.stats.triggers += 1
		field_feedback.push("vent",origin)
	if tactical.update_survival(defense.hp,defense.total_shield(),defense.max_shield,policy) and not manual_control:
		retreated = true; queue_redraw(); return
	if scenario==2:
		for unit in units:
			if unit.hp<=0:
				unit.respawn -= delta
				if unit.respawn<=0: unit.hp = 240; unit.fire = 0.6
				continue
			if unit.p.distance_to(origin)>185: unit.p = unit.p.move_toward(origin,delta*55)
			unit.fire -= delta
			if unit.fire<=0 and unit.p.distance_to(origin)<330:
				unit.fire = 1.2
				hostile.launch(unit.p,origin,8)
	hostile.advance(self,delta)
	if defense.hp<=0: queue_redraw(); return
	engine.advance(self,delta)
	defense.advance(delta,profile.stats,profile.nanite)
	var targets := attack_targets()
	if not targets.is_empty():
		var range_value: float = 0
		for weapon in profiles:
			if not weapon.is_empty(): range_value = maxf(range_value,weapon.range)
		var available := targets.filter(func(unit): return origin.distance_to(unit.p)<=range_value)
		var target := tactical.select_target(origin,available if not available.is_empty() else targets,policy)
		target_id = target.id
		var before := origin
		if not manual_control:
			var warnings: Array = TACTICS.projectile_warnings(origin,hostile.projectiles)
			var goal := tactical.destination(origin,target.p,policy,preload("res://scripts/melee.gd").engagement_range(profiles),warnings,bool(policy.orbit),func(point): return point.clamp(Vector2(30,150),Vector2(580,380)),func(_point): return true)
			origin = origin.move_toward(goal,configuration.base_speed*configuration.speed_factor*(1+profile.stats.speed/100.0)*delta)
		configuration.pilot_heat_factor = pilot_runtime.heat_factor(profile.pilot)
		var moving: bool = origin.distance_to(before)>0.01 or (manual_control and manually_moved)
		configuration.moving = moving
		rig.advance(delta,profiles,origin.distance_to(target.p),target.id,configuration,fire,policy)
		energy = minf(100,energy+delta*(4.5+profile.stats.energy+pilot_runtime.energy_bonus(profile.pilot)))
		var danger: bool = defense.hp<=50 or tactical.shield_retreat
		for shot in hostile.projectiles:
			if origin.distance_to(shot.p)<120: danger = true
		var elite: bool = available.any(func(unit): return unit.get("elite",false))
		if profile.auto_skill and energy>=100 and tactical.skill_allowed(policy,elite,danger):
			if pilot_runtime.use(profile.pilot,self,origin,target,rig,defense,profile.attack,profile.ion):
				energy = 0; skills += 1
	queue_redraw()

func _draw() -> void:
	CONTENT.draw(self,"hangar",0,Rect2(Vector2.ZERO,size),Color(0.65,0.7,0.8),false)
	var model: int = int(profile.get("mech_model",0))
	var pose: Dictionary = mech_motion.pose()
	pose.ready_slots = {0:0.0,4:0.0}
	for unit in units:
		if unit.id==target_id and unit.hp>0:
			pose.aim_point = (unit.p-origin+Vector2(0,31))/0.43
			if not retreated and defense.hp>0:
				for weapon_profile in profiles:
					if not weapon_profile.is_empty(): pose.ready_slots[int(weapon_profile.slot)] = float(origin.distance_to(unit.p)<=float(weapon_profile.range)+32)
				for held in visual_loadout.get("weapons",[]):
					if held.mode=="hand_shield": pose.ready_slots[int(held.slot)] = 1.0
	MECH_ART.render(self,origin-Vector2(0,31),0.43,MECH_ART.COLORS[model],false,elapsed,pose,visual_loadout,engine,guard_direction(),defense)
	if defense.max_guard>0: preload("res://scripts/hand_shield.gd").render_guard(self,defense,origin,1.0)
	for unit in units:
		if unit.hp<=0: continue
		CONTENT.enemy(self,unit.p,"cannon" if unit.id=="main" else "rusher" if unit.get("elite",false) else "guard",unit.get("elite",false),0.8,true,unit.id,unit.p.direction_to(origin),scenario==2 and unit.p.distance_to(origin)>185,elapsed)
		if unit.id==target_id: draw_arc(unit.p,27,0,TAU,24,Color("ffd683"),2,true)
		if unit.get("elite",false): draw_string(FONT,unit.p+Vector2(-20,-27),"精英",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ff7979"))
	pilot_runtime.render(self,origin,attack_targets(),func(point): return point,1,profile.pilot)
	var muzzle := func(slot): return origin-Vector2(0,31)+MECH_ART.muzzle_offset(model,pose,visual_loadout,engine,guard_direction(),slot,0.43,self)
	ATTACK_VISUALS.render(self,engine,func(point): return point,1,Vector2.ZERO,muzzle,true)
	field_feedback.render(self,func(point): return point,1)
	for unit in attack_targets():
		if unit.id==target_id: rig.render_aim(self,func(point): return point,origin,unit.p,profiles,1)
	for shot in hostile.projectiles: CONTENT.fx(self,"fx-energy",0,shot.p,Vector2(38,16),fmod(elapsed*8,1),shot.direction.angle())
	draw_rect(Rect2(0,0,size.x,150),Color(0.025,0.045,0.065,0.9))
	draw_string(FONT,Vector2(18,30),"%.1f / 30 秒   实测 DPS %.1f" % [elapsed,engine.stats.damage/maxf(elapsed,0.1)],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("8cdec3"))
	draw_string(FONT,Vector2(18,62),"总伤害 %d · 命中 %d · 机制触发 %d · 承伤 %.0f" % [engine.stats.damage,engine.stats.hits,engine.stats.triggers,incoming],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("d3e2eb"))

	draw_string(FONT,Vector2(18,91),"热量 %.0f/100 · 降频 %.1f秒 · 控热停火 %.1f秒 · %s" % [rig.heat,rig.overheated_seconds,rig.hold_seconds,configuration.reason],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ffb66b"))

	draw_string(FONT,Vector2(18,120),"装甲 %.0f · 护盾 %.0f · 吸收 %.0f · 修复 %.0f · 技能 %d%s" % [defense.hp,defense.total_shield(),defense.absorbed,defense.healed,skills," / 损毁" if defense.hp<=0 else ""],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("7ddfff"))
	draw_string(FONT,Vector2(18,143),"战术："+("已安全撤离" if retreated else "手动走位" if manual_control else tactical.status)+" / "+TACTICS.LABELS[policy.heat],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("8cdec3"))

func player_position() -> Vector2: return origin
func player_alive() -> bool: return defense.hp>0 and not retreated
func guard_direction() -> Vector2:
	for unit in units:
		if unit.id==target_id and unit.hp>0 and origin.distance_squared_to(unit.p)>0.01:
			defense.guard_facing = origin.direction_to(unit.p)
	return defense.guard_facing
func receive_directed_hit(damage: int, incoming_direction: Vector2) -> bool:
	return receive_hostile_hit(damage,{"incoming":incoming_direction,"facing":guard_direction()})
func receive_hostile_hit(damage: int, contact: Dictionary = {}) -> bool:
	if defense.hp<=0 or retreated: return false
	var temporary_before: float = defense.temporary_shield
	incoming += defense.hit(damage,profile.stats,profile.barrier,contact)
	field_feedback.push("hit",origin)
	engine.flashes.append({"kind":"impact","p":origin,"t":0.18,"life":0.18})
	if engine.flashes.size()>96: engine.flashes.pop_front()
	pilot_runtime.after_hit(profile.pilot,defense,temporary_before-defense.temporary_shield)
	if defense.counter_ready:
		defense.counter_ready = false
		engine.counter(self,origin,maxi(1,int(profile.skill_damage/5.0*0.7)),int(profile.get("armor_id",0)))
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		dragging = event.pressed
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	if dragging: manual_control = true
	if dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion or event is InputEventScreenTouch):
		origin = event.position.clamp(Vector2(30,150),Vector2(580,380))
		accept_event()
