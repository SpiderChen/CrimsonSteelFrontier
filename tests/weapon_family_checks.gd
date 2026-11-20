extends RefCounted
const ENGINE = preload("res://scripts/attack_system.gd")
class Arena extends Node:
	var units: Array = [{"id":"a","p":Vector2(180,0),"hp":100000.0}]
	var events: Array = []
	var wall: bool = false
	func attack_targets() -> Array: return units.filter(func(u): return u.hp>0)
	func player_position() -> Vector2: return Vector2.ZERO
	func line_clear(_a: Vector2,_b: Vector2) -> bool: return true
	func cell_at(p: Vector2) -> Vector2i: return Vector2i(floori(p.x/32),floori(p.y/32))
	func is_obstacle(c: Vector2i) -> bool: return wall and c.x==2
	func apply_attack_event(event: Dictionary) -> float:
		for unit in units:
			if unit.id==event.target and unit.hp>0:
				var actual := minf(unit.hp,event.damage)
				unit.hp -= actual; events.append(event.duplicate(true))
				return actual
		return 0
var fired_attack: float = 0
func capture(profile: Dictionary) -> void: fired_attack = profile.attack
func run(check: Callable) -> void:
	var arena := Arena.new()
	var engine = ENGINE.new()
	engine.launch(Vector2.ZERO,Vector2(180,0),10,"laser","",10,{"slot":0,"range":300,"target_id":"a"})
	check.call(arena.events.is_empty() and engine.beams.size()==1,"continuous laser creates a real channel before any damage is applied")
	engine.advance(arena,0.75)
	check.call(arena.events.size()==8 and engine.stats.damage==80 and engine.stats.by_kind.beam==80,"laser ticks exactly eight times along its actual ray")
	check.call(engine.stats.by_slot['0']==80 and engine.stats.by_weapon['10']==80 and engine.stats.by_type.thermal==80,"damage telemetry attributes the same damage to weapon, hand, type and attack kind")
	engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(180,0),100,"pulse","pulse",10,{"slot":0,"range":300})
	engine.advance(arena,0.2)
	check.call(arena.events.is_empty(),"pulse light-up is a charge period without damage")
	engine.advance(arena,0.3)
	check.call(arena.events.size()==1 and arena.events[0].damage==100,"charged pulse applies a single concentrated hit")
	engine.reset(); arena.events.clear(); arena.wall = true
	engine.launch(Vector2.ZERO,Vector2(180,0),10,"laser","",10,{"range":300})
	engine.advance(arena,0.3)
	check.call(arena.events.is_empty() and engine.beams[0].end.x<=64,"visible beam endpoint and real damage both stop at terrain")
	arena.wall = false; engine.reset(); arena.events.clear()
	arena.units = [{"id":"top","p":Vector2(120,-40),"hp":100000.0},{"id":"bottom","p":Vector2(120,40),"hp":100000.0}]
	engine.launch(Vector2.ZERO,Vector2(180,0),10,"laser","sweep",10,{"range":300})
	engine.advance(arena,0.75)
	var targets: Dictionary = {}
	for event in arena.events: targets[event.target] = true
	check.call(targets.size()==2,"sweep modulation hits both targets only as the moving ray crosses them")
	arena.units = [{"id":"a","p":Vector2(180,0),"hp":100000.0}]
	engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(180,0),100,"missile","",11,{"slot":4,"target_id":"a"})
	engine.advance(arena,0.1); arena.units[0].p = Vector2(180,90)
	engine.advance(arena,1.2)
	check.call(arena.events.size()==1 and engine.stats.damage==100,"missile changes trajectory and intercepts a moving target")
	arena.units[0].p = Vector2(180,0); engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(180,0),100,"missile","swarm",11,{"slot":4,"target_id":"a"})
	var budget := 0
	for shot in engine.projectiles: budget += shot.damage
	check.call(engine.projectiles.size()==4 and budget==90,"four swarm missiles share a ninety-percent total damage budget")
	engine.advance(arena,1.5)
	var coefficient: float = 0
	for event in arena.events: coefficient += event.trigger_coefficient
	check.call(arena.events.size()==4 and engine.stats.damage==90 and is_equal_approx(coefficient,1),"swarm damage and trigger coefficients are distributed across actual missile impacts")
	engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(180,0),1,"missile","swarm",11,{"target_id":"a"})
	budget = 0
	for shot in engine.projectiles: budget += shot.damage
	check.call(budget<=1,"swarm integer rounding cannot multiply very small damage budgets")
	engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(180,0),100,"missile","proximity",11,{"target_id":"a"})
	engine.advance(arena,0.5)
	check.call(engine.effects.size()>0 and engine.effects[0].p.x<158 and engine.effects[0].radius==110 and engine.stats.damage==85 and engine.stats.triggers==1,"proximity missile detonates before contact with its real radius, reduced damage and trigger telemetry")
	engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(180,0),100,"standard","ion",12,{"slot":0})
	engine.advance(arena,0.3)
	check.call(engine.stats.damage==100 and engine.stats.by_type.kinetic==60 and engine.stats.by_type.electric==40 and engine.stats.triggers==1,"ion conversion splits existing damage without duplication and records its effective activation")
	engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(180,0),100,"missile","incendiary",11,{"target_id":"a"})
	engine.advance(arena,0.6)
	check.call(engine.zones.size()==1 and engine.stats.damage==65,"incendiary missile reserves part of its damage for the ground zone")
	engine.advance(arena,2); engine.advance(arena,1)
	check.call(engine.zones.is_empty() and engine.stats.damage==100 and engine.stats.by_kind.burn==35,"burning zone has six finite ticks and preserves the total damage budget")
	engine.reset(); arena.events.clear()
	engine.launch(Vector2.ZERO,Vector2(180,0),100,"missile","incendiary",11,{"target_id":"a"})
	engine.advance(arena,0.6); arena.units[0].p = Vector2(180,200)
	engine.advance(arena,2); engine.advance(arena,1)
	check.call(engine.stats.damage==65,"leaving a burning zone avoids all subsequent damage")
	var parts = State.PARTS.new()
	check.call(State.PARTS.MECHANISMS.size()==12 and 'pulse' in parts.mechanism_pool(15) and 'swarm' in parts.mechanism_pool(16) and 'split' not in parts.mechanism_pool(15),"all twelve mechanisms use compatible pools for beams, missiles and projectile weapons")
	var rig = State.RIG_RUNTIME.new()
	rig.heat = 90
	var shield: float = rig.cool(0,{"cooling":12,"vent":true})
	check.call(shield==15 and rig.heat==60 and rig.vent_cooldown==8,"cooling circuit vents heat and grants a bounded shield event")
	rig.heat = 90
	check.call(rig.cool(0,{"cooling":12,"vent":true})==0,"cooling circuit cannot recursively retrigger during its cooldown")
	var defense = State.DEFENSE_RUNTIME.new()
	defense.grant_temporary(15,3)
	defense.hit(10,{"armor":0,"shield":0},false)
	check.call(defense.hp==100 and defense.temporary_shield==5,"temporary vent shield absorbs real incoming damage")
	defense.advance(3,{"armor":0,"shield":0},false)
	check.call(defense.temporary_shield==0,"temporary shield expires even when its capacity is not consumed")
	defense.hit(35,{"armor":0,"shield":0,"counter":1},false)
	check.call(defense.counter_ready and defense.counter_cooldown==5,"actual armor loss arms a finite counterattack")
	defense.counter_ready = false
	defense.hit(35,{"armor":0,"shield":0,"counter":1},false)
	check.call(not defense.counter_ready,"additional rapid hits cannot bypass counterattack cooldown")
	engine.reset(); arena.events.clear(); arena.units[0].p = Vector2(180,0)
	engine.launch(Vector2.ZERO,Vector2(180,0),100,"pulse","pulse",10,{"ion":true,"slot":0})
	engine.advance(arena,0.3)
	check.call(engine.stats.damage==100 and engine.stats.by_type.thermal==60 and engine.stats.by_type.electric==40,"reactor ion conversion composes with a weapon shape modifier without adding damage")
	check.call("ion" not in parts.mechanism_pool(1) and "ion" in parts.mechanism_pool(10),"fully electric weapons reject redundant conversion while reactors can support it")
	rig = State.RIG_RUNTIME.new(); rig.heat = 60
	var profile := {"slot":0,"mode":"standard","interval":0.9,"range":300.0,"heat":10.0,"attack":100.0,"mechanism":"hot_drive"}
	rig.advance(1,[profile,{}],100,"a",{"valid":true},capture)
	check.call(fired_attack==120 and rig.heat==73,"hot drive grants its high-temperature damage and increases actual heat cost")
	engine.reset(); arena.events.clear()
	arena.units = [{"id":"a","p":Vector2(180,0),"hp":100000.0},{"id":"b","p":Vector2(180,160),"hp":100000.0}]
	engine.launch(Vector2.ZERO,Vector2(180,0),100,"missile","swarm",11,{"target_id":"a","candidates":arena.attack_targets()})
	engine.advance(arena,1.5)
	var distributed: Dictionary = {}
	for event in arena.events: distributed[event.target] = true
	check.call(distributed.size()==2,"swarm rockets guide toward separate nearby targets instead of merely cloning one shot")
	defense = State.DEFENSE_RUNTIME.new(); defense.hp = 10; defense.counter_charge = 34
	defense.hit(40,{"armor":0,"shield":0,"counter":1},false)
	check.call(defense.hp==0 and not defense.counter_ready,"fatal damage cannot produce a posthumous counterattack")
	engine.reset(); arena.events.clear()
	engine.counter(arena,Vector2.ZERO,70,99)
	check.call(engine.stats.by_slot['1']>0 and engine.stats.by_mode.counter>0,"counter shockwave hits actual nearby enemies and is attributed to its armor source")
	var saved_world: Dictionary = World.export_save().duplicate(true)
	var enabled: bool = World.enabled
	var recovery: float = State.recovery
	World.import_save({}); World.docked = false; World.enabled = true; State.recovery = 0
	var point := World.START+Vector2(100,0)
	World.enemy_units['resistor'] = World.brain.new_unit({"id":"resistor","p":point})
	World.enemy_units['resistor'].resistances = {"electric":50}
	World.enemy_health['resistor'] = {"hp":1000.0,"max":1000.0}
	engine.reset()
	engine.deal(World,{"id":"resistor","p":point},100,{"weapon":12,"slot":0,"mode":"standard","mechanism":"ion","base_type":"kinetic"})
	check.call(engine.stats.damage==80 and engine.stats.by_type.kinetic==60 and engine.stats.by_type.electric==20,"per-type resistance resolves converted components once and telemetry reflects actual damage")
	World.import_save(saved_world); World.enabled = enabled; State.recovery = recovery
	arena.free()
