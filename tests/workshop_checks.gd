extends RefCounted

func run(check: Callable, main: Node) -> void:
	var saved_parts: Dictionary = State.parts.export_save()
	var economy := [State.credits,State.cores,State.stage,State.selected,State.recovery]
	var enabled: bool = World.enabled
	var docked: bool = World.docked
	World.enabled = false; World.docked = true
	State.parts = State.PARTS.new(); State.credits = 10000; State.cores = 1000
	State.stage = 11; State.selected = 0; State.recovery = 0
	var parts = State.parts
	var weapon: Dictionary = parts.roll(0,2)
	weapon.affixes = [{"stat":"attack","value":18},{"stat":"crit","value":6},{"stat":"armor","value":3}]
	weapon.mechanism = "pierce"; parts.equip(0,weapon.id); parts.save_preset(0,0)
	var original: Array = weapon.affixes.duplicate(true)
	var credits: int = State.credits
	check.call(State.reforge_part(weapon.id,1) and State.credits==credits-150 and State.cores==992,"reforge charges its fixed price once and opens three saved proposals")
	var valid: bool = parts.reforge.choices.size()==3
	for choice in parts.reforge.choices:
		valid = valid and choice.stat not in ["attack","armor"] and choice.value>=State.PARTS.AFFIXES[choice.stat].min*3 and choice.value<=State.PARTS.AFFIXES[choice.stat].max*3
	check.call(valid,"reforge proposals respect quality ranges and cannot duplicate other affix stats")
	credits = State.credits
	check.call(not State.reforge_part(weapon.id,1) and not State.upgrade_part(weapon.id) and State.credits==credits,"a pending result cannot be rerolled or upgraded to evade its saved choices")
	var saved: Dictionary = parts.export_save()
	parts.import_save(saved); weapon = parts.find_part(weapon.id)
	check.call(parts.export_save()==saved and not parts.recyclable(weapon),"pending reforge survives a save roundtrip and protects its item from recycling")
	check.call(State.resolve_reforge(-1) and weapon.affixes==original and weapon.reforge_slot==1,"keeping the old result preserves all affixes while retaining the chosen calibration slot")
	check.call(not State.reforge_part(weapon.id,0) and State.credits==credits,"only the first selected affix can be reforged and invalid requests do not charge")
	check.call(State.reforge_part(weapon.id,1),"the chosen calibration slot can be reforged repeatedly at the same fixed price")
	var choice: Dictionary = parts.reforge.choices[0].duplicate()
	check.call(State.resolve_reforge(0) and weapon.affixes[1]==choice and weapon.affixes[0]==original[0] and weapon.affixes[2]==original[2],"choosing a proposal replaces exactly one affix")
	credits = State.credits
	check.call(not State.resolve_reforge(0) and State.credits==credits,"a chosen reforge cannot be applied twice")
	var before_attack: float = parts.stats(0).attack
	var affixes: Array = weapon.affixes.duplicate(true)
	check.call(State.upgrade_part(weapon.id) and weapon.level==2 and is_equal_approx(parts.stats(0).attack,before_attack*1.1),"part upgrade increases actual equipped stats without changing its unique ID")
	check.call(weapon.affixes==affixes and weapon.mechanism=="pierce" and parts.protected(weapon.id),"upgrade retains rolled affixes, mechanism and preset references")
	check.call(State.upgrade_part(weapon.id) and weapon.level==3 and not State.upgrade_part(weapon.id),"part upgrades stop at the current region's level cap")
	State.credits = 0
	var untouched: Dictionary = parts.export_save()
	check.call(not State.reforge_part(weapon.id,1) and parts.export_save()==untouched,"unaffordable reforging changes neither proposals nor calibration locks")
	State.credits = 10000
	for i in range(2):
		var salvage: Dictionary = parts.roll(0,2); salvage.mechanism = "bounce"
		check.call(State.recycle_part(salvage.id) and int(parts.research.get("bounce",0))==3*(i+1),"dismantling a mechanism grants quality-scaled research progress")
	check.call(parts.research_ready("bounce") and not parts.research_ready("pulse"),"six research points permanently unlock only the researched mechanism")
	credits = State.credits
	check.call(not State.install_mechanism(weapon.id,"pulse") and State.credits==credits,"unresearched or incompatible mechanism installation cannot spend resources")
	check.call(State.install_mechanism(weapon.id,"bounce") and weapon.mechanism=="bounce" and weapon.affixes==affixes and weapon.level==3 and State.credits==credits-400,"researched mechanism replaces the existing mechanism and retains numerical rolls and level")
	credits = State.credits
	check.call(not State.install_mechanism(weapon.id,"bounce") and State.credits==credits and parts.research_ready("bounce"),"installing an already active mechanism does not charge or consume permanent research")
	var locked: Dictionary = parts.roll(1,1)
	var favorite: Dictionary = parts.roll(15,1)
	var free: Dictionary = parts.roll(16,1)
	State.set_part_flag(locked.id,"locked",true); State.set_part_flag(favorite.id,"favorite",true)
	check.call(parts.matches(favorite,4,favorite.mechanism,true) and parts.matches(locked,0,"all",true),"inventory filters combine hand compatibility, mechanism and unified lock status")
	check.call(parts.recycle_candidates().size()==1 and parts.recycle_candidates()[0].id==free.id,"batch candidates skip equipped, preset, locked and favorite parts")
	check.call(State.recycle_batch([weapon.id,locked.id,favorite.id,free.id,free.id])==1 and parts.find_part(free.id).is_empty() and not parts.find_part(locked.id).is_empty(),"batch recycling revalidates every ID and never rewards duplicate or protected entries")
	parts.begin_reforge(weapon.id,1)
	saved = parts.export_save(); parts.import_save(saved)
	check.call(parts.export_save()==saved and parts.research_ready("bounce") and parts.find_part(locked.id).locked and parts.find_part(favorite.id).locked and not parts.find_part(favorite.id).favorite,"levels, unified locks, research and reforge proposals persist together")
	parts.resolve_reforge(-1)
	while parts.inventory.size()<parts.LIMIT: parts.roll()
	var drop: Dictionary = parts.roll(16,2,true)
	var drop_snapshot: Dictionary = drop.duplicate(true)
	check.call(parts.inventory.size()==parts.LIMIT and parts.overflow.size()==1 and drop.quality==2 and not parts.find_any(drop.id).is_empty(),"a full warehouse retains the complete rare drop in an overflow warehouse")
	check.call(parts.collect_overflow()==0 and parts.overflow[0]==drop_snapshot,"collecting overflow with no room cannot delete or reroll its contents")
	saved = parts.export_save(); parts.import_save(saved)
	check.call(parts.export_save()==saved and parts.overflow[0]==drop_snapshot,"overflow rolls and their globally unique IDs survive save roundtrip")
	var recyclable: Array = parts.recycle_candidates()
	parts.recycle(recyclable[0].id)
	check.call(parts.collect_overflow()==1 and parts.find_part(drop.id)==drop_snapshot and parts.overflow.is_empty() and parts.collect_overflow()==0,"freeing one slot recovers the same overflow item once without rerolling")
	# Construct the actual facility screens while data includes locks, research and upgraded parts.
	main.show_part_detail(weapon.id); main.show_part_workshop(weapon.id)
	main.show_mechanism_research(weapon.id); main.show_mechanism_filter()
	main.show_batch_recycle(); main.show_overflow()
	parts.begin_reforge(weapon.id,1); main.show_reforge_choices(); main.close_modal()
	check.call(true,"workshop, research, filters, batch preview, overflow and saved reforge screens build")
	State.parts = State.PARTS.new(); State.parts.import_save(saved_parts)
	State.credits = economy[0]; State.cores = economy[1]; State.stage = economy[2]; State.selected = economy[3]; State.recovery = economy[4]
	World.enabled = enabled; World.docked = docked
	State.reset_part_combat()
