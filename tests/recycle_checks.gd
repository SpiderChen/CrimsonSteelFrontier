extends RefCounted

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	World.enabled = false; World.docked = true
	State.parts = State.PARTS.new(); State.parts.starter()
	State.selected_mech = 0; State.recovery = 0; State.sound_enabled = false
	var parts = State.parts
	var first: Dictionary = parts.roll(21,0)
	var keep: Dictionary = parts.roll(0,1)
	var locked: Dictionary = parts.roll(1,0); parts.set_flag(locked.id,"locked",true)
	var preset: Dictionary = parts.roll(2,0)
	parts.equip(1,preset.id); parts.save_preset(1,0); parts.unequip(1,0)
	var pending: Dictionary = parts.roll(15,1); parts.begin_reforge(pending.id,0)
	main.warehouse_slot = 0; main.mechanism_filter = "all"; main.locked_only = false
	main.show_batch_recycle()
	var ui = main.recycle_ui
	check.call(ui.selected.is_empty() and ui.refs.confirm.disabled,"batch recycling opens with no implicit selections or enabled destructive action")
	check.call(not ui.rows.has(1) and not ui.rows.has(locked.id) and not ui.rows.has(preset.id) and not ui.rows.has(pending.id),"equipped, locked, preset-referenced and pending-reforge parts are absent from the batch list")
	check.call(ui.rows.size()==2 and ui.rows.has(first.id) and ui.rows.has(keep.id) and not ui.refs.empty.visible,"batch list contains only the eligible unchecked parts")
	ui.rows[first.id].button_pressed = true
	check.call(ui.selected.has(first.id) and not ui.selected.has(keep.id) and not ui.refs.confirm.disabled,"individual checkboxes select only the requested free part")
	ui.rows[first.id].button_pressed = false
	check.call(ui.selected.is_empty() and ui.refs.confirm.disabled,"unchecking the last part disables the preview action")
	ui.rows[first.id].button_pressed = true; ui.show_preview()
	check.call(ui.refs.confirm.text=="确认分解 1 件","the confirmation displays exactly the manually chosen item count")
	ui.show_list()
	check.call(ui.rows[first.id].button_pressed and not ui.rows[keep.id].button_pressed,"returning from the preview preserves individual selections")
	var before: int = State.cores
	ui.show_preview(); ui.confirm()
	check.call(parts.find_part(first.id).is_empty() and not parts.find_part(keep.id).is_empty() and State.cores==before+6,"confirming dismantles only the checked item and preserves an unchecked eligible part")
	ui.confirm()
	check.call(State.cores==before+6 and not parts.find_part(locked.id).is_empty() and not parts.find_part(preset.id).is_empty(),"repeat confirmation cannot duplicate salvage or touch protected parts")
	main.show_batch_recycle()
	ui.refs.all.get_signal_connection_list("pressed")[0].callable.call()
	check.call(ui.selected.size()==1 and ui.selected.has(keep.id),"select-all respects the current body filter and skips every protected item")
	parts.set_flag(keep.id,"locked",true); ui.refresh()
	check.call(ui.selected.is_empty() and ui.rows[keep.id].disabled and not ui.rows[keep.id].get_parent().visible and ui.refs.empty.visible,"a part locked after selection disappears immediately and leaves a clear empty state")
	parts.set_flag(keep.id,"locked",false)
	ui.refresh(); ui.rows[keep.id].button_pressed = true
	parts.equip(2,keep.id,4); ui.refresh()
	check.call(ui.selected.is_empty() and ui.rows[keep.id].disabled and not ui.rows[keep.id].get_parent().visible,"a part equipped after selection disappears and is revalidated before recycling")
	var legacy = State.PARTS.new()
	var item: Dictionary = legacy.roll(0,0)
	var data: Dictionary = legacy.export_save()
	data.inventory[0].favorite = true; data.inventory[0].locked = false
	legacy.import_save(data); item = legacy.find_part(item.id)
	check.call(item.locked and not item.favorite and not legacy.recyclable(item),"legacy favorites migrate to the single lock flag and retain dismantling protection")
	legacy.set_flag(item.id,"locked",false)
	check.call(not legacy.is_locked(item) and legacy.recyclable(item),"explicitly unlocking a migrated favorite clears all legacy protection flags")
	main.close_modal(); main.locked_only = true; main.show_parts()
	check.call(parts.inventory.filter(func(part): return parts.matches(part,0,"all",true)).size()==1,"the unified locked-only filter includes locks without a duplicate favorites filter")
	main.close_modal(); main.locked_only = false
	State.import_game(original); World.enabled = enabled
