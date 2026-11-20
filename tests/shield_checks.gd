extends RefCounted
const DEFENSE = preload("res://scripts/defense_runtime.gd")
const HOSTILE = preload("res://scripts/hostile_attacks.gd")
class Arena extends Node:
	var defense = DEFENSE.new()
	var stats := {"armor":0,"shield":0,"guard_capacity":60}
	func player_position() -> Vector2: return Vector2.ZERO
	func player_alive() -> bool: return defense.hp>0
	func line_clear(_a: Vector2,_b: Vector2) -> bool: return true
	func cell_at(point: Vector2) -> Vector2i: return Vector2i(point/32)
	func is_obstacle(_cell: Vector2i) -> bool: return false
	func receive_directed_hit(damage: int, incoming: Vector2) -> bool:
		defense.hit(damage,stats,false,{"incoming":incoming,"facing":Vector2.RIGHT})
		return true

func run(check: Callable, main: Node) -> void:
	var defense = DEFENSE.new()
	var stats := {"armor":0,"shield":0,"guard_capacity":60}
	var front := {"incoming":Vector2.RIGHT,"facing":Vector2.RIGHT}
	defense.configure(stats,true)
	defense.hit(20,stats,false,front)
	check.call(defense.hp==92 and defense.guard==48 and defense.guard_blocked==12,"held shield blocks sixty percent of a frontal shot and spends equal guard durability")
	defense.hit(20,stats,false,{"incoming":Vector2.LEFT,"facing":Vector2.RIGHT})
	check.call(defense.hp==72 and defense.guard==48,"back attacks bypass the physical shield without spending guard")
	defense.hit(20,stats,false,{"incoming":Vector2.UP,"facing":Vector2.RIGHT})
	check.call(defense.hp==52 and defense.guard==48,"side attacks outside the one-hundred-twenty-degree guard cone bypass blocking")
	defense.hit(20,stats,false)
	check.call(defense.hp==32 and defense.guard==48,"undirected ground-area damage cannot be blocked by the held shield")
	defense = DEFENSE.new(); defense.configure(stats,true)
	defense.hit(100,stats,false,front)
	check.call(defense.hp==60 and defense.guard==0 and defense.guard_break==2,"depleting durability breaks the guard while preserving the unblocked damage")
	defense.hit(20,stats,false,front)
	check.call(defense.hp==40 and defense.guard==0,"a broken shield cannot keep blocking incoming hits")
	defense.advance(1,stats,false)
	check.call(defense.guard==0 and defense.guard_break==1,"guard stays empty during break recovery")
	defense.advance(2,stats,false)
	check.call(defense.guard==12 and defense.guard_break==0,"guard recovers at twelve per second only after two seconds without taking a hit")
	defense.advance(20,stats,false)
	check.call(defense.guard==60,"guard regeneration cannot exceed the equipped shield's capacity")
	stats.shield = 20; defense = DEFENSE.new(); defense.configure(stats,true)
	defense.hit(50,stats,false,front)
	check.call(defense.hp==100 and defense.guard==30 and defense.shield==0 and defense.absorbed==20,"physical guard and the energy shield consume separate defensive resources")
	var arena := Arena.new(); arena.defense.configure(arena.stats,true)
	var shots = HOSTILE.new()
	shots.launch(Vector2(150,0),Vector2.ZERO,20); shots.advance(arena,0.4)
	shots.launch(Vector2(-150,0),Vector2.ZERO,20); shots.advance(arena,0.4)
	check.call(shots.impacts==2 and arena.defense.hp==72 and arena.defense.guard_blocked==12,"real projectile travel passes the correct incoming direction to shield blocking")
	arena.free()
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	World.enabled = false; World.docked = true
	State.parts = State.PARTS.new(); State.parts.starter()
	State.selected = 0; State.selected_mech = 0; State.recovery = 0; State.sound_enabled = false
	State.credits = 10000; State.cores = 1000
	var blade: Dictionary = State.craft_part(21)
	var shield: Dictionary = State.craft_part(24)
	blade.affixes = []; blade.mechanism = ""; shield.affixes = []; shield.mechanism = ""
	State.equip_part(blade.id,0); State.equip_part(shield.id,4)
	check.call(State.weapon_profile(4).is_empty() and State.engagement_range()==120 and State.equipment_stats().guard_capacity>=60,"a sword-and-shield build keeps its sword attack range and a purely defensive second hand")
	State.equip_part(shield.id,0); State.equip_part(5,4)
	check.call(State.weapon_profile(0).is_empty() and State.weapon_profile(4).mode=="rail" and State.engagement_range()==390,"a shield may be held in the left hand without forcing a ranged build into melee")
	State.unequip_part(4)
	check.call(State.attack_range()==0 and not State.mech_configuration().valid,"shield-only loadouts cannot invent a ranged attack or depart without an attack weapon")
	State.equip_part(blade.id,4)
	State.defense.guard = 0; State.defense.guard_break = 1.5; State.defense.guard_quiet = 0.4; State.defense.guard_facing = Vector2.UP
	var saved: Dictionary = State.save_payload().duplicate(true)
	State.import_game(saved)
	check.call(State.defense.guard==0 and State.defense.guard_break==1.5 and State.defense.guard_quiet==0.4 and State.defense.guard_facing==Vector2.UP,"guard depletion, break recovery and facing persist across a save import")
	var training = load("res://scripts/training.gd").new()
	main.add_child(training); training.set_process(false); training.target_id = "main"
	training.receive_directed_hit(20,Vector2.RIGHT)
	check.call(training.defense.max_guard>0 and training.defense.guard_blocked>0,"training shares actual directional shield blocking with live combat")
	training.free()
	State.levels = [5,5,1]; State.unlocked = [true,true,false]; State.auto_skill = false
	State.import_tactics({})
	var simulator = load("res://scripts/certification.gd")
	var job = simulator.new(simulator.capture(State),0)
	for _batch in range(200):
		if job.done: break
		job.advance(1000)
	check.call(job.done and job.success and job.trials.size()==3,"a sword-and-shield build completes three real automatic certification cleanups")
	job.dispose()
	main.show_page(1); main.show_parts(); main.show_manufacturing(); main.close_modal()
	State.import_game(original); World.enabled = enabled
