extends RefCounted
const ENGINE = preload("res://scripts/attack_system.gd")
const MELEE = preload("res://scripts/melee.gd")

class Arena extends Node:
	var origin := Vector2.ZERO
	var alive := true
	var blocked := false
	var units: Array = []
	var events: Array = []
	func player_position() -> Vector2: return origin
	func player_alive() -> bool: return alive
	func attack_targets() -> Array: return units.filter(func(unit): return unit.hp>0)
	func line_clear(_a: Vector2,_b: Vector2) -> bool: return not blocked
	func cell_at(point: Vector2) -> Vector2i: return Vector2i(point/32)
	func is_obstacle(_cell: Vector2i) -> bool: return false
	func apply_attack_event(event: Dictionary) -> float:
		for unit in units:
			if unit.id!=event.target or unit.hp<=0: continue
			var actual := minf(unit.hp,event.damage)
			unit.hp -= actual; events.append(event.duplicate(true))
			return actual
		return 0.0

func target(id: String, point: Vector2) -> Dictionary:
	return {"id":id,"p":point,"hp":10000.0}

func run(check: Callable, main: Node) -> void:
	var arena := Arena.new()
	var engine = ENGINE.new()
	arena.units = [target("front",Vector2(90,0)),target("side",Vector2(0,70)),target("behind",Vector2(-60,0)),target("far",Vector2(121,0))]
	engine.launch(Vector2.ZERO,Vector2(90,0),100,"blade","",7,{"slot":0})
	check.call(engine.projectiles.is_empty() and engine.swings.size()==1 and arena.events.is_empty(),"melee creates a committed swing without a projectile or immediate damage")
	engine.advance(arena,0.16)
	check.call(arena.events.is_empty(),"blade windup cannot damage targets before the active window")
	engine.advance(arena,0.08)
	check.call(arena.events.size()==1 and arena.events[0].target=="front","blade hits only real targets inside its reach and facing cone")
	engine.advance(arena,1)
	check.call(arena.events.size()==1 and engine.swings.is_empty(),"one swing cannot repeatedly hit the same target during active frames or recovery")
	check.call(engine.stats.by_kind.melee==100 and engine.stats.by_slot['0']==100 and engine.stats.by_weapon['7']==100 and engine.stats.by_type.thermal==100 and arena.events[0].tags==["melee"],"melee damage records its own attack kind, hand, weapon and damage composition")
	engine.reset(); arena.events.clear(); arena.units = []
	for i in range(6): arena.units.append(target("front%d"%i,Vector2(50+i*8,0)))
	engine.launch(Vector2.ZERO,Vector2(90,0),100,"blade","")
	engine.advance(arena,0.35)
	check.call(arena.events.size()==4,"a blade cleave respects its four-target cap")
	engine.reset(); arena.events.clear(); arena.units = [target("moving",Vector2(90,0))]
	engine.launch(Vector2.ZERO,Vector2(90,0),100,"blade","")
	engine.advance(arena,0.12); arena.units[0].p = Vector2(180,0)
	engine.advance(arena,0.3)
	check.call(arena.events.is_empty(),"moving outside melee reach during windup causes a real miss")
	engine.reset(); arena.events.clear(); arena.units[0].p = Vector2(90,0); arena.blocked = true
	engine.launch(Vector2.ZERO,Vector2(90,0),100,"blade",""); engine.advance(arena,0.4)
	check.call(arena.events.is_empty(),"terrain and cover block melee contact")
	arena.blocked = false; engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(90,0),100,"blade","")
	arena.origin = Vector2(-120,0); engine.advance(arena,0.4)
	check.call(arena.events.is_empty(),"melee hit tests follow the attacker's real position while moving")
	arena.origin = Vector2.ZERO; engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(90,0),100,"blade","")
	arena.alive = false; engine.advance(arena,0.4)
	check.call(arena.events.is_empty() and engine.swings.is_empty(),"destruction or recall cancels pending melee damage")
	arena.alive = true; engine.reset(); arena.events.clear(); arena.units = [target("combo",Vector2(70,0))]
	engine.launch(Vector2.ZERO,Vector2(70,0),100,"gauntlet","",8,{"slot":4})
	engine.advance(arena,0.62)
	var coefficient := 0.0
	for event in arena.events: coefficient += float(event.trigger_coefficient)
	check.call(arena.events.size()==3 and engine.stats.damage==300 and is_equal_approx(coefficient,1.0),"gauntlets deliver three timed contacts with a bounded combined proc coefficient")
	engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(70,0),100,"gauntlet","")
	engine.advance(arena,0.16); arena.units[0].p = Vector2(160,0); engine.advance(arena,0.5)
	check.call(arena.events.size()==1,"leaving the fist path avoids later combo hits instead of locking in all three")
	engine.reset(); arena.events.clear(); arena.units = [target("heavy",Vector2(95,0))]
	engine.launch(Vector2.ZERO,Vector2(95,0),280,"hammer","")
	engine.advance(arena,0.34)
	check.call(arena.events.is_empty(),"heavy hammer keeps its longer committed windup")
	engine.advance(arena,0.08)
	check.call(arena.events.size()==1 and engine.stats.damage==280,"hammer applies one heavy hit inside its actual active window")
	engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(95,0),100,"blade","ion",9,{"slot":0})
	engine.advance(arena,0.3)
	check.call(arena.events.size()==1 and arena.events[0].components.thermal==60 and arena.events[0].components.electric==40 and engine.stats.damage==100,"ion-compatible melee converts damage without adding a second damage budget")
	arena.free()
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	World.enabled = false; World.docked = true
	State.selected_mech = 0; State.selected = 0; State.recovery = 0
	State.sound_enabled = false; State.auto_skill = false
	State.parts = State.PARTS.new(); State.parts.starter()
	State.credits = 10000; State.cores = 1000
	State.expedition = State.EXPEDITION.new()
	var weapons: Array = []
	for blueprint in State.PARTS.MELEE_BLUEPRINTS:
		var part: Dictionary = State.craft_part(blueprint)
		part.affixes = []; part.mechanism = ""
		weapons.append(part)
		check.call(not part.is_empty() and State.parts.mechanism_pool(blueprint).all(func(id): return id in ["ion","hot_drive"]),"melee blueprint %d is craftable without projectile-only mechanisms" % blueprint)
	check.call(State.credits==8650 and State.cores==955 and not main.manufacturing_ui.unlocked(17),"new basic melee models keep old named-blueprint locks and normal crafting costs")
	State.unequip_part(4); State.equip_part(weapons[1].id,0)
	check.call(State.attack_range()==84 and State.engagement_range()==84 and State.weapon_profile(4).is_empty(),"an empty second hand cannot give a melee-only build phantom ranged reach")
	State.equip_part(5,4)
	check.call(State.attack_range()==390 and State.engagement_range()==84,"mixed gun and fist builds retain ranged fire while choosing a melee engagement distance")
	var policy: Dictionary = State.TACTICS.defaults()
	policy.distance = "far"
	var controller = State.TACTICS.new()
	check.call(controller.desired_distance(policy,State.engagement_range())+25<State.weapon_range(0),"automatic melee positioning leaves enough arrival tolerance to enter fist range")
	State.set_tactic("distance","melee")
	var saved: Dictionary = State.save_payload().duplicate(true)
	State.import_game(saved)
	check.call(State.parts.export_save()==saved.parts and State.active_tactics().distance=="melee","new weapon IDs, hand assignments and melee policy survive save import without renumbering older parts")
	State.rig.heat = 0; State.rig.overheated = false; State.rig.cooling_hold = false
	var training = load("res://scripts/training.gd").new()
	main.add_child(training); training.set_process(false)
	for _i in range(200): training._process(0.05)
	check.call(training.engine.stats.by_kind.get("melee",0)>0 and training.engine.stats.by_mode.get("rail",0)>0,"real training closes to melee range and records both fist contacts and ranged shots")
	training.free()
	State.levels = [5,5,1]; State.unlocked = [true,true,false]
	State.unequip_part(4)
	State.import_tactics({}); State.pilot_runtime = State.PILOT_RUNTIME.new()
	var simulator = load("res://scripts/certification.gd")
	for weapon in weapons:
		State.equip_part(weapon.id,0)
		var job = simulator.new(simulator.capture(State),0)
		for _batch in range(200):
			if job.done: break
			job.advance(1000)
		check.call(job.done and job.success and job.trials.size()==3,"melee-only %s completes three real automatic certification cleanups" % State.parts.name_of(weapon))
		job.dispose()
	main.show_page(1); main.show_parts(); main.show_manufacturing(); main.show_tactics(); main.show_training()
	main.close_modal()
	State.import_game(original); World.enabled = enabled
