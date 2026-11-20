extends RefCounted

func run(check: Callable) -> void:
	World.enabled = true
	World.import_save({})
	World.patrol = false
	State.recovery = 0
	var sites := World.sites(Vector2i(7,-3)).duplicate(true)
	World.cache.clear()
	check.call(World.sites(Vector2i(7,-3))==sites,"world chunk generation is deterministic")
	for i in range(300): World.sites(Vector2i(i,14))
	check.call(World.cache.size()<=128,"world chunk cache stays bounded on a huge map")
	check.call(World.bounded(Vector2(1e9,-1e9)).x<World.EXTENT,"world navigation respects outer bounds")
	check.call(World.EXTENT*2==65536,"continuous world spans 65536 by 65536 units")
	World.position = World.START
	World.destination = World.START
	World.grace = 10000
	check.call(World.navigate(Vector2(3200,-700)),"cross-chunk destination receives a path")
	var safe := true
	for i in range(700):
		World.advance(0.05)
		if World.is_obstacle(World.cell_at(World.position)): safe = false
	check.call(World.position.distance_to(World.destination)<15,"segmented path reaches distant target without loading a scene")
	check.call(safe,"pathfinding avoids blocked terrain across chunk boundaries")
	check.call(World.distance_travelled>2000 and World.explored.size()>2,"movement records distance and multiple explored chunks")
	var wins := State.wins
	State.advance(1.0)
	check.call(State.wins==wins,"exploration does not fight enemies elsewhere on the map")
	var pilot_before: int = State.selected
	State.selected = 0
	State.energy = 100
	check.call(not State.ultimate(),"skill cannot damage a non-existent map encounter")
	State.selected = pilot_before
	World.import_save({})
	World.grace = 10000
	var resource: Dictionary = World.sites(Vector2i.ZERO)[0]
	var before := State.credits
	World.position = resource.p
	World.advance(0.01)
	check.call(World.cleared.has(resource.id) and State.credits>before,"walking to a resource collects it")
	before = State.credits
	World.advance(0.01)
	check.call(State.credits==before,"collected map resource cannot be claimed twice")
	var beacon: Dictionary = World.sites(Vector2i.ZERO)[2]
	State.hp = 30
	before = State.gems
	World.position = beacon.p
	World.advance(0.01)
	check.call(State.hp==100 and State.gems==before+30,"outpost activation repairs armor and rewards stars")
	var enemy: Dictionary = World.sites(Vector2i.ZERO)[1]
	World.position = enemy.p+Vector2(-50,0)
	World.grace = 0
	World.advance(0.01)
	check.call(World.encounter_id==enemy.id,"approaching a map enemy starts an encounter")
	before = State.wins
	State.damage_enemy(100000)
	check.call(World.cleared.has(enemy.id) and World.encounter_id=="" and State.wins==before+1,"victory removes that specific map enemy")
	World.cleared.erase(enemy.id)
	World.position=enemy.p-Vector2(170,0)
	World.grace=0
	World.advance(0.01)
	check.call(World.navigate(enemy.p-Vector2(160,70)),"path movement can be commanded during combat")
	World.path.clear()
	World.steering=Vector2.UP
	State.enemy_hp=10000
	State.enemy_max=10000
	State.battle_clock=0
	State.energy=0
	var moving_shots_before:=World.moving_shots
	var origin:=World.position
	for i in range(5): State.advance(0.2)
	World.attacks.advance(World,0.6) # resolve rounds already in flight
	check.call(World.position.distance_to(origin)>100 and State.enemy_hp<10000,"mech moves and fires during the same combat interval")
	check.call(World.moving_shots>moving_shots_before,"moving-fire count requires real displacement in the firing frame")
	check.call(World.steering==Vector2.UP,"auto target acquisition does not cancel held movement")
	World.steering=Vector2.ZERO
	World.path.clear()
	World.position=enemy.p-Vector2(350,0)
	World.grace=8
	World.attacks.reset() # isolate the out-of-range firing check from earlier projectiles
	var health:=State.enemy_hp
	var armor:=State.hp
	State.advance(1.0)
	check.call(State.enemy_hp==health and State.hp==armor,"outside attack range neither side deals phantom damage")
	World.position=World.encounter_position-Vector2(1000,0)
	World.grace=8
	World.advance(0.01)
	check.call(World.encounter_id=="" and World.enemy_health.has(enemy.id),"walking out of leash range drops target and records armor")
	World.position=enemy.p-Vector2(50,0)
	World.grace=0
	World.advance(0.01)
	check.call(World.encounter_id==enemy.id and State.enemy_hp==health,"re-engaging preserves enemy damage")
	World.steering=Vector2.UP
	State.damage_enemy(100000)
	check.call(World.steering==Vector2.UP,"victory does not interrupt held movement")
	World.steering=Vector2.ZERO
	World.cleared.erase(enemy.id)
	World.position=enemy.p-Vector2(60,0)
	World.grace=0
	World.advance(0.01)
	State.energy=100
	State.auto_skill=true
	State.advance(0.05)
	check.call(State.energy<100,"full-energy skill fires automatically for one-hand play")
	State.auto_skill=false
	var next_enemy: Dictionary = {}
	for site in World.nearby(enemy.p,2):
		if site.kind=="enemy" and site.id!=enemy.id and not World.cleared.has(site.id):
			next_enemy=site
			break
	World.encounter_id=enemy.id
	World.position=next_enemy.p-Vector2(50,0)
	World.encounter_position=World.position+Vector2(350,0)
	World.grace=0
	World.advance(0.01)
	check.call(World.encounter_id==next_enemy.id,"out-of-range target yields to a nearby enemy automatically")
	World.drop_target()
	World.cleared.erase(enemy.id)
	World.position = enemy.p+Vector2(-50,0)
	World.grace = 0
	World.advance(0.01)
	World.retreat()
	check.call(World.encounter_id=="" and World.grace>0 and World.position.distance_to(enemy.p)>86,"retreat leaves combat and provides a safe escape interval")
	var data := World.export_save().duplicate(true)
	var saved_pos := World.position
	World.position = Vector2.ZERO
	World.cleared.clear()
	World.import_save(data)
	check.call(World.position==saved_pos and World.cleared.has(resource.id),"world save restores position and one-time collection state")
	World.import_save({"position":["bad",null],"cleared":[],"explored":[]})
	check.call(World.position.is_finite() and World.cleared is Dictionary,"malformed world save is ignored safely")
	World.import_save({})
	World.grace = 10000
	World.patrol = true
	World.advance(1.0)
	check.call(World.is_moving(),"idle patrol chooses a nearby unvisited objective")
	World.patrol = false
	World.import_save({})
	World.grace = 0
