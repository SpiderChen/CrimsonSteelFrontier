extends RefCounted
## One authoritative event stream drives collision, damage composition, visuals and telemetry.
const MAX_PROJECTILES = 128
const MAX_DEPTH = 1
const MELEE = preload("res://scripts/melee.gd")
var projectiles: Array = []
var swings: Array = []
var beams: Array = []
var zones: Array = []
var effects: Array = []
var flashes: Array = []
var wakes: Array = []
var visual_time: float = 0.0
var next_id: int = 1
var stats: Dictionary = fresh_stats()
static func fresh_stats() -> Dictionary:
	return {"fired":0,"hits":0,"damage":0.0,"triggers":0,"by_weapon":{},"by_slot":{},"by_mode":{},"by_type":{},"by_kind":{}}
func reset() -> void:
	projectiles.clear(); swings.clear(); beams.clear(); zones.clear(); effects.clear(); flashes.clear(); wakes.clear(); visual_time = 0; stats = fresh_stats()

func launch(origin: Vector2, target: Vector2, damage: int, mode: String, mechanism: String, weapon: int = 0, metadata: Dictionary = {}) -> void:
	var direction := origin.direction_to(target)
	if direction==Vector2.ZERO: direction = Vector2.RIGHT
	if not MELEE.is_mode(mode):
		flashes.append({"kind":"muzzle","p":origin,"angle":direction.angle(),"t":0.14,"life":0.14,"mode":mode,"slot":metadata.get("slot",-1)})
		if flashes.size()>96: flashes.pop_front()
	var meta := metadata.duplicate(true)
	meta.weapon = weapon; meta.mode = mode; meta.mechanism = mechanism; meta.original_damage = damage
	meta.visual_angle = direction.angle()
	meta.base_type = metadata.get("base_type","electric" if mode=="rail" else "thermal" if mode in ["laser","pulse","missile","plasma"] else "kinetic")
	stats.fired += 1
	if bool(meta.get("hot_active",false)): stats.triggers += 1
	if MELEE.is_mode(mode):
		if swings.size()>=8: return
		var rule: Dictionary = MELEE.RULES[mode]
		meta.base_type = rule.type
		var visited: Array = []
		for _time in rule.timings: visited.append([])
		swings.append({"from":origin,"direction":direction,"mode":mode,"damage":damage,"meta":meta,"age":0.0,"visited":visited,"active":false,"stage":0})
		return
	if mode in ["laser","pulse"]:
		if beams.size()>=8: return
		beams = beams.filter(func(b): return int(b.meta.weapon)!=weapon)
		beams.append({"from":origin,"end":origin,"aim":target,"direction":direction,"meta":meta,"damage":damage,"age":0.0,"next_tick":0.22 if mode=="pulse" else 0.0,"duration":0.42 if mode=="pulse" else 0.75,"lit":false})
		if mechanism in ["pulse","sweep"]: stats.triggers += 1
		return
	var budget := 0.8 if mechanism=="bounce" else 0.7 if mechanism=="split" else 0.85 if mechanism=="proximity" else 0.65 if mechanism=="incendiary" else 0.9 if mechanism=="swarm" else 1.0
	if mechanism=="swarm" and mode=="missile":
		var alternatives: Array = meta.get("candidates",[]).filter(func(t): return t.p.distance_to(target)<=220)
		alternatives.sort_custom(func(a,b): return a.p.distance_squared_to(target)<b.p.distance_squared_to(target))
		meta.erase("candidates")
		var total := maxi(1,int(damage*budget))
		var count := mini(4,total)
		for i in range(count):
			var amount := int(total/count)+(1 if i<total%count else 0)
			var child_meta: Dictionary = meta.duplicate(true)
			if not alternatives.is_empty(): child_meta.target_id = alternatives[i%mini(count,alternatives.size())].id
			spawn(origin+direction.orthogonal()*(i-(count-1)/2.0)*7,direction.rotated((i-(count-1)/2.0)*0.18),amount,mode,mechanism,weapon,0,[],0,child_meta)
		stats.triggers += 1
	else: spawn(origin,direction,maxi(1,int(damage*budget)),mode,mechanism,weapon,0,[],3,meta)

func spawn(origin: Vector2, direction: Vector2, damage: int, mode: String, mechanism: String, weapon: int, depth: int, visited: Array, remaining: int, metadata: Dictionary = {}) -> void:
	if projectiles.size()>=MAX_PROJECTILES or depth>MAX_DEPTH: return
	var meta := metadata.duplicate(true)
	meta.weapon = weapon; meta.mode = mode; meta.mechanism = mechanism; meta.depth = depth
	meta.trigger_coefficient = (0.333333 if mode=="burst" else 0.25 if mechanism=="swarm" else 1.0)*(0.5 if depth>0 else 1.0)
	projectiles.append({"id":next_id,"p":origin,"previous":origin,"direction":direction,"damage":damage,"mode":mode,"mechanism":mechanism,"weapon":weapon,"depth":depth,"visited":visited.duplicate(),"remaining":remaining,"distance":0.0,"trigger_coefficient":(0.333333 if mode=="burst" else 0.25 if mechanism=="swarm" else 1.0)*(0.5 if depth>0 else 1.0),"tags":["missile" if mode=="missile" else "projectile"],"alive":true,"meta":meta})
	next_id += 1
	projectiles.back().trail = [origin]

func deal(world: Node, target: Dictionary, damage: int, metadata: Dictionary, kind: String = "direct", coefficient: float = 1.0) -> float:
	var components: Dictionary = {}
	var base: String = metadata.get("base_type","kinetic")
	components[base] = float(damage)
	var converted: bool = (metadata.get("mechanism","")=="ion" or bool(metadata.get("ion",false))) and base!="electric"
	if converted:
		components[base] = damage*0.6; components.electric = damage*0.4
	var event := {"target":target.id,"point":target.p,"damage":damage,"components":components,"weapon":metadata.get("weapon",0),"slot":metadata.get("slot",-1),"mode":metadata.get("mode","standard"),"kind":kind,"depth":metadata.get("depth",0),"trigger_coefficient":coefficient,"tags":["melee" if kind=="melee" else "beam" if metadata.get("mode","") in ["laser","pulse"] else "missile" if metadata.get("mode","")=="missile" else "projectile"]}
	var result = world.apply_attack_event(event) if world.has_method("apply_attack_event") else world.apply_projectile_hit(target.id,damage,event.mode,target.p)
	if not result: return 0
	flashes.append({"kind":"impact","p":target.p,"angle":metadata.get("visual_angle",0.0),"t":0.18,"life":0.18,"mode":metadata.get("mode","standard")})
	if flashes.size()>96: flashes.pop_front()
	var actual: float = float(result) if result is float or result is int else float(damage)
	if converted: stats.triggers += 1
	stats.hits += 1; stats.damage += actual
	for group in ["weapon","slot","mode","kind"]:
		var key := str(event[group])
		stats["by_"+group][key] = float(stats["by_"+group].get(key,0))+actual
	var resolved: Dictionary = event.get("resolved_components",components)
	var total: float = 0
	for type in resolved: total += float(resolved[type])
	for type in resolved: stats.by_type[type] = float(stats.by_type.get(type,0))+actual*float(resolved[type])/maxf(0.00001,total)
	return actual

func blast(world: Node, center: Vector2, damage: int, metadata: Dictionary, radius: float, primary: String = "") -> void:
	effects.append({"ion":bool(metadata.get("ion",false)) or metadata.get("mechanism","")=="ion","p":center,"radius":radius,"t":0.35,"mode":metadata.get("mode","missile")})
	if effects.size()>48: effects.pop_front()
	for target in world.attack_targets():
		if target.p.distance_to(center)>radius or not world.line_clear(center,target.p): continue
		var amount := damage if primary=="" or target.id==primary else maxi(1,int(damage*0.35))
		deal(world,target,amount,metadata,"explosion",float(metadata.get("trigger_coefficient",1.0))*(1.0 if primary=="" or target.id==primary else 0.35))

func counter(world: Node, center: Vector2, damage: int, weapon: int) -> void:
	stats.triggers += 1
	blast(world,center,damage,{"weapon":weapon,"slot":1,"mode":"counter","base_type":"kinetic","depth":1},210)

func burn(center: Vector2, damage: int, metadata: Dictionary) -> void:
	if zones.size()>=16: return
	var meta := metadata.duplicate(true)
	meta.base_type = "thermal"; meta.depth = 1
	var budget := maxi(0,int(meta.get("original_damage",damage))-damage)
	if budget<=0: return
	zones.append({"p":center,"radius":85.0,"remaining":6,"clock":0.5,"budget":budget,"damage":ceili(budget/6.0),"meta":meta})
	stats.triggers += 1

func advance(world: Node, delta: float) -> void:
	var remaining := minf(delta,2.0)
	visual_time += maxf(0,remaining)
	while remaining>0:
		var step := minf(remaining,0.02); remaining -= step
		for effect in effects: effect.t -= step
		effects = effects.filter(func(e): return e.t>0)
		for flash in flashes: flash.t -= step
		flashes = flashes.filter(func(f): return f.t>0)
		for wake in wakes: wake.t -= step
		wakes = wakes.filter(func(w): return w.t>0)
		advance_beams(world,step)
		advance_melee(world,step)
		for zone in zones:
			zone.clock -= step
			if zone.clock<=0 and zone.remaining>0:
				zone.clock += 0.5; zone.remaining -= 1
				var amount := mini(zone.damage,zone.budget)
				zone.budget -= amount
				if amount>0:
					for target in world.attack_targets():
						if target.p.distance_to(zone.p)<=zone.radius and world.line_clear(zone.p,target.p): deal(world,target,amount,zone.meta,"burn",1.0/6)
		zones = zones.filter(func(z): return z.remaining>0)
		var targets: Array = world.attack_targets()
		var batch := projectiles.duplicate()
		for projectile in batch:
			if not projectile.alive: continue
			if projectile.mode=="missile":
				for target in targets:
					if target.id==projectile.meta.get("target_id",""):
						var desired: Vector2 = projectile.p.direction_to(target.p)
						projectile.direction = projectile.direction.rotated(clampf(projectile.direction.angle_to(desired),-step*4,step*4))
						break
			var speed := 1800.0 if projectile.mode=="rail" else 720.0 if projectile.mode=="plasma" else 340.0 if projectile.mode=="missile" else 1050.0
			var before: Vector2 = projectile.p
			var after: Vector2 = before+projectile.direction*speed*step
			projectile.previous = before
			projectile.meta.visual_angle = projectile.direction.angle()
			if not world.line_clear(before,after) or world.is_obstacle(world.cell_at(after)):
				retain_wake(projectile)
				projectile.alive = false; continue
			var candidates: Array = []
			for target in targets:
				if target.id in projectile.visited: continue
				var nearest := Geometry2D.get_closest_point_to_segment(target.p,before,after)
				if nearest.distance_to(target.p)<=(50 if projectile.mechanism=="proximity" else 22): candidates.append({"id":target.id,"p":target.p,"along":before.distance_squared_to(nearest)})
			candidates.sort_custom(func(a,b): return a.along<b.along)
			for target in candidates:
				if not projectile.alive: break
				projectile.visited.append(target.id)
				if projectile.mode=="missile":
					if projectile.mechanism=="proximity": stats.triggers += 1
					blast(world,after,projectile.damage,projectile.meta,110 if projectile.mechanism=="proximity" else 80,target.id)
					if projectile.mechanism=="incendiary": burn(after,projectile.damage,projectile.meta)
					projectile.alive = false; break
				if deal(world,target,projectile.damage,projectile.meta,"direct",projectile.trigger_coefficient)<=0: continue
				if projectile.mode=="plasma":
					effects.append({"ion":projectile.mechanism=="ion","p":target.p,"radius":150.0,"t":0.35,"mode":"plasma"})
					if effects.size()>48: effects.pop_front()
					for secondary in world.attack_targets():
						if secondary.id!=target.id and secondary.p.distance_to(target.p)<=150 and world.line_clear(target.p,secondary.p): deal(world,secondary,maxi(1,int(projectile.damage*0.5)),projectile.meta,"explosion",0.5)
					if projectile.mechanism=="incendiary": burn(target.p,projectile.damage,projectile.meta)
				if projectile.mechanism=="pierce" and projectile.remaining>0:
					projectile.remaining -= 1; projectile.damage = maxi(1,int(projectile.damage*0.7)); stats.triggers += 1
				elif projectile.mechanism=="bounce" and projectile.remaining>0:
					var next: Dictionary = {}; var closest := 180.0
					for secondary in world.attack_targets():
						var distance: float = secondary.p.distance_to(target.p)
						if secondary.id not in projectile.visited and distance<closest and world.line_clear(target.p,secondary.p): next = secondary; closest = distance
					if not next.is_empty():
						projectile.direction = target.p.direction_to(next.p); after = target.p
						projectile.damage = maxi(1,int(projectile.damage*0.75)); projectile.remaining -= 1; stats.triggers += 1
					else: projectile.alive = false
					break
				elif projectile.mechanism=="split" and projectile.depth<MAX_DEPTH:
					for angle in [-0.5,0.5]: spawn(target.p,projectile.direction.rotated(angle),maxi(1,int(projectile.damage*0.3)),projectile.mode,"",projectile.weapon,projectile.depth+1,projectile.visited,0,projectile.meta)
					stats.triggers += 1; projectile.alive = false
				else: projectile.alive = false
			projectile.p = after; projectile.distance += before.distance_to(after)
			if after.distance_to(projectile.trail.back())>=12:
				projectile.trail.append(after)
				if projectile.trail.size()>(9 if projectile.mode=="missile" else 12): projectile.trail.pop_front()
			if projectile.distance>900: projectile.alive = false
			if not projectile.alive: retain_wake(projectile)
		projectiles = projectiles.filter(func(p): return p.alive)

func retain_wake(projectile: Dictionary) -> void:
	if projectile.mode!="rail" or projectile.trail.size()<2: return
	wakes.append({"points":projectile.trail.duplicate(),"mode":"rail","t":0.18})
	if wakes.size()>32: wakes.pop_front()

func advance_melee(world: Node, step: float) -> void:
	if world.has_method("player_alive") and not world.player_alive():
		swings.clear()
		return
	for swing in swings:
		var rule: Dictionary = MELEE.RULES[swing.mode]
		swing.age += step
		swing.active = false
		if world.has_method("player_position"): swing.from = world.player_position()
		for stage in range(rule.timings.size()):
			if swing.age+0.000001<float(rule.timings[stage]) or swing.age>=float(rule.timings[stage])+float(rule.window): continue
			swing.active = true; swing.stage = stage
			var candidates: Array = world.attack_targets().filter(func(target): return target.id not in swing.visited[stage])
			candidates.sort_custom(func(a,b): return swing.from.distance_squared_to(a.p)<swing.from.distance_squared_to(b.p))
			for target in candidates:
				if swing.visited[stage].size()>=int(rule.targets): break
				var offset: Vector2 = target.p-swing.from
				if offset.length()>float(rule.range) or (offset.length_squared()>0.001 and absf(swing.direction.angle_to(offset.normalized()))>float(rule.arc)*0.5): continue
				if not world.line_clear(swing.from,target.p): continue
				if deal(world,target,swing.damage,swing.meta,"melee",1.0/rule.timings.size())>0:
					swing.visited[stage].append(target.id)
				if world.has_method("player_alive") and not world.player_alive(): break
	swings = swings.filter(func(swing): return swing.age<float(MELEE.RULES[swing.mode].duration))

func advance_beams(world: Node, step: float) -> void:
	for beam in beams:
		beam.age += step
		if beam.meta.mode=="pulse" and beam.next_tick>50: continue
		if world.has_method("player_position"): beam.from = world.player_position()
		var targets: Array = world.attack_targets()
		var locked: String = beam.meta.get("target_id","")
		for target in targets:
			if target.id==locked: beam.aim = target.p
		var direction: Vector2 = beam.from.direction_to(beam.aim)
		beam.meta.visual_angle = direction.angle()
		if beam.meta.mechanism=="sweep": direction = direction.rotated(-0.35+0.7*beam.age/beam.duration)
		var end: Vector2 = beam.from+direction*float(beam.meta.get("range",350))
		for i in range(1,ceili(beam.from.distance_to(end)/8)+1):
			var point: Vector2 = beam.from+direction*i*8
			if world.is_obstacle(world.cell_at(point)):
				end = point-direction*8; break
		var nearest: Dictionary = {}; var closest: float = beam.from.distance_to(end)+1
		for target in targets:
			var point := Geometry2D.get_closest_point_to_segment(target.p,beam.from,end)
			if point.distance_to(target.p)<=14 and beam.from.distance_to(point)<closest:
				nearest = target; closest = beam.from.distance_to(point)
		if not nearest.is_empty(): end = nearest.p
		beam.end = end
		beam.lit = beam.meta.mode!="pulse" or beam.age>=0.22
		if beam.lit and beam.age+0.00001>=beam.next_tick and beam.age<=beam.duration:
			beam.next_tick += 100 if beam.meta.mode=="pulse" else 0.1
			if not nearest.is_empty(): deal(world,nearest,beam.damage,beam.meta,"beam",0.125 if beam.meta.mode=="laser" else 1.0)
	beams = beams.filter(func(b): return b.age<b.duration)
