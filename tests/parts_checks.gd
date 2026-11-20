extends RefCounted
var shot_count: int = 0
var visual_modes: Array = []
var critical_hits: int = 0
var damages: Array = []

func count_shot(friendly: bool, _damage: int) -> void:
	if friendly:
		shot_count += 1
		damages.append(_damage)

func count_visual(mode: String, _from: Vector2, _target: Vector2, _critical: bool) -> void:
	visual_modes.append(mode)
	if _critical: critical_hits += 1

func empty_loadout() -> void:
	State.rig = State.RIG_RUNTIME.new()
	State.parts.inventory.clear()
	State.parts.overflow.clear(); State.parts.research.clear(); State.parts.reforge.clear()
	State.parts.loadouts = [{},{},{}]
	State.parts.next_id = 1
	State.selected = 0
	State.recovery = 0
	State.burst_left = 0
	State.battle_clock = 0
	State.barrier_clock = 0
	State.energy = 0
	State.hp = 100
	State.auto = true
	State.auto_skill = false
	State.stage = 1
	State.reset_enemy()
	World.drive_clock = 0

func equip(blueprint: int) -> Dictionary:
	var part: Dictionary = State.parts.roll(blueprint,0)
	part.mechanism = ""
	part.affixes = [] # Isolate the trait's behavior from random rolls.
	State.parts.equip(0,part.id)
	return part

func run(check: Callable) -> void:
	var original_parts: Dictionary = State.parts.export_save()
	var previous_selected: int = State.selected
	World.enabled = false
	empty_loadout()
	State.parts.starter()
	check.call(State.parts.inventory.size()==7 and State.parts.loadouts[0].size()==6,"starter kit equips six slots including both weapons and a backpack")
	var original: Dictionary = State.parts.export_save()
	var valid := true
	for quality in range(3):
		for blueprint in range(State.PARTS.BLUEPRINTS.size()):
			var part: Dictionary = State.parts.roll(blueprint,quality)
			var seen: Array = []
			valid = valid and part.slot==State.PARTS.BLUEPRINTS[blueprint].slot and part.affixes.size()==quality+1
			for affix in part.affixes:
				valid = valid and not affix.stat in seen and affix.value>=State.PARTS.AFFIXES[affix.stat].min*(quality+1) and affix.value<=State.PARTS.AFFIXES[affix.stat].max*(quality+1)
				seen.append(affix.stat)
	check.call(valid,"all available blueprints roll one to three distinct affixes within quality ranges")
	State.parts.import_save(original)
	var id: int = State.parts.inventory[0].id
	State.parts.equip(1,id)
	check.call(State.parts.equipped(0,0).is_empty() and State.parts.equipped(1,0).id==id,"transferring a part removes its previous owner without duplication")
	check.call(State.parts.recycle(id)==0,"equipped parts cannot be dismantled")
	State.parts.unequip(1,0)
	check.call(State.parts.recycle(id)==6 and State.parts.find_part(id).is_empty() and State.parts.recycle(id)==0,"unequipped part dismantles once with quality-scaled reward")
	check.call(not State.equip_part(-1) and not State.unequip_part(9),"invalid part and slot IDs are rejected")
	empty_loadout()
	State.credits = 900
	State.cores = 30
	var crafted: Dictionary = State.craft_part()
	check.call(not crafted.is_empty() and State.credits==450 and State.cores==15,"crafting charges both currencies exactly and stores the rolled item")
	State.credits = 0
	var count: int = State.parts.inventory.size()
	check.call(State.craft_part().is_empty() and State.parts.inventory.size()==count and State.cores==15,"unaffordable crafting cannot change resources or inventory")
	State.stage = 5
	State.enemy_hp = 1
	count = State.parts.inventory.size()
	State.damage_enemy(100)
	check.call(State.parts.inventory.size()==count+1 and State.parts.inventory.back().quality==2,"every fifth victory guarantees an epic part drop")
	while State.parts.inventory.size()<State.PARTS.LIMIT: State.parts.roll()
	State.credits = 1000
	State.cores = 100
	check.call(State.craft_part().is_empty() and State.credits==1000 and State.cores==100,"full inventory blocks crafting before currency deduction")
	State.stage = 5
	State.enemy_hp = 1
	var full_cores: int = State.cores
	State.damage_enemy(100)
	check.call(State.parts.inventory.size()==State.PARTS.LIMIT and State.cores==full_cores+12 and State.parts.overflow.size()==1 and State.parts.overflow[0].quality==2,"full inventory preserves guaranteed epic drops in overflow without converting their rolls to alloy")
	empty_loadout()
	var attack: int = State.total_attack()
	var weapon := equip(1)
	weapon.affixes = [{"stat":"attack","value":5}]
	check.call(State.total_attack()==attack+10 and State.attack_range()==390 and is_equal_approx(State.attack_interval(),1.35),"weapon inherent stats, affix, rail range and slower interval affect live combat")
	State.parts.loadouts[0].clear()
	check.call(State.total_attack()==attack and State.attack_range()==300,"removing a part removes its combat effects immediately")
	equip(9)
	check.call(is_equal_approx(State.attack_interval(),0.9*0.82),"overdrive core shortens the actual firing interval")
	empty_loadout()
	State.shot.connect(count_shot)
	State.weapon_fired.connect(count_visual)
	equip(0)
	State.enemy_hp = 10000
	State.enemy_max = 10000
	shot_count = 0
	State.advance(0.91)
	check.call(shot_count==1 and State.burst_left==2,"burst weapon starts with one real shot and two pending shots")
	State.advance(0.13)
	State.advance(0.13)
	check.call(shot_count==3 and State.burst_left==0 and State.enemy_hp<10000,"burst weapon emits three separately timed damage events")
	check.call(visual_modes.count("burst")==3,"each burst round emits a matching visual effect event")
	State.enemy_hp = 1
	State.battle_clock = 1
	State.advance(0.1)
	check.call(State.burst_left==0,"lethal burst cancels queued rounds instead of hitting the next enemy")
	empty_loadout()
	equip(3)
	State.receive_enemy_hit(100)
	check.call(State.hp==61 and State.barrier_clock==6,"reactive armor applies passive reduction and timed shield to real incoming damage")
	State.hp = 100
	State.receive_enemy_hit(100)
	check.call(State.hp==3,"reactive shield cannot repeatedly block during cooldown")
	State.hp = 100
	State.battle_clock = -10
	State.advance(6.1)
	check.call(State.barrier_clock<=0,"reactive shield recharges through combat time")
	State.equip_part(State.parts.equipped(0,1).id)
	check.call(State.barrier_clock>=6,"re-equipping a shield cannot reset its cooldown")
	empty_loadout()
	equip(4)
	check.call(State.parts.stats(0).armor==21 and State.parts.stats(0).speed==-8,"fortress armor trades speed for additional damage reduction")
	empty_loadout()
	equip(11)
	check.call(State.parts.stats(0).crit==15,"precision core grants its stated critical chance")
	empty_loadout()
	equip(5)
	State.hp = 50
	State.advance(0.5)
	check.call(is_equal_approx(State.hp,50.6),"nanite armor actually repairs health over time")
	empty_loadout()
	equip(10)
	State.advance(0.5)
	check.call(is_equal_approx(State.energy,4.25),"synchronization core adds skill energy every second")
	empty_loadout()
	var crit_weapon := equip(1)
	crit_weapon.affixes = [{"stat":"crit","value":10000},{"stat":"armor","value":10000},{"stat":"haste","value":10000}]
	var stats: Dictionary = State.parts.stats(0)
	check.call(stats.crit==75 and stats.armor==65 and stats.haste==50,"effective stat caps prevent invulnerability and unbounded fire rate")
	State.enemy_hp = 100000
	State.enemy_max = 100000
	critical_hits = 0
	damages.clear()
	seed(20261110)
	for i in range(20): State.fire_weapon("rail",2)
	var largest: int = damages.max()
	check.call(critical_hits>0 and largest>=State.total_attack()*4,"critical attacks deal doubled damage and emit critical visuals")
	empty_loadout()
	World.enabled = true
	World.import_save({})
	World.position = World.START
	World.grace = 10000
	World.steering = Vector2.RIGHT
	equip(6)
	World.advance(0.1)
	check.call(World.position.distance_to(World.START)>State.mech_configuration().base_speed*0.1 and World.drive_mode()=="hover","hover drive changes real movement speed")
	State.parts.loadouts[0].clear()
	equip(7)
	World.drive_clock = 2.5
	var before := World.position
	World.advance(0.1)
	check.call(World.position.distance_to(before)>State.mech_configuration().base_speed*0.1*1.9,"pulse drive produces a real timed movement burst")
	State.parts.loadouts[0].clear()
	equip(8)
	check.call(World.move_speed()<State.mech_configuration().base_speed and State.parts.stats(0).armor==15,"tread chassis trades movement speed for reduction")
	empty_loadout()
	World.import_save({})
	World.position = World.START
	World.grace = 10000
	equip(2)
	for site in World.nearby(World.position,2):
		if site.kind=="enemy": World.cleared[site.id] = true
	var center := World.START+Vector2(100,0)
	for target in ["primary","secondary","far"]:
		var p: Vector2 = center+Vector2(40 if target=="secondary" else 200 if target=="far" else 0,0)
		World.enemy_units[target] = World.brain.new_unit({"id":target,"p":p})
		World.enemy_health[target] = {"hp":10000.0,"max":10000.0}
	World.encounter_id = "primary"
	World.encounter_position = center
	State.enemy_hp = 10000
	State.enemy_max = 10000
	State.fire_weapon("plasma",1.1)
	World.attacks.advance(World,0.3)
	check.call(State.enemy_hp<10000 and World.enemy_health.secondary.hp<10000 and World.enemy_health.far.hp==10000,"plasma damages the actual primary and only nearby secondary enemies")
	check.call(visual_modes.has("plasma"),"plasma combat emits its distinct explosion visual")
	World.enemy_health.secondary.hp = 1
	var wins: int = State.wins
	World.splash_damage(center,"primary",100)
	check.call(World.cleared.has("secondary") and State.wins==wins+1 and State.enemy_hp>0,"splash kills award victory without resetting the primary target health")
	State.burst_left = 2
	State.burst_target = "missing-target"
	State.advance(0.13)
	check.call(State.burst_left==0,"queued burst rounds cannot retarget another enemy")
	World.enemy_units.clear()
	World.enemy_health.clear()
	var edge_guard: Dictionary = World.sites(Vector2i.ZERO)[1]
	World.cleared.erase(edge_guard.id)
	World.position = edge_guard.p-Vector2(450,0)
	State.stage = 1
	World.splash_damage(edge_guard.p-Vector2(150,0),"primary",10)
	check.call(not World.enemy_units.has(edge_guard.id) and World.enemy_health.has(edge_guard.id) and World.enemy_health[edge_guard.id].hp==122,"splash also hits visible guards outside the active AI cache")
	State.parts.starter()
	State.parts.equip(1,State.parts.inventory[4].id)
	var saved_parts: Dictionary = State.parts.export_save()
	State.save_override = ProjectSettings.globalize_path("res://tests/parts_save_fixture.json")
	State.save_game()
	State.parts.inventory.clear()
	State.load_game()
	check.call(State.parts.export_save()==saved_parts,"disk roundtrip preserves exact rolls, IDs and per-mech loadouts")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(State.save_path()))
	saved.erase("parts")
	var file := FileAccess.open(State.save_path(),FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	State.load_game()
	check.call(State.parts.inventory.size()==7 and State.parts.loadouts[0].size()==6,"legacy saves receive a starter kit without resetting game progress")
	DirAccess.remove_absolute(State.save_path())
	State.save_override = ""
	var malformed: Dictionary = saved_parts.duplicate(true)
	malformed.inventory.append({"id":"bad","blueprint":null,"quality":[]})
	malformed.inventory.append(malformed.inventory[0])
	malformed.inventory[0].affixes = [{"stat":"unknown","value":999},{"stat":"attack","value":[]},{"stat":"crit","value":999}]
	malformed.loadouts = [{"0":[],"1":999},{"0":1},{"0":1}]
	State.parts.import_save(malformed)
	check.call(State.parts.inventory.size()==7 and State.parts.inventory[0].affixes.is_empty() and State.parts.owner(1)==1,"malformed rolls, duplicate IDs and duplicated equipment are sanitized")
	var new_part: Dictionary = State.parts.roll()
	check.call(new_part.id>7,"next unique ID is rebuilt from stored items")
	State.shot.disconnect(count_shot)
	State.weapon_fired.disconnect(count_visual)
	empty_loadout()
	State.parts.import_save(original_parts)
	State.selected = previous_selected
	World.import_save({})
	World.position = World.START
	World.grace = 0
	State.hp = 100
	State.recovery = 0
