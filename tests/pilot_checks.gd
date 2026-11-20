extends RefCounted
const PILOT = preload("res://scripts/pilot_runtime.gd")
const ROSTER = preload("res://scripts/pilot_roster.gd")
const RIG = preload("res://scripts/rig_runtime.gd")
const DEFENSE = preload("res://scripts/defense_runtime.gd")
const ENGINE = preload("res://scripts/attack_system.gd")
class Arena extends Node:
	var attacks = ENGINE.new()
	var pilot = PILOT.new()
	var units: Array = [{"id":"a","p":Vector2(180,0),"hp":10000.0},{"id":"b","p":Vector2(300,0),"hp":10000.0}]
	var events: Array = []
	func attack_targets() -> Array: return units
	func line_clear(_a: Vector2,_b: Vector2) -> bool: return true
	func cell_at(p: Vector2) -> Vector2i: return Vector2i(p/32)
	func is_obstacle(_cell: Vector2i) -> bool: return false
	func apply_attack_event(event: Dictionary) -> float:
		for unit in units:
			if unit.id==event.target:
				var factor: float = pilot.multiplier(event)
				var actual: float = minf(unit.hp,event.damage*factor)
				unit.hp -= actual; pilot.record_hit(event,actual,factor); events.append(event.duplicate(true))
				return actual
		return 0
func run(check: Callable, main: Node) -> void:
	var arena := Arena.new()
	var rig = RIG.new(); var defense = DEFENSE.new(); defense.hp = 50; rig.heat = 90
	var runtime = arena.pilot
	check.call(runtime.use(0,arena,Vector2.ZERO,arena.units[0],rig,defense,100) and arena.attacks.projectiles.size()==3 and arena.events.is_empty(),"Scarlet launches three real thermal projectiles before any damage")
	check.call(rig.heat==60 and defense.hp==50 and runtime.heat_factor(0)==0.55 and runtime.cooling_bonus(0,60)==4,"Scarlet vents thirty heat and gains a timed heat discount without healing")
	arena.attacks.advance(arena,0.5)
	check.call(arena.attacks.stats.damage>0 and arena.attacks.stats.by_type.get("thermal",0)==arena.attacks.stats.damage and arena.attacks.stats.by_slot.get("skill",0)>0,"Scarlet skill collisions attribute actual damage to the skill and thermal type")
	runtime.advance(6.1,0,rig,defense,false,true)
	check.call(runtime.heat_factor(0)==1 and runtime.cooling_bonus(0,59)==0,"Scarlet heat buff expires and passive requires the stated temperature")
	arena.attacks.reset(); arena.events.clear(); runtime = PILOT.new(); arena.pilot = runtime
	runtime.use(1,arena,Vector2.ZERO,arena.units[0],rig,defense,100)
	check.call(arena.attacks.projectiles.size()==1 and arena.attacks.projectiles[0].mechanism=="pierce" and defense.hp==50,"Raven launches a single penetrating rail without generic healing")
	arena.attacks.advance(arena,0.5)
	check.call(arena.events.size()==2 and arena.attacks.stats.by_type.get("electric",0)==arena.attacks.stats.damage,"Raven skill genuinely crosses both aligned targets as electric damage")
	var meta := {"slot":0,"base_type":"kinetic"}
	arena.attacks.deal(arena,arena.units[0],100,meta)
	check.call(is_equal_approx(runtime.pending.marked_damage,15) and runtime.multiplier({"target":"a","slot":"skill"})==1 and runtime.multiplier({"target":"b","slot":4})==1,"Raven mark grants fifteen percent only to hand weapons against the marked target")
	runtime.advance(1.2,1,rig,defense,false,true)
	check.call(runtime.heat_factor(1)==0.85,"Raven passive activates after actual stationary time")
	runtime.advance(0.1,1,rig,defense,true,true)
	check.call(runtime.heat_factor(1)==1,"moving immediately removes Raven stationary benefit")
	runtime.advance(6,1,rig,defense,false,true)
	check.call(runtime.multiplier({"target":"a","slot":0})==1,"Raven target mark expires without permanently changing damage")
	arena.attacks.reset(); runtime = PILOT.new(); arena.pilot = runtime; rig.heat = 80; defense = DEFENSE.new(); defense.hp = 30
	check.call(runtime.use(2,arena,Vector2.ZERO,{},rig,defense,100) and arena.attacks.projectiles.is_empty() and arena.attacks.stats.damage==0,"Frost can cast without a target and creates no hidden damage")
	check.call(defense.temporary_shield==30 and rig.heat==55 and defense.hp==30,"Frost grants thirty shield and vents twenty-five without instant generic healing")
	runtime.advance(5,2,rig,defense,false,true)
	check.call(defense.hp==45 and runtime.pending.support==15,"Frost repairs exactly fifteen armor over five seconds")
	runtime.advance(5,2,rig,defense,false,true)
	check.call(defense.hp==45,"Frost repair cannot continue beyond the declared duration")
	defense.hp = 35; defense.temporary_shield = 0
	runtime.after_hit(2,defense,0)
	check.call(defense.temporary_shield==12 and runtime.passive_cooldown==12,"Frost low-armor passive creates a bounded emergency shield")
	defense.temporary_shield = 0; runtime.after_hit(2,defense,0)
	check.call(defense.temporary_shield==0,"repeated hits cannot refresh emergency shield during cooldown")
	runtime.advance(12,2,rig,defense,false,true); defense.hp = 0; runtime.after_hit(2,defense,0)
	check.call(defense.temporary_shield==0 and not runtime.use(2,arena,Vector2.ZERO,{},rig,defense,100),"destroyed mechs cannot trigger a passive shield or cast repair")
	var restored = PILOT.new(); runtime.heat_buff = 4; runtime.mark_target = "a"; runtime.mark_ttl = 2; runtime.passive_cooldown = 7
	restored.import_save(JSON.parse_string(JSON.stringify(runtime.export_save())))
	check.call(restored.heat_buff==4 and restored.mark_target=="a" and restored.mark_ttl==2 and restored.passive_cooldown==7,"active pilot timers and target identity survive JSON persistence")
	var roster = ROSTER.new()
	check.call(not roster.claim(0,0) and roster.talk(0,2)=="","personal tasks and higher-trust conversations honor their conditions")
	roster.record(0,"nodes",3); check.call(roster.claim(0,0) and not roster.claim(0,0) and roster.trust[0]==6,"personal task claims grant trust once and nodes grant one trust per completed event")
	var line: String = roster.talk(0,0); var trust: int = roster.trust[0]
	check.call(line!="" and roster.talk(0,0)==line and roster.trust[0]==trust,"conversation can be replayed without farming repeated trust")
	roster.record(0,"vented",120); check.call(roster.claim(0,1),"Scarlet second task progresses from actual heat vented")
	roster.record(0,"bosses",2); check.call(roster.claim(0,2),"final personal chapter requires real boss victories")
	var other = ROSTER.new(); other.import_save(JSON.parse_string(JSON.stringify(roster.export_save())))
	check.call(other.export_save()==roster.export_save(),"trust, task claims, metrics and read conversations survive JSON persistence")
	var old_runtime = State.pilot_runtime; var old_roster = State.pilot_roster
	var selected: int = State.selected; var unlocked: Array = State.unlocked.duplicate()
	State.pilot_runtime = PILOT.new(); State.pilot_roster = ROSTER.new(); State.unlocked = [true,true,true,true,true,true]
	for pilot in range(State.PILOTS.size()):
		State.selected = pilot; State.pilot_roster.trust[pilot] = 25
		main.pilot_ui.show_abilities(pilot); main.pilot_ui.show_relationship(pilot); main.pilot_ui.show_talk(pilot,2)
		check.call(is_instance_valid(main.story_ui.stage) and main.story_ui.portraits.has(pilot),"pilot %d ability, task and cinematic conversation screens build"%pilot)
		World.enter_base(); main.show_training(); var view: Control = main.refs.training_view
		view.set_process(false); view.energy = 100; view.profile.auto_skill = true; view.defense.hp = 50
		if pilot==3: view.origin = view.units[0].p-Vector2(90,0); view.manual_control = true
		view._process(0.05)
		check.call(view.skills==1 and view.pilot_runtime.casts==1 and (view.defense.temporary_shield==30 if pilot==2 else view.defense.temporary_shield==18 if pilot==5 else not view.engine.swings.is_empty() if pilot==3 else not view.engine.projectiles.is_empty()),"training pilot %d uses the same real skill runtime"%pilot)
		if pilot==5:
			view.energy = 0; view.profile.auto_skill = false; view._process(0.1)
			check.call(is_equal_approx(view.energy,0.1*(6.0+view.profile.stats.energy)),"Eve energy passive changes the actual training energy cycle")
		main.close_modal()
	var simulator = load("res://scripts/certification.gd")
	var before: Dictionary = State.pilot_roster.export_save(); var snapshot: Dictionary = simulator.capture(State)
	var job = simulator.new(snapshot,0); job.actor.energy = 100; job.actor.pilot_runtime.pending.support = 50; job.actor.flush_pilot_progress()
	check.call(job.actor.pilot_runtime!=State.pilot_runtime and job.actor.selected==State.PILOTS.size()-1 and State.pilot_roster.export_save()==before,"certification uses a fresh pilot runtime and cannot leak story progress into the live roster")
	job.dispose(); job = null
	var old_parts = State.parts; var old_expedition = State.expedition
	var old_defense = State.defense; var old_rig = State.rig
	var old_world: Dictionary = World.export_save(); var world_enabled: bool = World.enabled
	var credits: int = State.credits; var cores: int = State.cores
	var recovery: float = State.recovery; var energy: float = State.energy
	var override: String = State.save_override
	State.parts = State.PARTS.new(); State.parts.starter()
	State.expedition = State.EXPEDITION.new(); State.defense = DEFENSE.new(); State.rig = RIG.new()
	State.pilot_roster = ROSTER.new(); State.pilot_runtime = PILOT.new(); State.recovery = 0
	World.enabled = true
	for pilot in range(State.PILOTS.size()):
		State.selected = pilot
		World.enter_base(); check.call(State.expedition.begin(World,0),"pilot %d can launch a free exploration map"%pilot)
		var cache: Dictionary = State.expedition.locations.filter(func(site): return site.kind=="cache")[0]
		World.position = cache.p; State.expedition.reveal(World.position)
		var bounty: int = State.expedition.run.bounty; var stock: int = State.parts.research_materials
		check.call(State.expedition.interact(World,cache.id,1,State.expedition.run.id),"pilot %d opens the actual cache event"%pilot)
		check.call(State.expedition.run.bounty==bounty+100+(40 if pilot==0 else 60 if pilot==3 else 0) and State.parts.research_materials==stock+(1 if pilot==1 else 2 if pilot==4 else 0),"cache exploration perks grant only the declared bounty or research reward for pilot %d"%pilot)
		check.call(not State.expedition.interact(World,cache.id,1,State.expedition.run.id),"stale cache choice cannot duplicate a pilot exploration perk")
		var supply: Dictionary = State.expedition.locations.filter(func(site): return site.kind=="supply")[0]
		World.position = supply.p; State.expedition.reveal(World.position); State.hp = 40; State.rig.heat = 80
		State.expedition.interact(World,supply.id,0,State.expedition.run.id)
		check.call(State.hp==(80 if pilot==2 else 70) and State.rig.heat==(30 if pilot==2 else 20 if pilot==5 else 40),"supply repair follows pilot %d exploration specialty"%pilot)
		State.expedition.withdraw(World)
	State.selected = 0
	State.pilot_roster.record(0,"nodes",3)
	var previous_credits: int = State.credits; var previous_stock: int = State.parts.research_materials
	check.call(State.claim_pilot_task(0,0) and not State.claim_pilot_task(0,0) and State.credits==previous_credits+200 and State.parts.research_materials==previous_stock+1,"live personal task reward is paid exactly once")
	State.pilot_runtime.heat_buff = 4; State.pilot_runtime.passive_cooldown = 7
	State.defense.grant_temporary(30,6)
	State.save_override = ProjectSettings.globalize_path("res://tests/pilot_save_fixture.json")
	State.save_game(); var saved: Dictionary = State.pilot_roster.export_save()
	State.pilot_roster = ROSTER.new(); State.pilot_runtime = PILOT.new(); State.defense.temporary_shield = 0
	State.load_game()
	check.call(State.pilot_roster.export_save()==saved and State.pilot_runtime.heat_buff==4 and State.pilot_runtime.passive_cooldown==7 and State.defense.temporary_shield==30 and State.defense.temporary_ttl==6,"actual disk reload preserves personal rewards, active effects and full Frost shield")
	check.call(not State.claim_pilot_task(0,0),"completed personal rewards remain protected after reload")
	DirAccess.remove_absolute(State.save_path()); State.save_override = override
	State.parts = old_parts; State.expedition = old_expedition; State.defense = old_defense; State.rig = old_rig
	State.credits = credits; State.cores = cores; State.recovery = recovery; State.energy = energy
	World.import_save(old_world); World.enabled = world_enabled
	State.pilot_runtime = old_runtime; State.pilot_roster = old_roster; State.selected = selected; State.unlocked = unlocked
	arena.free()
	new_abilities(check)
	recruitment_and_migration(check)

func new_abilities(check: Callable) -> void:
	var arena := Arena.new()
	var rig = RIG.new(); var defense = DEFENSE.new(); defense.hp = 60
	var runtime = arena.pilot
	check.call(not runtime.use(3,arena,Vector2.ZERO,arena.units[0],rig,defense,100) and runtime.casts==0,"Reina cannot spend a cast on a target beyond her actual blade range")
	arena.units[0].p = Vector2(90,0)
	check.call(runtime.use(3,arena,Vector2.ZERO,arena.units[0],rig,defense,100) and arena.attacks.swings.size()==1 and arena.events.is_empty(),"Reina creates a timed blade swing with no instant or distant damage")
	arena.attacks.advance(arena,0.5)
	check.call(arena.events.size()==1 and arena.events[0].target=="a" and arena.attacks.stats.by_slot.get("skill",0)==240,"Reina active hits the nearby target for declared damage and cannot hit a distant target")
	check.call(is_equal_approx(runtime.multiplier({"target":"a","slot":0,"mode":"blade"}),1.5) and runtime.multiplier({"target":"a","slot":4,"mode":"laser"})==1,"Reina active and passive bonuses apply only to actual melee hand weapons")
	var saved_runtime = PILOT.new(); saved_runtime.import_save(runtime.export_save())
	check.call(saved_runtime.pilot_id==3 and saved_runtime.assault_ttl==6,"Reina active identity and duration survive persistence")
	runtime.advance(6.1,3,rig,defense,true,true)
	check.call(is_equal_approx(runtime.multiplier({"target":"a","slot":4,"mode":"hammer"}),1.15),"Reina returns to her fifteen percent passive after the active expires")
	check.call(runtime.pending.melee_damage==240,"Reina task records actual melee damage from the combat event stream")
	arena.attacks.reset(); arena.events.clear(); arena.units[0].p = Vector2(180,0)
	runtime = PILOT.new(); arena.pilot = runtime
	check.call(runtime.use(4,arena,Vector2.ZERO,arena.units[0],rig,defense,100) and arena.attacks.projectiles.size()==4,"Aster launches four real homing missiles")
	var damage: int = 0
	for projectile in arena.attacks.projectiles:
		damage += projectile.damage
		check.call(projectile.mode=="missile" and projectile.meta.target_id=="a","each Aster missile tracks the declared target")
	check.call(damage==270,"Aster missile payload totals the stated 270 percent attack budget")
	arena.units[0].p = Vector2(180,45)
	arena.attacks.advance(arena,1.5)
	check.call(arena.attacks.stats.by_mode.get("missile",0)>0 and runtime.pending.missile_damage==arena.attacks.stats.damage,"Aster missiles track a moving target and record actual missile damage")
	check.call(is_equal_approx(runtime.multiplier({"target":"a","slot":0,"mode":"missile"}),1.3) and is_equal_approx(runtime.multiplier({"target":"b","slot":4,"mode":"missile"}),1.1) and runtime.multiplier({"target":"a","slot":0,"mode":"rail"})==1,"Aster mark adds twenty percent only to guided weapons against its target")
	runtime.advance(6.1,4,rig,defense,false,true)
	check.call(is_equal_approx(runtime.multiplier({"target":"a","slot":0,"mode":"missile"}),1.1),"Aster mark expires while her missile passive remains")
	arena.attacks.reset(); runtime = PILOT.new(); arena.pilot = runtime; rig.heat = 95; rig.overheated = true
	check.call(runtime.use(5,arena,Vector2.ZERO,{},rig,defense,100) and rig.heat==55 and not rig.overheated and defense.temporary_shield==18,"Eve casts without a target, vents forty heat and grants her smaller support shield")
	check.call(defense.hp==60 and runtime.heat_factor(5)==0.65 and runtime.energy_bonus(5)==1.5 and runtime.energy_bonus(2)==0,"Eve reduces weapon heat and accelerates sync energy without duplicating Frost healing")
	saved_runtime.import_save(runtime.export_save())
	check.call(saved_runtime.pilot_id==5 and saved_runtime.reactor_ttl==6,"Eve reactor duration survives save import")
	runtime.advance(6.1,5,rig,defense,false,true)
	check.call(defense.hp==60 and runtime.heat_factor(5)==1,"Eve heat discount expires without hidden healing")
	var roster = ROSTER.new()
	for pilot in range(3,State.PILOTS.size()):
		for chapter in range(3):
			var task: Dictionary = roster.TASKS[pilot][chapter]
			roster.record(pilot,task.key,task.goal)
			check.call(roster.claim(pilot,chapter) and not roster.claim(pilot,chapter),"new pilot %d task %d can complete and pays only once"%[pilot,chapter])
		roster.trust[pilot] = 25
		for chapter in range(3): check.call(roster.talk(pilot,chapter)!="","new pilot %d trust talk %d is authored"%[pilot,chapter])
	arena.free()

func recruitment_and_migration(check: Callable) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var previous_energy: float = State.energy
	var previous_last_pull: Array = State.last_pull.duplicate()
	var legacy: Dictionary = original.duplicate(true)
	legacy.levels = [7,4,3]; legacy.unlocked = [true,true,true]; legacy.selected = 2; legacy.selected_mech = 2
	legacy.pilot_roster = {"trust":[25,10,3],"metrics":[{"nodes":3},{"marked_damage":1500},{}],"claimed":[[0],[],[]],"heard":[[0,1],[],[]]}
	legacy.mechs.units = legacy.mechs.units.slice(0,3)
	legacy.parts.loadouts = legacy.parts.loadouts.slice(0,3)
	legacy.parts.presets = legacy.parts.presets.slice(0,3)
	legacy.tactics = legacy.tactics.slice(0,3); legacy.tactic_presets = legacy.tactic_presets.slice(0,3)
	check.call(State.import_game(JSON.parse_string(JSON.stringify(legacy))),"legacy three pilot save migrates successfully")
	check.call(State.levels==[7,4,3,1,1,1] and State.unlocked==[true,true,true,false,false,false] and State.selected==2,"migration preserves old pilot levels and unlocks while appending locked newcomers")
	check.call(State.pilot_roster.trust==[25,10,3,0,0,0] and State.pilot_roster.claimed[0]==[0] and State.pilot_roster.heard[0]==[0,1],"migration preserves trust, claimed stories and heard conversations")
	check.call(State.mechs.units.size()==State.MECHS.MODELS.size() and State.tactics.size()==State.MECHS.MODELS.size() and State.tactic_presets.size()==State.MECHS.MODELS.size(),"legacy saves append tactics and presets for every newly available mech")
	State.gems = 900
	for pilot in range(3,State.PILOTS.size()):
		var before: int = State.gems
		check.call(State.recruit_pilot(pilot) and State.unlocked[pilot] and State.gems==before-300,"directed recruitment unlocks pilot %d for exactly 300 gems"%pilot)
		check.call(not State.recruit_pilot(pilot) and State.gems==before-300,"repeat directed recruitment cannot charge for owned pilot %d"%pilot)
	check.call(not State.recruit_pilot(-1) and not State.recruit_pilot(99) and State.gems==0,"invalid directed recruitment does not alter the wallet")
	State.unlocked[5] = false
	check.call(not State.recruit_pilot(5) and not State.unlocked[5] and State.gems==0,"insufficient gems cannot unlock or charge a directed pilot")
	State.unlocked[5] = true; State.choose(5); World.enter_base(); State.choose_mech(5)
	State.pilot_roster.trust[5] = 29
	State.pilot_runtime.pilot_id = 5; State.pilot_runtime.reactor_ttl = 4
	var current: Dictionary = JSON.parse_string(JSON.stringify(State.save_payload()))
	check.call(State.import_game(current) and State.selected==5 and State.selected_mech==5 and State.pilot_roster.trust[5]==29 and State.pilot_runtime.reactor_ttl==4,"six pilot save preserves new pilot selection, story progress, mech and active runtime")
	var malformed: Dictionary = current.duplicate(true); malformed.levels = [1,2,3,4]
	var wallet: int = State.gems
	check.call(not State.import_game(malformed) and State.gems==wallet and State.selected==5,"malformed roster lengths reject before mutating current progression")
	State.import_game(original); State.energy = previous_energy; State.last_pull = previous_last_pull
