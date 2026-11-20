extends RefCounted
func run(check: Callable) -> void:
	var saved_world: Dictionary = World.export_save().duplicate(true)
	var original_parts = State.parts
	var original_rig = State.rig
	var original_defense = State.defense
	var saved: Dictionary = {}
	for key in ["credits","cores","gems","wins","stage","energy","auto","auto_skill","recovery","selected","levels","unlocked","last_result","idle_clock","pending_credits","pending_cores","core_clock","save_clock"]:
		saved[key] = State.get(key)
	State.parts = State.PARTS.new(); State.parts.starter()
	State.selected = 0; State.recovery = 0
	State.rig = State.RIG_RUNTIME.new(); State.defense = State.DEFENSE_RUNTIME.new()
	World.import_save({"docked":true})
	check.call(World.begin_boss() and World.boss.active and not World.docked,"carrier launches a real boss encounter in its arena")
	var boss = World.boss
	World.position = boss.position+boss.facing*230
	var before: float = boss.hp
	boss.hit(World,boss.BODY,100,"burst",boss.position)
	check.call(is_equal_approx(before-boss.hp,55),"frontal boss armor reduces ordinary shots")
	World.position = boss.position-boss.facing*230
	before = boss.hp
	boss.hit(World,boss.BODY,100,"burst",boss.position)
	check.call(is_equal_approx(before-boss.hp,120),"flanking bypasses frontal armor and increases effective damage")
	boss.hit(World,"boss:tracks",1000,"rail",boss.position)
	check.call(boss.parts.tracks==0 and boss.target_id()==boss.BODY,"breaking tracks removes their target and switches automatic targeting")
	boss.hit(World,"boss:cannon",1000,"rail",boss.position)
	check.call(boss.parts.cannon==0 and boss.phase==2,"cannon is independently destructible and body damage advances the phase")
	boss.hp = 1200; boss.phase = 3; boss.fire_clock = 0; boss.drone_clock = 0
	World.position = boss.position-Vector2(200,0); World.patrol = false
	boss.advance(World,0.05)
	check.call(boss.warnings.size()==4 and boss.drones.size()==1,"overload phase creates four actual danger zones and a drone")
	var data: Dictionary = boss.export_save().duplicate(true)
	boss.import_save(data)
	check.call(boss.phase==3 and boss.parts.cannon==0 and boss.warnings.size()==4 and boss.drones.size()==1 and boss.facing==Vector2.LEFT,"boss save restores phases, broken parts, facing, drones and pending attack countdowns")
	World.patrol = true
	var world_data: Dictionary = World.export_save().duplicate(true)
	World.import_save(world_data)
	check.call(World.patrol and boss.active and boss.warnings.size()==4,"active boss save restores automatic tactical movement along with pending attacks")
	boss.start(); World.position = boss.position-Vector2(200,0); World.patrol = false
	State.defense = State.DEFENSE_RUNTIME.new()
	boss.fire_clock = 0; boss.advance(World,0.05)
	var health: float = State.hp
	boss.advance(World,1.0)
	check.call(State.hp==health,"boss telegraphs cause no damage before their countdown expires")
	var circle: Vector2 = boss.warnings[0].p
	World.position = circle+Vector2(200,0)
	boss.advance(World,0.7)
	check.call(State.hp==health and boss.dodged>0,"moving out of the displayed circle avoids the actual blast")
	boss.start(); World.position = boss.position-Vector2(200,0); World.patrol = false; boss.fire_clock = 0
	boss.advance(World,0.05); boss.advance(World,1.7)
	check.call(State.hp<health,"remaining inside the same circle receives real damage at detonation")
	var wins: int = State.wins
	var gems: int = State.gems
	boss.hit(World,boss.BODY,100000,"rail",boss.position)
	check.call(World.docked and not boss.active and boss.victories==1 and State.wins==wins+1 and State.gems==gems+200,"boss defeat grants first-clear rewards once and returns the player to the carrier")
	boss.hit(World,boss.BODY,100000,"rail",boss.position)
	check.call(State.wins==wins+1 and State.gems==gems+200,"late projectiles cannot duplicate boss rewards")
	while State.parts.inventory.size()<State.PARTS.LIMIT: State.parts.roll()
	boss.start(); World.docked = false; World.position = boss.position-Vector2(200,0)
	boss.hit(World,boss.BODY,100000,"rail",boss.position)
	check.call(boss.pending_epics==0 and State.parts.inventory.size()==State.PARTS.LIMIT and State.parts.overflow.back().mechanism=="pierce","full inventory preserves the complete boss epic in overflow")
	for part in State.parts.inventory:
		if State.parts.owner(part.id)<0 and not State.parts.protected(part.id): State.parts.recycle(part.id); break
	check.call(State.parts.collect_overflow()==1 and State.parts.inventory.back().mechanism=="pierce" and State.parts.collect_overflow()==0 and not boss.claim_reward(),"overflow boss epic can be recovered exactly once after inventory space is freed")
	for build in [[0,1,3,6,11,13],[1,1,4,8,9,12],[2,0,5,7,10,12]]:
		seed(20261110)
		State.parts = State.PARTS.new()
		for index in range(6):
			var part: Dictionary = State.parts.roll(build[index],0)
			part.affixes = []
			part.mechanism = "pierce" if build[index] in [0,1] else "" 
			State.parts.equip(0,part.id,[0,4,1,2,3,5][index])
		State.rig = State.RIG_RUNTIME.new(); State.defense = State.DEFENSE_RUNTIME.new()
		State.defense.configure(State.parts.stats(0),true)
		State.levels = [1,1,1]; State.unlocked = [true,true,false]
		State.recovery = 0; State.auto = true; State.auto_skill = true; State.stage = 1
		World.import_save({"docked":true})
		check.call(World.begin_boss(),"reference build %s meets weight and power constraints" % str(build))
		for i in range(4800):
			State.advance(0.05)
			if not World.boss.active: break
		print("BOSS BUILD ",build," victories=",World.boss.victories," hp=",World.boss.hp," player=",State.hp," elapsed=",World.boss.elapsed)
		check.call(World.boss.victories==1,"reference build %s clears all phases using real automatic movement and attacks" % str(build))
	State.parts = original_parts; State.rig = original_rig; State.defense = original_defense
	for key in saved: State.set(key,saved[key])
	World.import_save(saved_world)
