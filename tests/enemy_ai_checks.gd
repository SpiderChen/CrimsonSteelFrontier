extends RefCounted

func isolate(allowed: Array) -> void:
	for site in World.nearby(World.position,3):
		if site.kind=="enemy" and not site.id in allowed: World.cleared[site.id]=true

func reset() -> void:
	World.import_save({})
	World.grace=0
	State.recovery=0
	State.hp=100
	State.defense.temporary_shield=0; State.defense.temporary_ttl=0
	State.auto_skill=false

func run(check: Callable) -> void:
	reset()
	var enemy: Dictionary=World.sites(Vector2i.ZERO)[1]
	World.position=enemy.p-Vector2(300,0)
	isolate([enemy.id])
	World.advance(0.05)
	check.call(World.enemy_units.has(enemy.id) and World.enemy_mode(enemy.id)=="chase","enemy detects player inside warning radius and starts pursuit")
	var original: Vector2=enemy.p
	var original_distance:=original.distance_to(World.position)
	for i in range(40): World.advance(0.05)
	var unit: Dictionary=World.enemy_units[enemy.id]
	check.call(unit.p.distance_to(original)>70 and unit.p.distance_to(World.position)<original_distance-80,"pursuit physically closes distance to the player")
	check.call(World.encounter_position==unit.p and World.site_position(enemy)==unit.p,"targeting and map use the same moving enemy position")
	check.call(World.enemy_shots>0 and State.hp<100,"pursuer fires after entering weapon range")
	check.call(unit.p.distance_to(World.position)>140,"ranged enemy stops before overlapping player")
	World.position-=Vector2(0,240)
	var gap: float=unit.p.distance_to(World.position)
	for i in range(30): World.advance(0.05)
	check.call(unit.p.distance_to(World.position)<gap-30,"enemy resumes chasing a moving player")
	State.enemy_hp=77
	State.enemy_max=200
	World.drop_target()
	World.position=unit.home+Vector2(1200,0)
	isolate([enemy.id])
	World.advance(0.05)
	check.call(unit.mode=="return","enemy abandons pursuit outside its home leash")
	World.grace=10000
	var shots:=World.enemy_shots
	for i in range(200): World.advance(0.05)
	check.call(unit.p.distance_to(unit.home)<5 and unit.mode=="guard","enemy walks home and resumes guarding")
	check.call(World.enemy_shots==shots,"returning enemies do not keep firing at distant player")
	check.call(World.enemy_health[enemy.id].hp==77,"returning home preserves damage already dealt")
	# Find an actual procedural obstacle with open cells on either side.
	reset()
	var obstacle:=Vector2i.ZERO
	var found:=false
	for y in range(8,35):
		for x in range(8,35):
			var c:=Vector2i(x,y)
			if World.is_obstacle(c) and not World.is_obstacle(c+Vector2i.LEFT) and not World.is_obstacle(c+Vector2i.RIGHT):
				obstacle=c;found=true;break
		if found: break
	var left:=Vector2(obstacle+Vector2i.LEFT)*World.CELL+Vector2.ONE*World.CELL/2.0
	var right:=Vector2(obstacle+Vector2i.RIGHT)*World.CELL+Vector2.ONE*World.CELL/2.0
	World.position=right
	isolate(["wall-test"])
	World.enemy_units["wall-test"]=World.brain.new_unit({"id":"wall-test","p":left})
	check.call(found and not World.line_clear(left,right),"obstacle scenario blocks direct line of fire")
	var collision_free:=true
	for i in range(120):
		World.advance(0.05)
		if World.is_obstacle(World.cell_at(World.enemy_units["wall-test"].p)): collision_free=false
	var routed: Vector2=World.enemy_units["wall-test"].p
	check.call(collision_free and World.chase_distance>256,"pursuer routes around terrain without walking through it")
	check.call(routed.distance_to(right)<200 and World.line_clear(routed,right),"pursuer gets around cover before attacking")
	# Two real guard posts close enough to detect the same player.
	reset()
	var guards: Array=World.nearby(World.START,2).filter(func(s): return s.kind=="enemy")
	var pair: Array=[]
	for a in guards:
		for b in guards:
			var middle: Vector2=(a.p+b.p)/2
			if a.id!=b.id and a.p.distance_to(b.p)<600 and not World.is_obstacle(World.cell_at(middle)):
				pair=[a,b];break
		if not pair.is_empty():break
	check.call(pair.size()==2,"multiple guard posts exist within shared warning range")
	World.position=(pair[0].p+pair[1].p)/2
	isolate([pair[0].id,pair[1].id])
	for i in range(35):World.advance(0.05)
	check.call(World.threat_count()==2,"multiple enemies can pursue independently of selected target")
	check.call(World.enemy_shots>=2 and State.hp<100,"multiple pursuers have independent attack cooldowns")
	var data:=World.export_save().duplicate(true)
	var enemy_position: Vector2=World.enemy_units[pair[0].id].p
	World.import_save(data)
	check.call(World.enemy_units[pair[0].id].p==enemy_position,"moving enemies restore their live position from save")
	State.hp=1
	for i in range(40):World.advance(0.05)
	check.call(State.recovery>0 and World.encounter_id=="","player defeat stops damage and releases target lock")
	check.call(World.threat_count()==0,"enemies disengage and return when player is down")
	reset()
