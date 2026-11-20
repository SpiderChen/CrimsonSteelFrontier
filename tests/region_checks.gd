extends RefCounted

func kit(quality: int, level: int) -> void:
	State.parts = State.PARTS.new()
	for index in range(6):
		var part: Dictionary = State.parts.roll([0,1,5,8,10,12][index],quality)
		part.level = level
		part.affixes = [{"stat":"attack","value":3*(quality+1)}] if quality==0 else [{"stat":"attack","value":3*(quality+1)},{"stat":"haste","value":2*(quality+1)}]
		part.mechanism = "pierce" if index in [0,1] else ""
		State.parts.equip(0,part.id,[0,4,1,2,3,5][index])
	State.rig = State.RIG_RUNTIME.new(); State.defense = State.DEFENSE_RUNTIME.new()
	State.defense.configure(State.parts.stats(0),true)
	State.hp = 100; State.recovery = 0; State.auto = true; State.auto_skill = true; State.energy = 25
	State.tactics[0] = State.TACTICS.defaults()
	World.enter_base()

func same_values(before: Variant, after: Variant, path: String = "") -> bool:
	if before is Dictionary and after is Dictionary:
		if before.size()!=after.size(): return false
		for key in before:
			if not after.has(key) or not same_values(before[key],after[key],path+"/"+str(key)): return false
		return true
	if before is Array and after is Array:
		if before.size()!=after.size(): return false
		for i in range(before.size()):
			if not same_values(before[i],after[i],path+"/"+str(i)): return false
		return true
	if (before is int or before is float) and (after is int or after is float):
		if floorf(float(before))==float(before) and floorf(float(after))==float(after): return float(before)==float(after)
		return absf(float(before)-float(after))<=0.000000001
	return before==after

func walk(point: Vector2) -> bool:
	World.patrol = false
	if not World.navigate(point): return false
	for i in range(2400):
		State.advance(0.05)
		if World.docked: return false
		# Navigation snaps an obstructed request to nearby reachable ground.
		if World.position.distance_to(World.destination)<24: return true
	return false

func find(kind: String) -> Dictionary:
	for site in State.expedition.locations:
		if site.kind==kind: return site
	return {}

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	State.expedition = State.EXPEDITION.new(); State.selected = 0; State.selected_mech = 0
	State.stage = 1; State.credits = 10000; State.cores = 1000
	State.levels = [3,3,3,1,1,1]; State.unlocked = [true,true,true,false,false,false]
	World.enabled = true; World.import_save({"docked":true,"cleared":{"old-resource":true},"enemies":{"old-guard":{"hp":17,"max":100}}})
	kit(1,3)
	check.call(State.expedition.unlocked(0) and not State.expedition.unlocked(1),"map unlocks still depend on first clears")
	check.call(not State.expedition.begin(World,1) and not State.expedition.begin(World,0,16),"locked maps and off-map loot focus cannot launch")
	main.open_base(); main.show_region_detail(0)
	var titles: Array = main.overlay.find_children("*","Button",true,false).map(func(b): return b.text)
	check.call(titles.count("进入地图 · 自由探索")==1 and not titles.any(func(t): return "路线" in t),"map details offer one free-exploration launch action with no route selector")
	check.call(State.expedition.begin(World,0,0),"a selected map launches directly into free exploration")
	var exp = State.expedition
	var boss: Dictionary = exp.boss_site()
	check.call(not exp.run.has("route") and not exp.run.has("step") and not exp.run.has("auto") and not World.boss.active,"new sorties contain no linear route, step or automatic progression")
	check.call(not exp.boss_discovered() and not exp.revealed(boss.p) and not exp.sites().any(func(s): return s.kind=="boss_site"),"the boss and its terrain stay undisclosed at landing")
	var landing: Vector2 = World.position
	var discovered: Array = exp.run.discovered.duplicate()
	for i in range(400): State.advance(0.05)
	check.call(World.position==landing and exp.run.discovered==discovered and not World.boss.active,"automatic combat never drives the mech through unexplored terrain or starts a boss by elapsed time")
	main.show_page(0); main.refs.map.camera = boss.p
	var visited: Dictionary = exp.run.visited.duplicate()
	main.show_map_status(); main.refresh_map_status()
	check.call(exp.run.visited==visited and not exp.boss_discovered() and "尚未发现" in main.refs.exploration_summary.text,"panning and viewing exploration status do not reveal the boss or change the world")
	check.call(main.refs.hud_exploration.visible and main.refs.support_cannon.visible and not main.refs.hud_target.visible,"exploration and carrier controls stay visible while undiscovered boss targeting remains hidden")
	main.close_modal()
	var cache: Dictionary = find("cache")
	var stock: int = State.parts.inventory.size()
	check.call(not exp.interact(World,cache.id,1,exp.run.id) and State.parts.inventory.size()==stock,"remote or undiscovered facilities cannot be looted through a stale UI call")
	check.call(walk(cache.p),"real map navigation reaches a freely selected weapon cache through terrain")
	exp.reveal(World.position)
	var bounty: int = exp.run.bounty
	check.call(exp.interact(World,cache.id,1,exp.run.id) and cache.id in exp.run.used and exp.run.alert==1 and exp.run.bounty==bounty+140,"a nearby cache grants its actual selected rare part and Scarlet's declared reward")
	check.call(State.parts.inventory.back().blueprint==0 and State.parts.inventory.back().quality==1,"cache loot respects the selected model and rare quality")
	check.call(not exp.interact(World,cache.id,1,exp.run.id) and exp.run.bounty==bounty+140,"used facilities cannot duplicate loot or bounty")
	var cooling: Dictionary = find("cooling")
	check.call(walk(cooling.p),"cooling facilities can be visited in any order without a route gate")
	exp.reveal(World.position)
	var cooling_rate: float = State.combat_configuration().cooling
	var speed: float = World.move_speed()
	check.call(exp.interact(World,cooling.id,1,exp.run.id) and is_equal_approx(State.combat_configuration().cooling,cooling_rate*1.4) and is_equal_approx(World.move_speed(),speed*0.8),"the discovered cooling facility changes real heat dissipation and speed for ninety seconds")
	var actor_site: Dictionary = find("enemy")
	check.call(walk(actor_site.p+Vector2(-210,0)),"free-roaming enemy camps are reachable without transitions")
	exp.reveal(World.position)
	var foe_id: String = actor_site.id
	if not World.cleared.has(foe_id): World.apply_projectile_hit(foe_id,5,"standard",actor_site.p)
	var health: float = World.remaining_target_health(foe_id)
	var snapshot: Dictionary = State.save_payload().duplicate(true)
	var layout: Array = exp.locations.duplicate(true)
	var position: Vector2 = World.position
	State.save_override = ProjectSettings.globalize_path("res://tests/region_save_fixture.json")
	State.save_game(); State.expedition = State.EXPEDITION.new(); World.import_save({"docked":true}); State.load_game()
	exp = State.expedition
	check.call(same_values(exp.export_save(),snapshot.expedition) and exp.locations==layout and World.position.distance_to(position)<0.01,"disk reload retains the same generated layout, fog, discoveries, used sites and free-roaming position")
	check.call(is_equal_approx(World.remaining_target_health(foe_id),health) and cache.id in exp.run.used,"reload preserves wounded or defeated camps and cannot restock looted caches")
	DirAccess.remove_absolute(State.save_path()); State.save_override = ""
	exp.advance(World,90)
	check.call(exp.run.cooling_seconds==0 and is_equal_approx(State.combat_configuration().cooling,cooling_rate),"temporary cooling expires by elapsed exploration time rather than an invented node count")
	bounty = exp.run.bounty
	var cash: int = State.credits
	check.call(exp.withdraw(World) and State.credits==cash+bounty and exp.report.outcome=="withdrawn","manual departure banks exactly the earned exploration bounty")
	check.call(not exp.withdraw(World) and State.credits==cash+bounty,"repeated departure cannot award the same bounty twice")
	# All four bosses are found by real movement and fought at their actual map location.
	for region in range(4):
		kit(1,region+3); State.levels = State.initial_pilot_levels(); State.levels[0] = region+3; State.levels[1] = region+3; State.levels[2] = 3
		check.call(exp.begin(World,region,exp.DATA.REGIONS[region].pool[0]),"unlocked map %d starts without a route selection" % region)
		boss = exp.boss_site()
		check.call(walk(boss.p+Vector2(-200,0)),"the mech physically explores a path to map %d's boss" % region)
		exp.reveal(World.position)
		check.call(exp.boss_discovered() and not World.boss.active and exp.can_interact(World,boss.id),"finding a boss reveals it without forcing the player into combat")
		var before_position: Vector2 = World.position
		var ammunition: Dictionary = exp.run.support.duplicate(true)
		check.call(exp.interact(World,boss.id,0,exp.run.id) and World.boss.center==boss.p and World.position==before_position and exp.run.support==ammunition,"choosing to challenge starts at the discovered position without a teleport, route prerequisite or support refill")
		if region==0:
			World.boss.hit(World,"boss:tracks",13,"standard",World.boss.position)
			World.boss.fire_clock = 0; World.boss.advance(World,0.01)
			var hurt: float = World.boss.hp
			var warning: Vector2 = World.boss.warnings[0].p
			var during_boss: Dictionary = JSON.parse_string(JSON.stringify(State.save_payload()))
			State.import_game(during_boss)
			check.call(World.boss.active and World.boss.center==boss.p and is_equal_approx(World.boss.hp,hurt) and World.boss.parts.tracks==687 and World.boss.warnings[0].p.distance_to(warning)<0.01,"boss reload preserves its discovered map anchor, broken armor and live ground warnings instead of returning to the old arena")
		main.refresh_world()
		check.call(main.refs.hud_target.visible,"the boss target selector appears only after the player starts the fight")
		for i in range(14400):
			State.advance(0.05)
			if not exp.active(): break
		print("FREE MAP %d outcome=%s elapsed=%.1f" % [region,exp.report.get("outcome",""),exp.report.get("elapsed",0)])
		check.call(not exp.active() and exp.report.get("outcome")=="cleared" and exp.clears[region]==1,"map %d's discovered boss completes real combat and settles once" % region)
		if exp.active(): exp.withdraw(World)
		check.call(exp.blueprint_unlocked(17+region) and exp.samples[region]>=16 and (region==3 or exp.unlocked(region+1)),"boss victory preserves first-clear blueprints, samples and next-map unlocks")
		check.call(World.docked and World.cleared.has("old-resource") and World.enemy_health.get("old-guard",{}).get("hp",0)==17,"returning from free exploration preserves the archived world and carrier state")
	# Failure settlement keeps earned items and samples while losing unbanked bounty.
	kit(1,3); exp.begin(World,0,4)
	var supply: Dictionary = find("supply")
	World.position = supply.p; exp.reveal(World.position); exp.interact(World,supply.id,1,exp.run.id)
	stock = State.parts.inventory.size(); bounty = exp.run.bounty; cash = State.credits
	var samples: int = exp.samples[0]
	State.receive_enemy_hit(100000)
	check.call(not exp.active() and exp.report.outcome=="failed" and exp.report.lost==bounty and State.credits==cash,"exploration defeat loses only unbanked bounty and recalls to the carrier")
	check.call(State.parts.inventory.size()==stock and exp.samples[0]==samples and State.recovery>0,"defeat retains actual earned components, samples and repair state")
	State.advance(5.1)
	var sample_before: int = exp.samples[0]
	check.call(exp.exchange(0,17,true) and exp.samples[0]==sample_before-20,"the separate sample exchange still grants an unlocked named epic at its fixed price")
	check.call(not exp.exchange(0,16,false),"off-map exchange requests cannot consume regional samples")
	# Removed linear-save progress safely banks once instead of restarting or losing rewards.
	var legacy: Dictionary = State.save_payload().duplicate(true)
	legacy.expedition.run = {"id":77,"region":0,"route":1,"step":2,"phase":"battle","bounty":175,"overworld":World.export_save()}
	legacy.world.docked = false
	cash = int(legacy.credits)
	State.import_game(legacy)
	check.call(not State.expedition.active() and World.docked and State.credits==cash+175 and State.expedition.clears==exp.clears,"legacy route saves return safely with unbanked bounty and permanent progression preserved")
	var migrated: Dictionary = State.save_payload().duplicate(true)
	State.import_game(migrated)
	check.call(State.credits==cash+175 and not migrated.expedition.run.has("route"),"saving and reloading migrated progress cannot repeat the legacy settlement")
	main.close_modal(); State.import_game(original); World.enabled = enabled
