extends RefCounted

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	World.enabled = false; World.import_save({"docked":true})
	State.expedition = State.EXPEDITION.new(); State.carrier = State.CARRIER_SYSTEM.new()
	State.parts = State.PARTS.new(); State.parts.starter()
	State.recovery = 0; State.hp = 100; State.selected_mech = 0
	State.credits = 10000; State.cores = 1000
	main.open_base()
	check.call(not main.refs.has("base_facility_regions") and not main.refs.has("base_facility_boss") and main.refs.base_launch.tooltip_text.contains("选择地图") and main.refs.base_launch.get_children().any(func(child): return child is Label and child.text=="副本作战"),"carrier home has one map departure entry instead of separate exploration, boss and free-launch actions")
	main.launch_from_base()
	check.call(World.docked and not State.expedition.active() and main.overlay.find_children("*","Button",true,false).size()>=5,"departure opens four dungeon maps without launching before map selection")
	main.show_boss()
	check.call(World.docked and not State.expedition.active(),"legacy boss UI routes through map selection without starting a second mission system")
	main.carrier_ui.show_upgrades()
	check.call(main.carrier_ui.refs.size()==9 and not main.carrier_ui.refs.cannon_button.disabled,"all three carrier modules expose their effect and upgrade price")
	var cash: int = State.credits
	var alloy: int = State.cores
	check.call(State.carrier.upgrade("cannon") and State.carrier.levels.cannon==2 and State.credits==cash-600 and State.cores==alloy-20,"carrier upgrades permanently charge the displayed currencies once")
	check.call(State.carrier.damage()==210 and State.carrier.radius()==190,"cannon upgrades increase actual strike damage and coverage")
	State.credits = 0
	check.call(not State.carrier.upgrade("repair") and State.carrier.levels.repair==1 and State.cores==alloy-20,"unaffordable carrier upgrades cannot change a module or charge alloy")
	State.credits = 10000
	State.carrier.levels.cannon = 5
	check.call(not State.carrier.upgrade("cannon") and State.carrier.levels.cannon==5,"carrier modules stop at their visible maximum level")
	State.carrier.levels = {"cannon":1,"repair":3,"logistics":3}
	check.call(State.carrier.initial_support().cannon==3 and State.carrier.initial_support().repair==2 and State.carrier.cooldown()==26,"logistics upgrades add real mission ammunition and shorten the shared cooldown")
	State.carrier.levels = {"cannon":1,"repair":1,"logistics":1}
	check.call(not State.carrier.call_support(World,"cannon") and not State.carrier.call_support(World,"repair"),"support cannot fire or consume ammunition in the carrier")
	check.call(State.expedition.begin(World,0,0),"unified map selection starts a real dungeon with its own support allocation")
	main.show_page(0)
	check.call(main.refs.map.carrier_position()==State.expedition.DATA.LANDING and main.refs.map.carrier_button.visible,"exploration draws the carrier and its dock action at the real landing point")
	main.refs.map.carrier_button.pressed.emit()
	check.call(not World.docked and main.overlay.get_child_count()>0,"the map carrier point opens the return confirmation without withdrawing immediately")
	main.close_modal()
	World.position = State.expedition.locations.filter(func(site): return site.kind=="enemy")[0].p-Vector2(200,0)
	State.expedition.reveal(World.position)
	main.show_page(0); main.refresh_world()
	check.call(main.refs.support_cannon.visible and not main.refs.support_cannon.disabled and main.refs.support_repair.visible and main.refs.support_repair.disabled,"battle HUD exposes support directly and disables unnecessary full-health repairs")
	check.call(not State.carrier.upgrade("repair"),"carrier modules cannot be altered during a dungeon")
	var before: Dictionary = World.enemy_health.duplicate(true)
	check.call(State.carrier.call_support(World,"cannon") and State.expedition.run.support.cannon==1 and not State.expedition.run.support.pending.is_empty(),"calling artillery consumes one charge and records a delayed strike")
	check.call(World.enemy_health==before and not State.carrier.call_support(World,"cannon") and not State.carrier.call_support(World,"repair"),"artillery has a real warning delay and shared cooldown prevents duplicate or simultaneous calls")
	var snapshot: Dictionary = State.save_payload().duplicate(true)
	check.call(State.import_game(snapshot) and State.expedition.run.support.cannon==1 and State.expedition.run.support.cooldown==30 and not State.expedition.run.support.pending.is_empty(),"save reload preserves charges, shared cooldown and an incoming strike")
	State.carrier.advance(World,0.6)
	check.call(World.enemy_health==before,"carrier fire does not deal damage before the warning expires")
	State.carrier.advance(World,0.61)
	var damage := 0.0
	for id in before: damage += float(before[id].hp)-World.remaining_target_health(id)
	check.call(damage==280 and State.expedition.run.support.pending.is_empty(),"artillery damages both real enemies inside its radius exactly once")
	State.carrier.advance(World,0.1)
	var after_damage := 0.0
	for id in before: after_damage += float(before[id].hp)-World.remaining_target_health(id)
	check.call(after_damage==damage,"resolved artillery cannot repeat damage on subsequent updates")
	State.carrier.advance(World,30)
	State.hp = 40; State.rig.heat = 80
	check.call(State.carrier.call_support(World,"repair") and State.hp==60 and State.rig.heat==55 and State.expedition.run.support.repair==0,"repair deployment heals actual armor, vents actual heat and consumes its mission charge")
	State.carrier.advance(World,30)
	check.call(not State.carrier.call_support(World,"repair") and State.hp==60,"expired cooldown does not replenish exhausted repair ammunition")
	State.carrier.call_support(World,"cannon")
	State.expedition.advance(World,1.0)
	check.call(State.expedition.run.support.cannon==0 and State.expedition.run.support.repair==0 and not State.expedition.run.support.pending.is_empty(),"free exploration retains spent ammunition and a pending strike while the player travels")
	State.expedition.withdraw(World)
	check.call(not State.carrier.call_support(World,"cannon") and World.docked,"returning to the carrier ends the dungeon's support context")
	State.expedition.begin(World,0)
	check.call(State.expedition.run.support.cannon==2 and State.expedition.run.support.repair==1,"a new dungeon receives a fresh allocation after the previous mission ends")
	# Boss limbs share one damage pool; artillery must not triple-hit the core.
	var boss: Dictionary = State.expedition.boss_site()
	World.position = boss.p-Vector2(200,0); State.expedition.reveal(World.position)
	State.expedition.start_boss(World,boss.id)
	State.carrier.call_support(World,"cannon")
	var boss_hp: float = World.boss.hp
	var limbs: Dictionary = World.boss.parts.duplicate(true)
	var frontal: bool = World.boss.position.direction_to(World.position).dot(World.boss.facing)>0.6
	State.carrier.advance(World,1.3)
	check.call(is_equal_approx(boss_hp-World.boss.hp,int(140*(0.55 if frontal else 1.2))) and limbs==World.boss.parts,"carrier area fire resolves boss armor once instead of multiplying damage across visible limbs")
	State.expedition.withdraw(World)
	State.carrier.levels = {"cannon":3,"repair":2,"logistics":4}
	var saved: Dictionary = State.save_payload().duplicate(true)
	State.carrier = State.CARRIER_SYSTEM.new(); State.import_game(saved)
	check.call(State.carrier.levels=={"cannon":3,"repair":2,"logistics":4},"permanent carrier modifications survive a full game save round trip")
	saved.erase("carrier"); State.import_game(saved)
	check.call(State.carrier.levels=={"cannon":1,"repair":1,"logistics":1},"existing saves acquire functional level-one carrier modules without losing map progression")
	State.carrier.import_save({"levels":{"cannon":999,"repair":"bad","logistics":-1}})
	check.call(State.carrier.levels=={"cannon":5,"repair":1,"logistics":1},"invalid carrier module values cannot escape supported level bounds")
	main.carrier_ui.show_exchange(0)
	check.call(main.overlay.find_children("*","Button",true,false).any(func(b): return "样本 12" in b.text),"regional samples have a dedicated carrier exchange facility")
	check.call(State.expedition.DATA.MAP_HALF.x>1500 and State.expedition.DATA.MAP_HALF.y>1200,"dungeon maps provide a full exploration area instead of successive small combat rooms")
	main.close_modal(); State.import_game(original); World.enabled = enabled
