extends RefCounted
func run(check: Callable, main: Control) -> void:
	var parts = State.PARTS.new()
	parts.starter()
	var id: int = parts.equipped(0,0).id
	parts.save_preset(0,0)
	parts.unequip(0,0)
	check.call(parts.protected(id) and parts.recycle(id)==0,"presets protect referenced parts even while unequipped")
	parts.equip(1,id)
	check.call(parts.apply_preset(0,0) and parts.equipped(0,0).id==id and parts.equipped(1,0).is_empty(),"applying a preset restores its exact unique items and transfers ownership")
	var snapshot: Dictionary = parts.export_save()
	parts.import_save(snapshot)
	check.call(parts.export_save()==snapshot and parts.protected(id),"preset references and dismantle protection survive save roundtrip")
	var before: Dictionary = parts.loadouts[0].duplicate()
	check.call(not parts.apply_preset(0,9) and parts.loadouts[0]==before,"invalid presets cannot partially mutate current equipment")
	var credits: int = State.credits
	var armor: float = State.hp
	var stage: int = State.stage
	var view := Control.new()
	view.set_script(load("res://scripts/training.gd"))
	main.add_child(view)
	view.set_process(false)
	for kind in range(3):
		view.reset(kind)
		# The collision check deliberately holds position: automatic combat now
		# dodges aimed bullets and can legitimately finish with zero impacts.
		if kind==2: view.manual_control = true
		for i in range(50): view._process(0.1)
		check.call(view.engine.stats.hits>0 and view.engine.stats.damage>0,"training scenario %d measures actual projectile hits" % kind)
	check.call(view.hostile.impacts>0 and view.defense.hits>0,"survival training receives damage from actual enemy projectile collisions")
	check.call(view.incoming>0 and State.credits==credits and State.hp==armor and State.stage==stage,"training measures survival pressure without affecting rewards, progress or real armor")
	view.free()
	World.docked = true
	main.show_training()
	check.call(main.overlay.get_child_count()>0,"training facility opens from the carrier")
	main.close_modal()
	main.show_presets()
	check.call(main.overlay.get_child_count()>0,"preset archive opens from the carrier")
	main.close_modal()
