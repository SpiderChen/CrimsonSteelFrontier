extends RefCounted
var emissions: Array = []
func capture(profile: Dictionary) -> void: emissions.append(profile.slot)

func run(check: Callable, main: Node) -> void:
	var policy = State.TACTICS.new()
	var settings: Dictionary = State.TACTICS.defaults()
	var targets := [
		{"id":"near","p":Vector2(100,0),"hp":90.0,"max":100.0},
		{"id":"elite","p":Vector2(180,0),"hp":80.0,"max":100.0,"elite":true},
		{"id":"part","p":Vector2(210,0),"hp":70.0,"max":100.0,"part":true},
		{"id":"weak","p":Vector2(190,0),"hp":2.0,"max":100.0}
	]
	for pair in [["parts","part"],["nearest","near"],["elite","elite"],["weak","weak"]]:
		settings.target = pair[0]
		check.call(policy.select_target(Vector2.ZERO,targets,settings).id==pair[1],"target policy %s selects its intended live target" % pair[0])
	settings.target = "elite"; settings.survival = "clear"
	check.call(policy.select_target(Vector2.ZERO,targets,settings).id=="near","close-threat defense overrides distant target priorities")
	settings = State.TACTICS.defaults(); settings.survival = "withdraw"
	check.call(not policy.update_survival(100,15,100,settings) and policy.shield_retreat,"low shield initiates a retreat without recalling a healthy mech")
	policy.update_survival(100,50,100,settings)
	check.call(policy.shield_retreat,"shield recovery has hysteresis and does not oscillate at twenty percent")
	policy.update_survival(100,60,100,settings)
	check.call(not policy.shield_retreat and policy.update_survival(30,100,100,settings),"sixty percent shield resumes fighting while critical armor requests carrier withdrawal")
	settings = State.TACTICS.defaults(); settings.distance = "close"
	var close: Vector2 = policy.destination(Vector2.ZERO,Vector2(300,0),settings,390,[],false,func(p): return p,func(_p): return true)
	settings.distance = "far"
	var far: Vector2 = policy.destination(Vector2.ZERO,Vector2(300,0),settings,390,[],false,func(p): return p,func(_p): return true)
	check.call(close.x>0 and far.x<0 and is_equal_approx(far.distance_to(Vector2(300,0)),351),"close and far strategies produce opposite real movement goals within weapon range")
	var escape: Vector2 = policy.destination(Vector2.ZERO,Vector2(300,0),settings,390,[{"p":Vector2.ZERO,"radius":80}],false,func(p): return p,func(_p): return true)
	check.call(escape.length()>102,"danger-zone avoidance takes priority over the selected engagement distance")
	settings.skill = "elite"
	check.call(not policy.skill_allowed(settings,false,false) and policy.skill_allowed(settings,true,false),"elite skill timing holds a ready skill until an elite is in range")
	settings.skill = "danger"
	check.call(not policy.skill_allowed(settings,true,false) and policy.skill_allowed(settings,false,true),"danger skill timing waits for an actual defensive trigger")
	var profiles := [{"slot":0,"mode":"standard","interval":0.2,"range":300.0,"heat":40.0},{"slot":4,"mode":"standard","interval":0.2,"range":390.0,"heat":40.0}]
	var rig = State.RIG_RUNTIME.new(); emissions.clear()
	var peak := 0.0
	for i in range(150):
		rig.cool(0.05,{"cooling":20.0}); rig.advance(0.05,profiles,200,"a",{"valid":true},capture,{"heat":"conserve"}); peak = maxf(peak,rig.heat)
	check.call(peak<=95 and not rig.overheated and rig.hold_seconds>0 and not emissions.is_empty(),"conservative heat policy really stops fire, cools and resumes without overheating")
	rig.heat = 80; rig.cooling_hold = true; rig.cool(2,{"cooling":20.0})
	check.call(not rig.cooling_hold and rig.heat==40,"cooling clears a heat hold even without a target or another firing update")
	rig = State.RIG_RUNTIME.new(); emissions.clear()
	rig.advance(0.21,profiles,200,"a",{"valid":true},capture)
	rig.advance(0.21,profiles,200,"a",{"valid":true},capture)
	check.call(rig.overheated and rig.heat==100,"the same pressure configuration can overheat when continuous fire is chosen")
	rig = State.RIG_RUNTIME.new(); emissions.clear()
	profiles[0].mode = "burst"; profiles[0].heat = 1.0; profiles[1].heat = 1.0
	for step in [0.21,0.13,0.13]: rig.advance(step,profiles,200,"a",{"valid":true},capture,{"heat":"alternate"})
	check.call(emissions==[0,0,0,4],"alternation completes a three-round burst before switching to the other weapon")
	rig = State.RIG_RUNTIME.new(); emissions.clear()
	rig.advance(0.3,profiles,350,"a",{"valid":true},capture,{"heat":"alternate"})
	check.call(emissions==[4],"alternation cannot deadlock on an out-of-range weapon")
	var saved_parts = State.parts
	var saved_rig = State.rig
	var saved_defense = State.defense
	var saved_policies: Array = State.tactics.duplicate(true)
	var saved_presets: Array = State.tactic_presets.duplicate(true)
	var saved_world: Dictionary = World.export_save().duplicate(true)
	var before := [State.selected,State.hp,State.energy,State.stage,State.auto,State.auto_skill,World.enabled,State.recovery]
	State.parts = State.PARTS.new(); State.parts.starter(); State.rig = State.RIG_RUNTIME.new(); State.defense = State.DEFENSE_RUNTIME.new()
	State.selected = 0; State.tactics = [State.TACTICS.defaults(),State.TACTICS.defaults(),State.TACTICS.defaults()]; State.tactic_presets = [[],[],[]]
	State.recovery = 0; State.auto = true; State.auto_skill = false; State.stage = 1
	World.import_save({}); World.enabled = true; World.grace = 0; World.position = World.START
	var sites := [{"id":"near","kind":"enemy","p":World.START+Vector2(120,0),"name":"普通"},{"id":"elite","kind":"enemy","p":World.START+Vector2(190,0),"name":"精英","elite":true},{"id":"weak","kind":"enemy","p":World.START+Vector2(230,0),"name":"残血"}]
	World.cache["0:0"] = sites
	for site in World.nearby(World.position,2):
		if site.id not in ["near","elite","weak"]: World.cleared[site.id] = true
	for site in sites: World.enemy_health[site.id] = {"hp":1000000.0,"max":1000000.0}
	World.enemy_health.weak = {"hp":1.0,"max":1000.0}
	State.set_tactic("target","elite"); World.advance(0.01)
	check.call(World.encounter_id=="elite" and World.enemy_units.elite.elite,"real field targeting selects the marked elite over a nearer guard")
	State.set_tactic("target","weak"); World.advance(0.01)
	check.call(World.encounter_id=="weak" and World.enemy_health.elite.hp==1000000,"retargeting picks the wounded enemy and preserves the old enemy's remaining armor")
	State.set_tactic("target","nearest"); World.advance(0.01)
	check.call(World.encounter_id=="near","real field targeting can return to the nearest threat")
	State.set_tactic("distance","far"); World.set_patrol(true)
	var previous: Vector2 = World.position
	var old_distance: float = World.position.distance_to(World.encounter_position)
	World.advance(0.1)
	check.call(World.position.distance_to(previous)>0 and World.position.distance_to(World.encounter_position)>old_distance,"automatic far-distance strategy physically moves away from a nearby enemy")
	World.set_patrol(false); previous = World.position; World.advance(0.1)
	check.call(World.position==previous and World.path.is_empty(),"stopping autopilot cancels its tactical route immediately")
	World.set_patrol(true); World.steering = Vector2.RIGHT; previous = World.position; World.advance(0.1)
	check.call(World.position.x>previous.x,"manual steering takes priority over an automatic retreat direction")
	World.steering = Vector2.ZERO; World.set_patrol(false)
	State.set_tactic("skill","danger"); State.hp = 100; World.hostile.projectiles.clear()
	check.call(not World.auto_skill_allowed(),"real field danger strategy holds a full skill in a quiet, healthy state")
	State.hp = 40
	check.call(World.auto_skill_allowed(),"critical armor opens the real field danger skill gate")
	State.hp = 100; State.energy = 100
	check.call(State.ultimate() and State.energy==0,"manual skill release remains available while the automatic danger gate is closed")
	World.boss.start(); World.position = World.boss.CENTER-Vector2(260,0)
	World.boss.drones = [{"id":"boss:drone:test","p":World.position+Vector2(70,0),"hp":1.0,"fire":1.0}]
	State.set_tactic("target","weak"); World.boss.advance(World,0.01)
	check.call(World.current_target_id()=="boss:drone:test","real boss auto-targeting honors the wounded-target policy for maintenance drones")
	World.boss.selected = "cannon"; World.boss.advance(World,0.01)
	check.call(World.current_target_id()=="boss:cannon","explicit boss part locking overrides automatic target preferences and exposes the actual burst target ID")
	World.enter_base(); State.set_tactic("distance","far"); State.set_tactic("heat","conserve")
	State.save_configuration(0); State.set_tactic("distance","close"); State.set_tactic("heat","pressure")
	check.call(State.apply_configuration(0) and State.active_tactics().distance=="far" and State.active_tactics().heat=="conserve","loadout presets restore the exact saved tactical settings with their equipment")
	var saved_mech: int = State.selected_mech
	State.selected_mech = 1; State.set_tactic("distance","close"); State.selected_mech = 0
	check.call(State.active_tactics().distance=="far" and State.tactics[1].distance=="close","each chassis has independent persistent tactical preferences")
	State.save_override = ProjectSettings.globalize_path("res://tests/tactics_save_fixture.json")
	State.rig.heat = 75; State.rig.cooling_hold = true
	State.save_game(); State.import_tactics({}); State.rig.heat = 0; State.rig.cooling_hold = false; State.load_game()
	check.call(State.active_tactics().distance=="far" and State.tactic_presets[0][0].heat=="conserve" and State.tactics[1].distance=="close","chassis policies and preset policies survive an actual disk save roundtrip")
	check.call(State.rig.heat==75 and State.rig.cooling_hold,"reloading during a heat hold preserves its cooldown hysteresis")
	DirAccess.remove_absolute(State.save_path()); State.save_override = ""
	State.set_tactic("survival","withdraw"); World.docked = false; World.set_patrol(true); State.hp = 25
	World.advance(0.05)
	check.call(World.docked and State.hp==100 and not World.patrol,"automatic critical-armor withdrawal really recalls and repairs the mech at its carrier")
	State.set_tactic("target","elite"); State.set_tactic("skill","elite"); State.auto_skill = true
	var training = load("res://scripts/training.gd").new()
	main.add_child(training); training.set_process(false); training.reset(1); training.energy = 100
	training._process(0.05)
	check.call(training.target_id=="group4" and training.skills==1 and training.policy.heat=="conserve","training uses the same target, thermal and elite skill policy as the field")
	training.reset(0); training.energy = 100; training._process(0.05)
	check.call(training.skills==0 and training.energy==100,"elite timing also holds a ready skill during single-target training without elites")
	var real_hp: float = State.hp
	training.defense.hp = 25; training._process(0.05)
	check.call(training.retreated and State.hp==real_hp and World.docked,"training records safe withdrawal without recalling or damaging the actual mech")
	training.reset(0); training.manual_control = true; training.origin = Vector2(110,260); previous = training.origin; training._process(0.05)
	check.call(training.origin==previous,"training manual takeover prevents automatic distance corrections")
	training.queue_free()
	main.show_tactics(); main.close_modal()
	check.call(State.TACTICS.sanitize({"heat":[],"distance":"invalid","unknown":true})==State.TACTICS.defaults(),"invalid saved tactical fields fall back to supported defaults")
	var left: Dictionary = State.parts.equipped(0,0)
	var right_attack: float = State.weapon_profile(4).attack
	left.level = 3
	check.call(absf(State.weapon_profile(4).attack-right_attack)<1.1,"upgrading the other hand cannot leak its inherent attack into this weapon's damage profile")
	var blocked := false
	World.boss.stop(); World.docked = false
	for y in range(20,30):
		for x in range(20,30):
			var cell := Vector2i(x,y)
			if World.is_obstacle(cell) and not World.is_obstacle(cell+Vector2i.LEFT) and not World.is_obstacle(cell+Vector2i.RIGHT):
				World.position = Vector2(cell+Vector2i.LEFT)*World.CELL+Vector2.ONE*World.CELL/2
				World.encounter_position = Vector2(cell+Vector2i.RIGHT)*World.CELL+Vector2.ONE*World.CELL/2
				World.encounter_id = "occluded"
				blocked = not World.target_in_range()
				break
		if blocked: break
	check.call(blocked,"a target within nominal range is rejected when an actual terrain cell blocks its firing line")
	State.parts = saved_parts; State.rig = saved_rig; State.defense = saved_defense
	State.tactics = saved_policies; State.tactic_presets = saved_presets
	State.selected_mech = saved_mech
	State.selected = before[0]; State.hp = before[1]; State.energy = before[2]; State.stage = before[3]; State.auto = before[4]; State.auto_skill = before[5]; State.recovery = before[7]
	World.cache.clear(); World.import_save(saved_world); World.enabled = before[6]
