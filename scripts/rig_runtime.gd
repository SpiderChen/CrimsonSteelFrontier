extends RefCounted
## Per-weapon cooldowns share one reactor heat pool; throttling never stops locomotion.
var weapons: Array = [new_weapon(),new_weapon()]
var heat: float = 0
var overheated: bool = false
var vent_cooldown: float = 0
var vent_triggers: int = 0
var overheated_seconds: float = 0
var fired_by_slot: Dictionary = {0:0,4:0}
var cooling_hold: bool = false
var hold_seconds: float = 0
var next_hand: int = 0

static func new_weapon() -> Dictionary:
	return {"clock":0.0,"pending":0,"burst_clock":0.0,"target":"","aim":0.0}

func reset_clocks() -> void:
	weapons = [new_weapon(),new_weapon()]
	next_hand = 0

func render_aim(canvas: CanvasItem, project: Callable, origin: Vector2, target: Vector2, profiles: Array, scale_value: float) -> void:
	for i in range(2):
		if profiles[i].is_empty() or weapons[i].aim<=0: continue
		var mode: String = profiles[i].mode
		if mode not in ["rail","pulse","missile"]: continue
		var color := Color("e9c78e") if mode=="missile" else Color("c7b3ed")
		var progress := clampf(float(weapons[i].aim)/(0.4 if mode=="missile" else 0.65),0,1)
		var point: Vector2 = project.call(target)
		canvas.draw_arc(point,(26+i*6)*scale_value,-PI/2,-PI/2+TAU*progress,40,color,2*scale_value,true)
		if mode!="missile": canvas.draw_dashed_line(project.call(origin),point,Color(color,0.4),scale_value,8*scale_value,true)

func cool(delta: float, configuration: Dictionary) -> float:
	vent_cooldown = maxf(0,vent_cooldown-delta)
	var granted: float = 0
	if bool(configuration.get("vent",false)) and heat>=80 and vent_cooldown<=0:
		heat -= 30; vent_cooldown = 8; vent_triggers += 1; granted = 15
	heat = maxf(0,heat-float(configuration.cooling)*delta)
	if overheated: overheated_seconds += delta
	if cooling_hold: hold_seconds += delta
	if heat<=45: cooling_hold = false
	if heat<=60: overheated = false
	return granted

func add_heat(amount: float) -> void:
	heat = minf(100,heat+maxf(0,amount))
	if heat>=100: overheated = true

static func prepare_shot(profile: Dictionary, current_heat: float, configuration: Dictionary) -> Dictionary:
	var shot: Dictionary = profile.duplicate(true)
	if profile.get("mechanism","")=="hot_drive":
		shot.heat *= 1.3
		if current_heat>=60: shot.attack *= 1.2; shot.hot_active = true
	shot.heat *= float(configuration.get("pilot_heat_factor",1.0))
	return shot

func advance(delta: float, profiles: Array, distance: float, target: String, configuration: Dictionary, fire: Callable, policy: Dictionary = {}) -> void:
	if not configuration.valid:
		reset_clocks()
		return
	var heat_policy: String = policy.get("heat","pressure")
	if heat_policy!="conserve": cooling_hold = false
	elif heat>=80: cooling_hold = true
	elif heat<=45: cooling_hold = false
	var usable: Array = []
	for i in range(2):
		if not profiles[i].is_empty() and distance<=float(profiles[i].range): usable.append(i)
	for i in range(2):
		var profile: Dictionary = profiles[i]
		var weapon: Dictionary = weapons[i]
		if profile.is_empty() or distance>float(profile.range):
			weapon.clock = 0; weapon.pending = 0; weapon.aim = 0; weapon.target = ""
			continue
		# Each hand owns its firing rhythm. Precision weapons charge more slowly
		# while moving; guided missiles track at full speed during movement.
		var moving: bool = configuration.get("moving",false)
		if profile.mode in ["rail","pulse","missile"]:
			if weapon.target!=target: weapon.aim = 0; weapon.target = target
			if profile.mode in ["rail","pulse"] and moving: weapon.aim += delta*0.35
			else: weapon.aim += delta
		var interval: float = float(profile.interval)/(0.35 if overheated else 1.0)
		if profile.mode=="burst" and moving: interval *= 0.75
		if int(weapon.pending)>0:
			if weapon.target!=target:
				weapon.pending = 0
				continue
			weapon.burst_clock -= delta
			if weapon.burst_clock>0: continue
		else:
			weapon.clock += delta
			if weapon.clock<interval: continue
			if profile.mode in ["rail","pulse"] and weapon.aim<0.65: continue
			if profile.mode=="missile" and weapon.aim<0.4: continue
		var shot: Dictionary = prepare_shot(profile,heat,configuration)
		if heat_policy=="conserve" and (cooling_hold or heat+float(shot.heat)>95):
			cooling_hold = true
			continue
		if heat_policy=="alternate" and usable.size()==2 and i!=next_hand: continue
		if int(weapon.pending)>0:
			weapon.pending -= 1
			weapon.burst_clock = 0.12/(0.35 if overheated else 1.0)
		else:
			weapon.clock = 0
			if profile.mode in ["rail","pulse","missile"]: weapon.aim = 0
			if profile.mode=="burst":
				weapon.pending = 2
				weapon.burst_clock = 0.12/(0.35 if overheated else 1.0)
				weapon.target = target
		add_heat(shot.heat)
		if heat_policy=="alternate" and int(weapon.pending)==0: next_hand = 1-i
		fired_by_slot[profile.slot] = int(fired_by_slot.get(profile.slot,0))+1
		fire.call(shot)
