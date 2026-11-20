extends RefCounted
const ATTACKS = preload("res://scripts/attack_system.gd")
class Arena extends Node:
	var units: Array = []
	var hits: Array = []
	var wall: bool = false
	func attack_targets() -> Array: return units
	func line_clear(_a: Vector2,_b: Vector2) -> bool: return true
	func cell_at(p: Vector2) -> Vector2i: return Vector2i(floori(p.x/32),floori(p.y/32))
	func is_obstacle(c: Vector2i) -> bool: return wall and c.x==2
	func apply_projectile_hit(id: String, damage: int, _mode: String, _point: Vector2) -> bool:
		hits.append({"id":id,"damage":damage})
		return true

func run(check: Callable) -> void:
	var arena := Arena.new()
	var engine = ATTACKS.new()
	arena.units = [{"id":"a","p":Vector2(120,0)}]
	engine.launch(Vector2.ZERO,Vector2(120,0),100,"standard","")
	check.call(arena.hits.is_empty(),"launching a projectile does not immediately apply damage")
	engine.advance(arena,0.03)
	check.call(arena.hits.is_empty(),"projectile travel time precedes target damage")
	engine.advance(arena,0.2)
	check.call(arena.hits.size()==1 and arena.hits[0].damage==100,"collision applies damage once when the projectile reaches the target")
	engine.reset(); arena.hits.clear()
	engine.launch(Vector2.ZERO,Vector2(120,0),100,"standard","")
	arena.units[0].p = Vector2(120,100)
	engine.advance(arena,1)
	check.call(arena.hits.is_empty(),"moving away from a shot causes a real miss")
	engine.reset(); arena.hits.clear(); arena.units.clear()
	for i in range(6): arena.units.append({"id":str(i),"p":Vector2(100+i*70,0)})
	engine.launch(Vector2.ZERO,Vector2(100,0),100,"rail","pierce")
	engine.advance(arena,0.5)
	check.call(arena.hits.size()==4 and arena.hits[0].damage==100 and arena.hits[1].damage==70 and arena.hits[3].damage==34,"piercing hits real collinear targets with attenuation and a finite target budget")
	engine.reset(); arena.hits.clear()
	arena.units = [{"id":"a","p":Vector2(100,0)},{"id":"b","p":Vector2(130,90)},{"id":"c","p":Vector2(220,75)}]
	engine.launch(Vector2.ZERO,Vector2(100,0),100,"standard","bounce")
	engine.advance(arena,1)
	var unique: Dictionary = {}
	for hit in arena.hits: unique[hit.id] = true
	check.call(arena.hits.size()==3 and unique.size()==3 and arena.hits[0].damage==80,"bounces find reachable distinct targets and reduce the initial damage budget")
	engine.reset(); arena.hits.clear()
	arena.units = [{"id":"a","p":Vector2(100,0)},{"id":"b","p":Vector2(200,55)},{"id":"c","p":Vector2(200,-55)}]
	engine.launch(Vector2.ZERO,Vector2(100,0),100,"standard","split")
	engine.advance(arena,0.5)
	check.call(arena.hits.size()==3 and arena.hits[0].damage==70 and engine.stats.triggers==1,"split produces two real child projectiles without recursive splitting or re-hitting the parent target")
	engine.reset(); arena.hits.clear(); arena.wall = true
	arena.units = [{"id":"a","p":Vector2(120,0)}]
	engine.launch(Vector2.ZERO,Vector2(120,0),100,"standard","")
	engine.advance(arena,0.5)
	check.call(arena.hits.is_empty() and engine.projectiles.is_empty(),"terrain stops a projectile before it reaches a target behind cover")
	var parts = State.PARTS.new()
	var variants: Dictionary = {}
	for i in range(90):
		var part: Dictionary = parts.roll(0,0)
		variants[part.mechanism] = true
	check.call(variants.has("pierce") and variants.has("bounce") and variants.has("split"),"one weapon model can roll all three distinct compatible mechanisms")
	check.call(parts.mechanism_pool(3)==["counter"] and "split" not in parts.mechanism_pool(2) and "pierce" not in parts.mechanism_pool(15),"mechanism tags restrict armor and reject incompatible ammunition on beams")
	var saved: Dictionary = parts.export_save()
	saved.inventory[0].mechanism = "invalid"
	saved.inventory[1].mechanism = "bounce"
	parts.import_save(saved)
	check.call(parts.inventory[0].mechanism=="" and parts.inventory[1].mechanism=="bounce","save loading preserves legal mechanisms and removes invalid mechanism IDs")
	arena.free()
