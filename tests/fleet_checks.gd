extends RefCounted

func total_health() -> float:
	var result := 0.0
	for target in World.attack_targets(): result += World.remaining_target_health(target.id)
	return result

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var flags := [World.enabled,State.auto,State.auto_skill]
	var save_override: String = State.save_override
	main.close_modal()
	State.expedition = State.EXPEDITION.new(); State.carrier = State.CARRIER_SYSTEM.new()
	State.parts = State.PARTS.new(); State.parts.starter(); State.selected_mech = 0; State.selected = 0
	State.defense = State.DEFENSE_RUNTIME.new(); State.defense.configure(State.equipment_stats(),true)
	State.rig = State.RIG_RUNTIME.new(); State.recovery = 0; State.auto = true; State.auto_skill = false
	World.import_save({"docked":true}); World.enabled = true
	var ops = State.carrier.ops
	check.call(not ops.command(World,"barrier") and not ops.follow(),"fleet commands cannot create shields or deployments outside a sortie")
	State.expedition.begin(World,0); main.show_page(0)
	var current: Dictionary = ops.data()
	check.call(current.energy==60 and ops.position()==State.expedition.DATA.LANDING and current.mode=="escort","each sortie starts with its actual carrier at landing and sixty command energy")
	main.refresh_world()
	check.call(main.refs.hud_carrier.visible and main.refs.hud_carrier.get_rect().end.x<=696 and not main.refs.hud_carrier.get_rect().intersects(main.refs.hud_exploration.get_rect()),"battle HUD keeps fleet command visible without covering exploration controls")
	main.carrier_ui.show_bridge()
	check.call(main.carrier_ui.bridge.barrier.disabled==false and main.carrier_ui.bridge.barrage.disabled,"the bridge enables an affordable shield and rejects a barrage without a nearby target")
	main.close_modal()
	World.position += Vector2(800,-200)
	var fog: Dictionary = State.expedition.run.visited.duplicate()
	var player: Vector2 = World.position
	ops.advance(World,1)
	check.call(ops.position()==State.expedition.DATA.LANDING and World.position==player,"the capital ship stays at landing while the player explores")
	check.call(fog==State.expedition.run.visited,"stationary carrier cannot explore fog or discover remote locations")
	var enemy: Dictionary = State.expedition.locations.filter(func(site): return site.kind=="enemy")[0]
	World.position = enemy.p-Vector2(180,0); State.expedition.reveal(World.position); World.grace = 0
	for site in State.expedition.sites():
		if site.kind=="enemy": World.enemy_health[site.id] = {"hp":10000.0,"max":10000.0}
	World.advance(0.01)
	current.ship = [World.position.x-190,World.position.y-110]; current.goal = current.ship.duplicate(); current.auto_clock = 0; current.energy = 100
	var health := total_health()
	ops.advance(World,0.1)
	check.call(current.salvos.size()==1 and total_health()==health,"automatic fire escort launches a delayed real shot against the current engagement")
	ops.advance(World,0.41)
	check.call(health-total_health()==24 and current.shots==1 and current.damage==24,"escort fire inflicts one actual hit and records its contribution")
	# A guard near the ship remains targetable when the mech is far away and idle.
	var saved_player: Vector2 = World.position
	var saved_ship: Array = current.ship.duplicate()
	World.drop_target()
	World.position = State.expedition.DATA.LANDING
	current.auto_clock = 0; current.energy = 100
	var fixed: Vector2 = ops.position()
	var nearby_target: Dictionary = ops.target(World)
	check.call(not nearby_target.is_empty(),"ship-centered targeting works without an active player encounter")
	var distant_health: float = World.remaining_target_health(nearby_target.id)
	ops.advance(World,0.1); ops.advance(World,0.41)
	check.call(World.remaining_target_health(nearby_target.id)<distant_health and ops.position()==fixed,"stationary ship independently attacks nearby enemies while the player is away")
	current.ship = [World.position.x,World.position.y]; current.goal = current.ship.duplicate(); current.auto_clock = 0
	var ranged_target: Dictionary = ops.target(World)
	check.call(ranged_target.is_empty() or ranged_target.p.distance_to(ops.position())<=ops.ATTACK_RANGE,"enemies near the distant mech do not extend the ship's firing range")
	current.ship = saved_ship; current.goal = saved_ship.duplicate(); World.position = saved_player
	ops.set_doctrine("silent"); var shots: int = current.shots
	ops.advance(World,7)
	check.call(current.shots==shots and current.salvos.is_empty(),"silent escort reserves energy instead of firing autonomously")
	ops.set_doctrine("guard"); current.auto_clock = 0; current.energy = 100; State.defense.temporary_shield = 0
	ops.advance(World,0.1)
	check.call(State.defense.temporary_shield==12 and current.energy<100,"defensive escort consumes command energy to grant a real timed shield")
	ops.set_doctrine("silent"); current.clock = 0; current.energy = 100
	check.call(ops.command(World,"barrage") and current.salvos.size()==3 and current.energy==60,"barrage commits forty energy and schedules three separate salvos")
	check.call(not ops.command(World,"barrier") and current.energy==60,"the command cooldown blocks repeated presses without a second charge")
	health = total_health(); ops.advance(World,0.7)
	check.call(total_health()==health,"barrage warning circles precede damage")
	State.save_override = ProjectSettings.globalize_path("res://tests/fleet_save_fixture.json")
	State.save_game(); State.load_game(); ops = State.carrier.ops; current = ops.data()
	check.call(State.carrier.doctrine=="silent" and current.salvos.size()==3 and is_equal_approx(current.salvos[0].t,0.1),"disk reload preserves doctrine, energy, command cooldown and each pending salvo timer")
	ops.advance(World,0.11); var first_hit := total_health()
	ops.advance(World,0.55); var second_hit := total_health()
	ops.advance(World,0.55); var third_hit := total_health()
	check.call(first_hit<health and second_hit<first_hit and third_hit<second_hit and current.salvos.is_empty(),"all three barrages resolve in sequence after a reload")
	ops.advance(World,0.2)
	check.call(total_health()==third_hit,"resolved salvos cannot repeat damage on later updates")
	current.clock = 0; current.energy = 0
	check.call(not ops.command(World,"barrier") and current.energy==0,"insufficient energy prevents shield creation without debt")
	ops.advance(World,10)
	check.call(current.energy==30 and ops.command(World,"barrier"),"elapsed sortie time replenishes energy for another meaningful command")
	State.defense = State.DEFENSE_RUNTIME.new(); var equipment = State.parts; State.parts = State.PARTS.new()
	State.hp = 100; State.receive_enemy_hit(20)
	check.call(State.hp==87 and current.prevented==7,"standing in the deployed shield zone reduces an actual twenty-damage hit to thirteen")
	World.position += Vector2(220,0); State.hp = 100; State.receive_enemy_hit(20)
	check.call(State.hp==80,"leaving the shield radius removes its damage reduction")
	ops.advance(World,8)
	check.call(current.field.is_empty(),"the area shield expires by actual combat time")
	State.parts = equipment
	World.drop_target(); World.position = State.expedition.DATA.LANDING; current.clock = 0; current.energy = 100
	current.ship = [World.position.x+800,World.position.y]; current.goal = current.ship.duplicate()
	State.hp = 40; State.rig.heat = 50
	var mission: int = State.expedition.run.id
	check.call(ops.command(World,"rally") and current.mode=="station" and current.energy==55,"supply deployment spends energy without relocating the carrier")
	ops.advance(World,0.1)
	check.call(not ops.supplying(World) and State.hp==40,"distant mechs cannot receive stationary supply")
	World.position = ops.position()
	ops.advance(World,8)
	check.call(ops.supplying(World) and State.hp>40 and State.rig.heat<50 and State.expedition.run.id==mission,"the stationary carrier repairs and vents nearby mechs without ending their expedition")
	if not World.enemy_units.has(enemy.id): World.enemy_units[enemy.id] = World.brain.new_unit(enemy)
	var old_position: Vector2 = World.enemy_units[enemy.id].p
	World.enemy_units[enemy.id].p = World.position+Vector2(80,0)
	var armor: float = State.hp; ops.advance(World,1)
	check.call(not ops.supplying(World) and State.hp==armor,"nearby hostile pressure interrupts forward supply instead of granting safe healing during combat")
	World.enemy_units[enemy.id].p = old_position
	check.call(ops.follow() and current.mode=="escort","the commander can release the supply site and resume stationary defense")
	State.save_game(); State.load_game(); ops = State.carrier.ops; current = ops.data()
	check.call(current.mode=="escort" and current.deployments==1 and current.repaired>0,"fleet position, deployment history and support contribution persist across disk reload")
	var before: Dictionary = current.duplicate(true)
	State.expedition.withdraw(World)
	check.call(State.expedition.report.carrier.shots==before.shots and State.expedition.report.carrier.repaired==before.repaired,"extraction stores the carrier's actual contribution in the sortie report")
	State.save_game(); State.load_game()
	check.call(State.expedition.report.carrier.prevented==7,"carrier contribution remains readable after reopening the saved return report")
	var report_cash: int = State.credits
	main.carrier_ui.show_report()
	check.call(State.carrier.report_seen==State.expedition.report.id and main.overlay.find_children("*","Label",true,false).any(func(label): return "护航射击" in label.text),"every completed sortie has a ship arrival presentation and its actual fleet report")
	main.close_modal(); main.carrier_ui.show_report(); main.close_modal()
	check.call(State.credits==report_cash,"viewing the fleet debrief cannot pay extraction rewards again")
	State.expedition.begin(World,0); current = ops.data()
	check.call(current.energy==60 and current.shots==0 and current.salvos.is_empty() and current.field.is_empty(),"a new sortie cannot inherit old salvos, shields or spent command energy")
	var boss: Dictionary = State.expedition.boss_site()
	World.position = boss.p-Vector2(200,0); State.expedition.reveal(World.position); State.expedition.start_boss(World,boss.id)
	current.energy = 100; current.ship = [World.position.x,World.position.y]; current.goal = current.ship.duplicate()
	check.call(not ops.command(World,"rally") and current.energy==100,"boss combat rejects forward supply deployment without charging energy")
	var boss_hp: float = World.boss.hp
	var front: bool = World.boss.position.direction_to(World.position).dot(World.boss.facing)>0.6
	ops.command(World,"barrage"); ops.advance(World,0.81)
	check.call(is_equal_approx(boss_hp-World.boss.hp,maxi(1,int(35*(0.55 if front else 1.2)))) ,"barrage hits the boss health pool once rather than once for every visible limb")
	World.boss.hp = 1; var cash: int = State.credits
	ops.advance(World,0.55)
	check.call(World.docked and State.expedition.clears[0]==1 and State.expedition.report.carrier.damage>0,"a lethal pending salvo safely completes and records its sortie")
	var paid: int = State.credits; ops.advance(World,10)
	check.call(paid>cash and State.credits==paid and not State.expedition.active(),"remaining salvo callbacks cannot duplicate victory rewards after extraction")
	var invalid: Dictionary = ops.import_save({"energy":999,"clock":-10,"ship":[1e20,1e20],"mode":"teleport","salvos":[{"point":[1e20,0]}],"field":{"point":[0,"bad"]}})
	check.call(invalid.energy==100 and invalid.clock==0 and invalid.mode=="escort" and invalid.salvos.is_empty() and invalid.field.is_empty(),"invalid saved fleet commands are sanitized without off-map targets or unlimited energy")
	State.carrier.import_save({"levels":{"cannon":1,"repair":1,"logistics":1},"doctrine":"invalid"})
	check.call(State.carrier.doctrine=="assault","unknown saved doctrines fall back to supported fire escort")
	main.open_base(); main.carrier_ui.show_bridge()
	check.call(main.carrier_ui.bridge.barrier.disabled and not main.carrier_ui.bridge.summary.text.is_empty(),"the carrier bridge shows the last report while preventing field commands in port")
	main.close_modal(); DirAccess.remove_absolute(State.save_path()); State.save_override = save_override
	State.import_game(original); World.enabled = flags[0]; State.auto = flags[1]; State.auto_skill = flags[2]
	main.open_base()
