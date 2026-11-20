extends RefCounted
## Hostile shots track the target only when fired; subsequent movement can evade them.
var projectiles: Array = []
var impacts: int = 0
func launch(from: Vector2, target: Vector2, damage: int) -> void:
	if projectiles.size()>=96: return
	projectiles.append({"p":from,"direction":from.direction_to(target),"damage":damage,"ttl":3.0})
func advance(arena: Node, delta: float) -> void:
	var remaining := minf(delta,2)
	while remaining>0:
		var step := minf(remaining,0.02)
		remaining -= step
		var active: Array = []
		for shot in projectiles:
			var before: Vector2 = shot.p
			var after: Vector2 = before+shot.direction*460*step
			shot.ttl -= step
			if shot.ttl<=0 or arena.is_obstacle(arena.cell_at(after)) or not arena.line_clear(before,after): continue
			if Geometry2D.get_closest_point_to_segment(arena.player_position(),before,after).distance_to(arena.player_position())<=16:
				if arena.has_method("receive_directed_hit"): arena.receive_directed_hit(int(shot.damage),-shot.direction)
				else: arena.receive_hostile_hit(int(shot.damage))
				impacts += 1
				if not arena.player_alive():
					projectiles.clear()
					return
				continue
			shot.p = after
			active.append(shot)
		projectiles = active
