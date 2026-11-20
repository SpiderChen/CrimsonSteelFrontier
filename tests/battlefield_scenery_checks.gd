extends RefCounted
## Environment drawing must remain cosmetic: it cannot discover, obstruct or move anything.
var draws: int = 0

func collision_snapshot() -> PackedByteArray:
	var result := PackedByteArray()
	var bounds: Rect2 = State.expedition.bounds()
	var low: Vector2i = World.cell_at(bounds.position)
	var high: Vector2i = World.cell_at(bounds.end-Vector2.ONE)
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1): result.append(1 if World.is_obstacle(Vector2i(x,y)) else 0)
	return result

func render_frames(main: Node, map: Control) -> void:
	map.queue_redraw()
	await main.get_tree().process_frame
	await main.get_tree().process_frame

func screenshot(main: Node, name_value: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("res://.local/scenery-"+name_value+".png")

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	var original_clock: int = State.settlement_clock_override
	State.settlement_clock_override = int(Time.get_unix_time_from_system())
	State.parts = State.PARTS.new(); State.parts.starter()
	State.selected = 0; State.selected_mech = 0; State.recovery = 0; State.hp = 100
	State.expedition = State.EXPEDITION.new(); State.expedition.clears = [1,1,1,1]
	World.enabled = false; World.import_save({"docked":true})
	main.close_modal()
	for region in range(4):
		check.call(State.expedition.begin(World,region),"scenery fixture launches region %d"%region)
		main.show_page(0)
		var map: Control = main.refs.map
		map.set_process(false); map.following = false; map.camera = World.position
		map.draw.connect(func(): draws += 1)
		var boss: Dictionary = State.expedition.boss_site()
		var fog_before: Dictionary = State.expedition.run.visited.duplicate(true)
		var discovered_before: Array = State.expedition.run.discovered.duplicate()
		var collisions: PackedByteArray = collision_snapshot()
		var route: PackedVector2Array = World.build_path(World.position,World.position+Vector2(128,0))
		World.path = route.duplicate(); World.path_index = 0; World.destination = World.position+Vector2(128,0)
		var destination: Vector2 = World.destination
		var payload: Dictionary = State.save_payload().duplicate(true)
		var before_draws := draws
		await render_frames(main,map)
		await screenshot(main,"region-%d-landing"%region)
		for magnification in [0.38,1.4,0.88]:
			map.camera = boss.p
			map.zoom_at(magnification/map.zoom,map.size*0.5)
			map.elapsed += 0.75
			await render_frames(main,map)
		check.call(draws>before_draws,"region %d executes real map drawing at landing and across camera zooms"%region)
		check.call(State.expedition.run.visited==fog_before and State.expedition.run.discovered==discovered_before and not State.expedition.boss_discovered() and not State.expedition.revealed(boss.p),"region %d scenery and camera motion cannot reveal fog or disclose the hidden boss"%region)
		check.call(collision_snapshot()==collisions and World.build_path(World.position,destination)==route and World.path==route and World.path_index==0 and World.destination==destination,"region %d scenery preserves all collision cells, computed paths and the live navigation route"%region)
		check.call(State.save_payload()==payload,"region %d environment animation and redraw leave the complete save payload unchanged"%region)
		await screenshot(main,"region-%d-unexplored"%region)
		# Cached scenery must survive eviction without changing the map on return.
		var sample := Vector2i(4,7)
		var map_seed: int = State.expedition.run.seed
		var first: Dictionary = map.scenery.cell_data(sample,region,map_seed).duplicate(true)
		check.call(first==map.scenery.cell_data(sample,region,map_seed) and first!=map.scenery.cell_data(sample,(region+1)%4,map_seed),"region %d decoration stays deterministic and differs from the adjacent region"%region)
		for i in range(map.SCENERY.CACHE_LIMIT+32): map.scenery.cell_data(Vector2i(i,90),region,map_seed)
		check.call(map.scenery.cache.size()<=map.SCENERY.CACHE_LIMIT and first==map.scenery.cell_data(sample,region,map_seed),"region %d long camera travel keeps scenery memory bounded and reconstructs identical decoration"%region)
		map.camera = World.position; map.zoom = 0.88
		await render_frames(main,map)
		check.call(State.save_payload()==payload,"region %d returning from a distant camera view leaves the expedition untouched"%region)
		State.expedition.withdraw(World)
		await main.get_tree().process_frame
	State.import_game(original); World.enabled = enabled
	State.settlement_clock_override = original_clock
	main.show_page(0)
