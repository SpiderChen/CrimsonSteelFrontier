extends RefCounted

func run(check: Callable, main: Control) -> void:
	var saved: Dictionary = World.export_save()
	var wall := Vector2i.ZERO
	var found := false
	for y in range(-8,8):
		for x in range(-8,8):
			var cell := Vector2i(x,y)
			if World.is_obstacle(cell) and not World.is_obstacle(cell+Vector2i.LEFT) and not World.is_obstacle(cell+Vector2i(-1,-1)):
				wall = cell
				found = true
				break
		if found: break
	check.call(found,"movement reproduction locates a real obstacle next to open terrain")
	World.import_save({})
	World.position = Vector2(wall)*World.CELL+Vector2(-0.1,64)
	World.grace = 10000
	World.steering = Vector2.RIGHT
	State.recovery = 0
	var before: Vector2 = World.position
	World.advance(0.05)
	check.call(World.position==before and World.movement_blocked and wall in World.blocked_cells,"holding movement into terrain reports the exact blocking collision cell")
	check.call(World.steering==Vector2.RIGHT,"terrain blocking does not cancel the held movement input")
	main.refresh_world()
	check.call("障碍" in main.refs.world_status.text,"blocked movement gets an obstacle hint rather than a moving label")
	State.recovery = 3
	main.refresh_world()
	check.call("3.0 秒" in main.refs.world_status.text,"repair countdown takes priority over stale collision information")
	World.steering = Vector2.UP
	State.hp = 0
	State.auto = true
	State.advance(0.5)
	check.call(World.position==before and State.recovery>0,"depleted armor deliberately suspends movement during repair")
	State.advance(3.0)
	check.call(State.recovery<=0 and State.hp==100 and World.steering==Vector2.ZERO and World.docked and World.position==World.START,"repair respawns at the carrier and clears the held direction")
	World.launch()
	before = World.position
	World.steering = Vector2.UP
	World.advance(0.05)
	check.call(World.position.y<before.y and not World.movement_blocked,"changing direction immediately resumes movement along the obstacle")
	World.steering = Vector2.ZERO
	World.advance(0.05)
	check.call(not World.movement_blocked and World.blocked_cells.is_empty(),"release clears the obstacle indication")
	World.import_save(saved)
	World.grace = 0
	main.refresh_world()
