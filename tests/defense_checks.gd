extends RefCounted
const DEFENSE = preload("res://scripts/defense_runtime.gd")
const HOSTILE = preload("res://scripts/hostile_attacks.gd")
class Arena extends Node:
	var position := Vector2(120,0)
	var defense = DEFENSE.new()
	var stats := {"armor":0,"shield":20}
	var wall: bool = false
	func player_position() -> Vector2: return position
	func player_alive() -> bool: return defense.hp>0
	func line_clear(_a: Vector2,_b: Vector2) -> bool: return true
	func cell_at(p: Vector2) -> Vector2i: return Vector2i(floori(p.x/32),floori(p.y/32))
	func is_obstacle(c: Vector2i) -> bool: return wall and c.x==2
	func receive_hostile_hit(damage: int) -> bool:
		defense.hit(damage,stats,false)
		return true
func run(check: Callable) -> void:
	var arena := Arena.new()
	arena.defense.configure(arena.stats,true)
	var shots = HOSTILE.new()
	shots.launch(Vector2.ZERO,arena.position,20)
	shots.advance(arena,0.05)
	check.call(arena.defense.hits==0,"hostile bullets do not deal damage at firing time")
	shots.advance(arena,0.3)
	check.call(arena.defense.hits==1 and arena.defense.shield==0 and arena.defense.hp==100,"actual hostile impact consumes shield before armor health")
	shots.launch(Vector2.ZERO,arena.position,40)
	shots.advance(arena,0.4)
	check.call(arena.defense.hp==60,"damage over shield capacity reaches real armor")
	arena.defense.advance(4.1,arena.stats,false)
	check.call(is_equal_approx(arena.defense.shield,0.4),"shield regeneration starts only after four seconds without damage")
	arena.defense.advance(1,arena.stats,true)
	check.call(is_equal_approx(arena.defense.hp,61.2) and is_equal_approx(arena.defense.healed,1.2),"nanite repair uses the same health restoration accounting in training and combat")
	shots = HOSTILE.new()
	shots.launch(Vector2.ZERO,Vector2(120,0),20)
	arena.position = Vector2(120,100)
	shots.advance(arena,2); shots.advance(arena,2)
	check.call(shots.impacts==0 and shots.projectiles.is_empty(),"moving off a hostile trajectory evades the bullet and it expires")
	arena.position = Vector2(120,0); arena.wall = true
	shots.launch(Vector2.ZERO,arena.position,20)
	shots.advance(arena,1)
	check.call(shots.projectiles.is_empty() and shots.impacts==0,"cover blocks hostile projectiles with the same terrain rule")
	var defense = DEFENSE.new()
	var stats := {"armor":20,"shield":0}
	defense.hit(50,stats,true)
	check.call(defense.hp==84 and defense.prevented==34,"reactive barrier and armor reduction share a deterministic defense pipeline")
	defense.hit(50,stats,true)
	check.call(defense.hp==44,"reactive barrier cannot trigger again before its cooldown")
	arena.free()
