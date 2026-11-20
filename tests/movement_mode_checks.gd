extends RefCounted

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	State.expedition = State.EXPEDITION.new()
	State.parts = State.PARTS.new(); State.parts.starter()
	State.selected = 0; State.selected_mech = 0; State.stage = 1
	State.recovery = 0; State.auto = true; State.auto_skill = false
	State.rig = State.RIG_RUNTIME.new(); State.defense = State.DEFENSE_RUNTIME.new()
	State.defense.configure(State.equipment_stats(),true)
	State.tactics[0] = State.TACTICS.defaults()
	World.import_save({}); World.enabled = true; World.grace = 0
	var enemy := {"id":"movement-mode-guard","kind":"enemy","p":World.START+Vector2(235,0),"name":"测试守军"}
	World.cache["0:0"] = [enemy]
	for site in World.nearby(World.position,3):
		if site.id!=enemy.id: World.cleared[site.id] = true
	World.enemy_health[enemy.id] = {"hp":1000000.0,"max":1000000.0}
	World.advance(0.01)
	World.set_patrol(true)
	var before: Vector2 = World.position
	World.advance(0.1)
	check.call(World.position.distance_to(before)>5 and absf(World.position.y-before.y)>5,"default automatic movement strafes even when already at its preferred combat distance")
	var travelled: float = World.distance_travelled
	for i in range(30): World.advance(0.05)
	check.call(World.distance_travelled-travelled>50,"automatic combat keeps moving over multiple navigation updates")
	World.set_patrol(false); before = World.position
	var shots: int = World.shots_fired
	for i in range(30): State.advance(0.05)
	check.call(World.position==before and World.path.is_empty(),"manual mode stays still while nearby enemies continue fighting")
	check.call(World.shots_fired>shots,"manual movement retains automatic weapon fire")
	# Legacy roaming routes and boss routes are not marked tactical_path.
	World.set_patrol(true); World.tactical_path = false
	World.navigate(World.position+Vector2(100,0))
	World.set_patrol(false); before = World.position; World.advance(0.1)
	check.call(World.position==before and World.path.is_empty(),"switching to manual cancels an unmarked roaming route immediately")
	World.boss.start(); World.position = World.boss.position-Vector2(235,0)
	World.set_patrol(true); World.boss.advance(World,0.01)
	check.call(not World.path.is_empty(),"boss autopilot produces a real movement route")
	World.set_patrol(false); before = World.position
	for i in range(5): World.advance(0.05)
	check.call(World.position==before and World.path.is_empty(),"switching to manual during a boss fight cancels its route without residual movement")
	World.boss.navigation_clock = 5; World.set_patrol(true)
	World.advance(0.01); World.advance(0.1)
	check.call(World.position.distance_to(before)>1,"re-enabling boss autopilot replans immediately instead of waiting on its previous timer")
	main.show_page(0)
	main.refs.map.pointer_press(Vector2(200,700)); main.refs.map.pointer_move(Vector2(270,700))
	before = World.position; World.advance(0.1)
	check.call(not World.patrol and World.position.x>before.x,"dragging takes over automatic movement with the player's requested direction")
	main.refs.map.pointer_release(Vector2(270,700)); before = World.position
	World.advance(0.1)
	check.call(World.position==before,"releasing manual input stops movement instead of resuming autopilot")
	World.enter_base(); State.expedition.begin(World,0)
	before = World.position; World.set_patrol(true)
	for i in range(40): World.advance(0.05)
	main.refresh_world()
	check.call(World.position==before and "待敌" in main.refs.world_status.text,"automatic mode waits at landing and explains that it needs a nearby enemy")
	State.import_game(original); World.enabled = enabled
	main.show_page(0)
