extends RefCounted

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var save_override: String = State.save_override
	var enabled: bool = World.enabled
	World.enabled = false; World.docked = true
	State.recovery = 0; State.selected = 0; State.selected_mech = 0
	State.unlocked.fill(true)
	State.mechs = State.MECHS.new(); State.parts = State.PARTS.new(); State.parts.starter()
	State.credits = 10000; State.cores = 1000
	State.import_tactics({})
	var rolls: Dictionary = State.mechs.export_save()
	var valid := true
	for unit in State.mechs.units:
		valid = valid and unit.affixes.size()==2 and unit.affixes[0].stat!=unit.affixes[1].stat
	check.call(State.mechs.units.size()==6 and valid,"six independent chassis have two distinct permanent affixes each")
	var restored = State.MECHS.new(); restored.import_save(rolls)
	check.call(restored.export_save()==rolls,"chassis levels, IDs and exact affix rolls survive roundtrip")
	var old_rolls: Dictionary = rolls.duplicate(true)
	old_rolls.units = old_rolls.units.slice(0,3)
	old_rolls.units[2].level = 8
	restored.import_save(old_rolls)
	check.call(restored.units.size()==6 and restored.units.slice(0,3)==old_rolls.units and restored.units[5].level==1,"three-chassis saves retain exact original rolls and growth while adding three fresh chassis")
	var old_parts: Dictionary = State.parts.export_save()
	old_parts.loadouts = old_parts.loadouts.slice(0,3); old_parts.presets = old_parts.presets.slice(0,3)
	old_parts.presets[0].append(old_parts.loadouts[0].duplicate(true))
	var migrated_parts = State.PARTS.new(); migrated_parts.import_save(old_parts)
	check.call(migrated_parts.loadouts.size()==6 and migrated_parts.presets.size()==6 and migrated_parts.loadouts.slice(0,3)==old_parts.loadouts and migrated_parts.presets.slice(0,3)==old_parts.presets and migrated_parts.inventory==old_parts.inventory,"legacy equipment and presets keep their original chassis and grow to six independent slots")
	var old_weapon: int = migrated_parts.equipped(0,0).id
	check.call(migrated_parts.equip(5,old_weapon,0) and migrated_parts.owner(old_weapon)==5 and migrated_parts.equipped(0,0).is_empty() and migrated_parts.save_preset(5,2),"sixth chassis accepts equipment and saves its own preset without duplicating shared parts")
	migrated_parts.equip(3,old_weapon,0)
	check.call(migrated_parts.apply_preset(5,2) and migrated_parts.owner(old_weapon)==5 and migrated_parts.equipped(3,0).is_empty(),"new chassis preset restores shared equipment from another new chassis")
	var migrated_save: Dictionary = migrated_parts.export_save()
	migrated_parts.import_save(migrated_save)
	check.call(migrated_parts.export_save()==migrated_save,"six-chassis loadouts and presets survive exact save roundtrip")
	var policy = State.TACTICS.new()
	var mobile: Dictionary = State.TACTICS.resolve(State.TACTICS.defaults(),[{"mode":"standard"}],0,3)
	var artillery: Dictionary = State.TACTICS.resolve(State.TACTICS.defaults(),[{"mode":"standard"}],0,4)
	var fortress: Dictionary = State.TACTICS.resolve(State.TACTICS.defaults(),[{"mode":"standard"}],0,5)
	check.call(mobile.orbit and not artillery.orbit and not fortress.orbit and artillery.range_factor>mobile.range_factor and mobile.style!=artillery.style and fortress.style!=mobile.style,"new chassis produce mobile flanking, long-range artillery and stationary fortress battle policies")
	var missile_pilot: Dictionary = State.TACTICS.resolve(State.TACTICS.defaults(),[{"mode":"missile"}],4,3)
	var support_pilot: Dictionary = State.TACTICS.resolve(State.TACTICS.defaults(),[{"mode":"standard"}],5,3)
	var melee_policy: Dictionary = State.TACTICS.resolve(State.TACTICS.defaults(),[{"mode":"blade"},{"mode":"rail"}],3,4)
	check.call(not missile_pilot.orbit and missile_pilot.range_factor>=0.88 and support_pilot.range_factor>=0.88 and not melee_policy.orbit and melee_policy.style=="贴身格斗" and policy.desired_distance(melee_policy,90)<120,"new ranged pilots retain safe spacing while melee equipment overrides the artillery policy and approaches within skill range")
	var broken: Dictionary = rolls.duplicate(true)
	broken.units[0].affixes = [{"stat":"attack","value":999},{"stat":"cooling","value":-2}]
	broken.units[1].affixes = [{"stat":"not_a_stat","value":2}]
	broken.units[2].level = "bad"
	restored.import_save(broken)
	check.call(restored.units[0].affixes[0].value==7 and restored.units[0].affixes[1].value==2 and restored.units[1].affixes.size()==2 and restored.units[2].level==1,"malformed chassis rolls are sanitized within stat ranges")
	var equipment: Dictionary = State.parts.export_save()
	State.set_tactic("distance","far")
	State.choose(1)
	check.call(State.selected==1 and State.selected_mech==0 and State.parts.export_save()==equipment and State.active_tactics().distance=="far","changing pilot preserves chassis, parts and tactical settings")
	check.call(State.choose_mech(1) and State.selected==1 and State.selected_mech==1,"pilot can freely board a different chassis in the carrier")
	check.call(State.parts.loadouts[0].size()==6 and State.parts.loadouts[1].is_empty(),"changing chassis leaves the original six-slot build on its own chassis")
	var spare: Dictionary = State.parts.inventory[5]
	check.call(State.equip_part(spare.id) and State.parts.equipped(1,2).id==spare.id and State.parts.equipped(0,2).id!=spare.id,"equipment installation targets the active chassis independently of pilot")
	State.set_tactic("distance","close"); State.save_configuration(0)
	var pilot_levels: Array = State.levels.duplicate()
	var attack_before: int = State.total_attack()
	var credits_before: int = State.credits; var cores_before: int = State.cores
	check.call(State.upgrade_mech() and State.mech_level()==2 and State.total_attack()==attack_before+7 and State.credits==credits_before-225 and State.cores==cores_before-7,"chassis upgrade charges once and increases actual chassis firepower")
	check.call(State.levels==pilot_levels and State.mechs.units[0].level==1 and State.mechs.units[1].affixes==rolls.units[1].affixes,"chassis upgrade preserves pilot growth, other chassis and permanent rolls")
	State.choose(0)
	check.call(State.selected_mech==1 and State.active_tactics().distance=="close" and State.parts.presets[1][0].get("2")==spare.id,"pilot replacement retains the current chassis preset and tactics")
	check.call(is_equal_approx(State.weapon_range(0),300*1.15),"long-range chassis extends actual weapon range by fifteen percent")
	State.choose_mech(0)
	var raw_config: Dictionary = State.parts.configuration(0)
	var chassis: Dictionary = State.mechs.stats(0)
	check.call(is_equal_approx(State.mech_configuration().cooling,raw_config.cooling+chassis.cooling) and chassis.cooling>=8,"cooling chassis trait and random cooling affix enter the real thermal configuration")
	check.call(State.active_tactics().distance=="far" and State.mechs.units[0].level==1,"switching back restores the chassis's own tactics and growth")
	State.choose_mech(2)
	check.call(State.equipment_stats().shield>=12 and State.mech_configuration().capacity>=125,"heavy chassis applies base shield and additional load capacity")
	State.choose_mech(3)
	check.call(State.mech_configuration().base_speed==210 and State.mech_configuration().cooling>=4,"vector chassis applies its 210 base speed and cooling bonus")
	State.choose_mech(4)
	check.call(State.mech_configuration().base_speed==145 and is_equal_approx(State.weapon_range(0),300*1.25) and State.mechs.stats(4).supply>=12 and State.mech_configuration().supply>=State.parts.configuration(4).supply+12,"artillery chassis applies its speed, range and power-supply bonuses in battle configuration")
	State.choose_mech(5)
	check.call(State.mech_configuration().base_speed==110 and State.equipment_stats().shield>=24 and State.mech_configuration().capacity>=140,"fortress chassis applies its distinct speed, shield and capacity in battle configuration")
	State.choose_mech(2)
	State.choose(1)
	var training = load("res://scripts/training.gd").new()
	main.add_child(training); training.set_process(false)
	check.call(training.profile.pilot==1 and training.profile.stats==State.equipment_stats() and training.configuration==State.mech_configuration(),"training combines independently selected pilot and chassis with real traits and rolls")
	training.free()
	var simulator = load("res://scripts/certification.gd")
	var snapshot: Dictionary = simulator.capture(State)
	var job = simulator.new(snapshot,0)
	check.call(snapshot.pilot==1 and snapshot.mech==2 and snapshot.mechs==State.mechs.export_save() and job.actor.selected==1 and job.actor.selected_mech==2 and job.actor.equipment_stats()==State.equipment_stats(),"certification snapshots preserve separate pilot and chassis identities and exact rolls")
	job.dispose()
	State.save_override = ProjectSettings.globalize_path("res://tests/mechs_save_fixture.json")
	State.save_game()
	State.selected_mech = 0; State.selected = 0; State.mechs.starter()
	State.load_game()
	check.call(State.selected==1 and State.selected_mech==2 and State.mechs.units[1].level==2 and State.mechs.units[1].affixes==rolls.units[1].affixes,"actual disk reload restores independent selections, chassis upgrade and original random rolls")
	DirAccess.remove_absolute(State.save_path()); State.save_override = save_override
	var legacy: Dictionary = State.save_payload().duplicate(true)
	legacy.erase("selected_mech"); legacy.erase("mechs")
	legacy.selected = 1
	var legacy_parts: Dictionary = legacy.parts.duplicate(true)
	State.import_game(legacy)
	check.call(State.selected==1 and State.selected_mech==1 and State.parts.export_save()==legacy_parts and State.levels==pilot_levels,"legacy bound saves retain their active build, every part and pilot growth")
	main.show_page(1); main.show_mechs()
	check.call(main.overlay.get_child_count()>0,"independent hangar renders all chassis traits, rolls and boarding controls")
	main.close_modal()
	World.docked = false
	check.call(not State.choose_mech(2) and State.selected_mech==1,"chassis changes are blocked outside the carrier")
	State.import_game(original); World.enabled = enabled
