extends RefCounted

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	State.expedition = State.EXPEDITION.new()
	State.parts = State.PARTS.new()
	State.mechs = State.MECHS.new()
	State.selected = 0; State.selected_mech = 0; State.recovery = 0
	State.tactics = [State.TACTICS.defaults(),State.TACTICS.defaults(),State.TACTICS.defaults()]
	World.import_save({}); World.enabled = true; World.grace = 100
	var distances: Array = []
	for model in range(3):
		State.selected_mech = model
		World.position = World.START; World.steering = Vector2.RIGHT
		World.path.clear(); World.patrol = false
		World.advance(0.1)
		distances.append(World.position.distance_to(World.START))
	check.call(is_equal_approx(distances[0],19) and is_equal_approx(distances[1],16) and is_equal_approx(distances[2],13),"identical bare builds physically travel at 190, 160 and 130 units per second")
	World.steering = Vector2.ZERO
	State.selected_mech = 0; State.parts.starter()
	var profiles: Array = State.weapon_profiles()
	var settings: Dictionary = State.movement_tactics()
	var controller = State.TACTICS.new()
	var reach: float = State.engagement_range()
	var target := World.START+Vector2(reach*float(settings.range_factor),0)
	var moving: Vector2 = controller.destination(World.START,target,settings,reach,[],settings.orbit,func(p): return p,func(_p): return true)
	check.call(moving.distance_to(World.START)>30,"Scarlet in a light chassis with burst weapons actually strafes")
	State.selected = 1
	settings = State.movement_tactics()
	target = World.START+Vector2(reach*float(settings.range_factor),0)
	World.position = World.START; World.encounter_position = target; World.encounter_id = "identity-target"
	World.path.clear(); World.path_index = 0; World.patrol = true
	World.tactical.navigation_clock = 0
	World.plan_tactical_movement(0.1)
	check.call(World.path.is_empty(),"Raven stops moving at effective range instead of constantly resetting steady aim")
	var training = load("res://scripts/training.gd").new()
	main.add_child(training); training.set_process(false)
	training.origin = Vector2(110,220)
	training.units[0].p = training.origin+Vector2(reach*float(settings.range_factor),0)
	for i in range(40): training._process(0.05)
	check.call(training.pilot_runtime.stationary>=1.2 and training.pilot_runtime.heat_factor(1)==0.85 and training.engine.stats.damage>0,"Raven activates steady aim while genuinely shooting in automatic training")
	training.free()
	var dodge: Vector2 = controller.destination(World.START,target,settings,reach,[{"p":World.START,"radius":80}],false,func(p): return p,func(_p): return true)
	check.call(dodge.distance_to(World.START)>100,"stationary sniper doctrine still leaves a real danger zone")
	var shots: Array = [{"p":World.START+Vector2(220,0),"direction":Vector2.LEFT}]
	var threats: Array = State.TACTICS.projectile_warnings(World.START,shots)
	dodge = controller.destination(World.START,target,settings,reach,threats,false,func(p): return p,func(_p): return true)
	check.call(not threats.is_empty() and absf(dodge.y-World.START.y)>80,"sniper evasion steps out of an incoming projectile corridor instead of retreating along it")
	shots[0].direction = Vector2.RIGHT
	check.call(State.TACTICS.projectile_warnings(World.START,shots).is_empty(),"departing projectiles do not repeatedly interrupt stationary aim")
	var melee := [{"mode":"gauntlet","range":84.0},{"mode":"rail","range":390.0}]
	settings = State.TACTICS.resolve(State.TACTICS.defaults(),melee,1,2)
	check.call(not settings.orbit and controller.desired_distance(settings,State.MELEE.engagement_range(melee))<60,"melee contact overrides sniper pilot and heavy chassis stances")
	var mixed := [{"mode":"rail","range":390.0},{"mode":"burst","range":300.0}]
	settings = State.TACTICS.resolve(State.TACTICS.defaults(),mixed,0,0)
	check.call(not settings.orbit and controller.desired_distance(settings,State.MELEE.engagement_range(mixed))<300,"mixed ranged builds stop inside both hands' range instead of starving the shorter weapon")
	var rocket: Dictionary = State.TACTICS.resolve(State.TACTICS.defaults(),[{"mode":"missile","range":420.0}],0,0)
	var plasma: Dictionary = State.TACTICS.resolve(State.TACTICS.defaults(),[{"mode":"plasma","range":300.0}],0,0)
	check.call(controller.desired_distance(rocket,420)>350 and controller.desired_distance(plasma,300)<200,"missile and plasma loadouts produce distinct stand-off and close-pressure distances")
	var manual := State.TACTICS.defaults(); manual.distance = "close"
	check.call(controller.desired_distance(State.TACTICS.resolve(manual,profiles,1,0),300)==120,"an explicit player distance setting takes precedence over pilot preferences")
	var ops = State.carrier.ops
	var ship: Dictionary = ops.initial()
	ship.goal[0] += 1000
	var initial_x: float = ship.ship[0]
	ops.move_ship(ship,1)
	check.call(ship.ship[0]==initial_x and ship.flight_speed==0 and ship.goal==ship.ship,"carrier ignores stale travel orders and remains fixed")
	ops.move_ship(ship,10)
	check.call(ship.ship[0]==initial_x,"elapsed time cannot move the stationed carrier")
	var restored: Dictionary = ops.import_save(ship)
	check.call(restored.ship==ship.ship and restored.flight_speed==ship.flight_speed,"stationary carrier position survives save import")
	ops.move_ship(ship,10)
	check.call(ship.ship==ship.goal and ship.flight_speed==0,"stationary carrier keeps its goal anchored to its position")
	ship.flight_speed = 140; ship.goal[0] += 500
	restored = ops.import_save(ship)
	check.call(restored.ship==ship.ship and restored.goal==restored.ship and restored.flight_speed==0,"legacy moving saves keep the ship position and discard travel velocity and destination")
	ship.flight_speed = INF
	check.call(ops.import_save(ship).flight_speed==0,"malformed carrier speed cannot inject infinite movement")
	World.enter_base(); State.selected_mech = 0
	main.show_page(1)
	check.call("基础移速" in main.refs.hangar_stats.text and "当前移速" in main.refs.part_summary.text,"hangar exposes chassis speed and the actual equipment-adjusted speed")
	State.import_game(original); World.enabled = enabled
	main.show_page(0)
