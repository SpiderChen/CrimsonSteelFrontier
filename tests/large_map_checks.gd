extends RefCounted
## Expanded exploration must retain old layouts and every outer-sector save field.
const DATA = preload("res://scripts/region_data.gd")

func same_value(before: Variant, after: Variant) -> bool:
	if before is Dictionary and after is Dictionary:
		if before.size()!=after.size(): return false
		for key in before:
			if not after.has(key) or not same_value(before[key],after[key]): return false
		return true
	if before is Array and after is Array:
		if before.size()!=after.size(): return false
		for i in range(before.size()):
			if not same_value(before[i],after[i]): return false
		return true
	if (before is int or before is float) and (after is int or after is float): return is_equal_approx(float(before),float(after))
	return before==after

func fog_points(bounds: Rect2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var low := Vector2i((bounds.position/DATA.FOG_CELL).floor())
	var high := Vector2i((bounds.end/DATA.FOG_CELL).ceil())
	for y in range(low.y,high.y):
		for x in range(low.x,high.x):
			var center := Vector2(x,y)*DATA.FOG_CELL+Vector2.ONE*DATA.FOG_CELL/2.0
			if bounds.has_point(center): result.append(center)
	return result

func reachable(target: Vector2) -> bool:
	var position: Vector2 = DATA.LANDING
	var bounds: Rect2 = State.expedition.bounds()
	for segment in range(20):
		if position.distance_to(target)<1: return true
		var route: PackedVector2Array = World.build_path(position,target)
		if route.is_empty(): return false
		var before := position
		for waypoint in route:
			if not bounds.has_point(waypoint) or World.is_obstacle(World.cell_at(waypoint)) or not World.line_clear(position,waypoint): return false
			position = waypoint
		if position.distance_to(before)<1: return false
	return position.distance_to(target)<1

func setup(region: int) -> bool:
	State.expedition = State.EXPEDITION.new(); State.expedition.clears = [1,1,1,1]
	World.import_save({"docked":true}); World.enabled = false
	State.hp = 100; State.recovery = 0
	return State.expedition.begin(World,region)

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	var original_clock: int = State.settlement_clock_override
	State.settlement_clock_override = int(Time.get_unix_time_from_system())
	main.close_modal()
	State.parts = State.PARTS.new(); State.parts.starter()
	State.selected = 0; State.selected_mech = 0
	State.rig = State.RIG_RUNTIME.new(); State.defense = State.DEFENSE_RUNTIME.new()
	var old_bounds: Rect2 = DATA.map_bounds(1)
	var new_bounds: Rect2 = DATA.map_bounds(2)
	check.call(old_bounds.size==Vector2(3584,2816) and new_bounds.size==Vector2(7168,5632) and new_bounds.get_area()==old_bounds.get_area()*4,"new maps double both axes and provide four times the original playable area")
	check.call(new_bounds.position==Vector2(-256,-3840) and new_bounds.end==Vector2(6912,1792) and DATA.LANDING==Vector2(192,1600),"expansion extends north and east while preserving the carrier landing location")
	var candidate_seeds: Dictionary = {}
	for seed_value in range(1,33):
		var sites: Array = DATA.map_sites(0,seed_value,77,2)
		candidate_seeds[sites[0].p] = seed_value
	check.call(candidate_seeds.size()==DATA.EXPANDED_LAIRS.size(),"expanded maps retain multiple generated boss locations")
	for region in range(4):
		check.call(setup(region),"expanded map fixture launches region %d"%region)
		var exp = State.expedition
		check.call(int(exp.run.layout)==2 and exp.bounds()==new_bounds and World.position==DATA.LANDING,"region %d starts the expanded layout without relocating the carrier"%region)
		var sites: Array = exp.locations
		var legacy: Array = DATA.map_sites(region,int(exp.run.seed),int(exp.run.id),1)
		var enemies: Array = sites.filter(func(site): return site.kind=="enemy")
		var facilities: Array = sites.filter(func(site): return site.kind in ["cache","cooling","supply"])
		var outer: Array = sites.filter(func(site): return not old_bounds.has_point(site.p))
		var ids: Array = sites.map(func(site): return site.id)
		var unique: Dictionary = {}
		for id in ids: unique[id] = true
		check.call(sites.size()>64 and sites.size()>legacy.size()*2 and enemies.size()>legacy.filter(func(site): return site.kind=="enemy").size()*2 and facilities.size()>6,"region %d adds real enemy camps and facilities throughout the enlarged world"%region)
		check.call(not outer.is_empty() and outer.any(func(site): return site.p.x>old_bounds.end.x) and outer.any(func(site): return site.p.y<old_bounds.position.y) and sites.all(func(site): return new_bounds.grow(-128).has_point(site.p)) and unique.size()==sites.size(),"region %d populates both expansion directions with unique sites safely inside the map"%region)
		check.call(not exp.boss_discovered() and not old_bounds.has_point(exp.boss_site().p),"region %d places its undiscovered boss in an expanded sector"%region)
		check.call(reachable(exp.boss_site().p),"region %d segmented pathfinding reaches its distant boss without crossing obstacles or bounds"%region)
		var north: Dictionary = facilities[0]
		var east: Dictionary = facilities[0]
		for site in facilities:
			if site.p.y<north.p.y: north = site
			if site.p.x>east.p.x: east = site
		check.call(reachable(north.p) and reachable(east.p),"region %d paths reach the northernmost and easternmost facilities"%region)
		var points := fog_points(exp.bounds())
		check.call(points.size()==616,"region %d exploration uses all 616 fog cells in the expanded area"%region)
		exp.run.visited.clear()
		for i in range(154): exp.run.visited[exp.fog_key(points[i])] = true
		check.call(exp.explored_percent()==25,"region %d no longer reports full exploration after only the old map's 154 cells"%region)
		for point in points: exp.run.visited[exp.fog_key(point)] = true
		check.call(exp.explored_percent()==100,"region %d reaches 100 percent only after all expanded fog cells are visited"%region)
		exp.run.visited.erase(exp.fog_key(points.back()))
		check.call(exp.explored_percent()<100,"region %d leaves incomplete exploration below 100 percent"%region)
		# More than 64 discoveries/cleared camps must survive the same JSON path as disk saves.
		var wounded: Dictionary = enemies.back()
		for site in sites:
			if not site.id in exp.run.discovered: exp.run.discovered.append(site.id)
			if site.kind in ["cache","cooling","supply"]: exp.run.used.append(site.id)
			elif site.kind=="enemy" and site.id!=wounded.id:
				exp.run.secured.append(site.id); World.cleared[site.id] = true
		World.position = wounded.p; exp.reveal(World.position)
		World.enemy_health[wounded.id] = {"hp":17.0,"max":300.0}
		World.enemy_units[wounded.id] = World.brain.new_unit(wounded)
		World.enemy_units[wounded.id].p = wounded.p+Vector2(16,0)
		var ship: Vector2 = north.p
		exp.run.support.ops.ship = [ship.x,ship.y]; exp.run.support.ops.goal = [ship.x,ship.y]
		var snapshot: Dictionary = State.save_payload().duplicate(true)
		var discovered_count: int = exp.run.discovered.size()
		var secured_count: int = exp.run.secured.size()
		var layout: Array = exp.locations.duplicate(true)
		var fog: Dictionary = exp.run.visited.duplicate(true)
		check.call(State.import_game(JSON.parse_string(JSON.stringify(snapshot))),"region %d reload accepts the complete expanded JSON save"%region)
		exp = State.expedition
		check.call(exp.locations==layout and exp.run.discovered.size()==discovered_count and exp.run.secured.size()==secured_count and same_value(exp.run.used,snapshot.expedition.run.used),"region %d reload preserves every location, discovery, cleared camp and looted facility beyond the old 64-ID limit"%region)
		check.call(exp.run.visited==fog and World.position==wounded.p and World.enemy_units[wounded.id].p==wounded.p+Vector2(16,0) and World.remaining_target_health(wounded.id)==17 and State.carrier.ops.position()==ship,"region %d outer-sector fog, mech/enemy positions, damage and stationary carrier survive reload"%region)
		var invalid: Dictionary = snapshot.expedition.duplicate(true)
		invalid.run.visited["999:999"] = true; invalid.run.visited["-2:0"] = true; invalid.run.visited["0:-16"] = true
		exp.import_save(invalid)
		check.call(exp.run.visited==fog,"region %d discards out-of-bounds fog entries without losing valid expanded cells"%region)
		# End-of-sortie reports also carry more than the original maximum number of discoveries.
		exp.withdraw(World)
		var report_data: Dictionary = exp.export_save()
		exp.import_save(JSON.parse_string(JSON.stringify(report_data)))
		check.call(exp.report.discovered==discovered_count and exp.report.secured==secured_count,"region %d completed reports preserve the full expanded discovery and victory counts"%region)
	# Exercise every boss placement through the actual bounded segment planner.
	setup(0)
	for target in candidate_seeds:
		State.expedition.run.seed = candidate_seeds[target]
		State.expedition.locations = DATA.map_sites(0,int(candidate_seeds[target]),int(State.expedition.run.id),2)
		check.call(reachable(target),"all generated boss positions remain reachable from landing: %s"%target)
	# An in-progress schema-2 save without the new layout flag must stay on its original map.
	setup(0)
	var exp = State.expedition
	var legacy_payload: Dictionary = State.save_payload().duplicate(true)
	legacy_payload.expedition.run.erase("layout")
	legacy_payload.expedition.run.seed = 9321
	var old_sites: Array = DATA.map_sites(0,9321,int(exp.run.id),1)
	var old_pois: Array = old_sites.filter(func(site): return site.kind in ["cache","cooling","supply"])
	check.call(old_pois.map(func(site): return site.p)==[Vector2(448,1472),Vector2(1600,1216),Vector2(448,-192),Vector2(2304,-576),Vector2(2496,1344),Vector2(1216,-64)],"legacy facilities retain their original authored world coordinates")
	legacy_payload.expedition.run.used = [old_pois[0].id]
	legacy_payload.expedition.run.discovered = [old_sites[0].id,old_pois[0].id]
	legacy_payload.expedition.run.visited = {}
	for point in fog_points(old_bounds): legacy_payload.expedition.run.visited[exp.fog_key(point)] = true
	legacy_payload.world.position = [1600,1216]
	check.call(State.import_game(JSON.parse_string(JSON.stringify(legacy_payload))),"unversioned in-progress free-exploration saves still load")
	exp = State.expedition
	check.call(int(exp.run.layout)==1 and exp.bounds()==old_bounds and exp.locations==old_sites and World.position==Vector2(1600,1216) and old_pois[0].id in exp.run.used and exp.explored_percent()==100,"legacy reload keeps the original map, exact sites, looted facilities, player position and exploration percentage")
	var versioned: Dictionary = State.save_payload().duplicate(true)
	State.import_game(JSON.parse_string(JSON.stringify(versioned)))
	check.call(State.expedition.locations==old_sites and State.expedition.bounds()==old_bounds,"a second save/reload cannot silently expand a continuing legacy sortie")
	State.expedition.withdraw(World)
	check.call(State.expedition.begin(World,0) and State.expedition.bounds()==new_bounds and int(State.expedition.run.layout)==2,"the next sortie after a legacy return uses the expanded map")
	State.import_game(original); World.enabled = enabled
	State.settlement_clock_override = original_clock
	main.show_page(0)
