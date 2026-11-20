extends RefCounted

func buttons(node: Node) -> Array:
	return node.find_children("*","Button",true,false)

func titles(node: Node) -> Array:
	return buttons(node).map(func(button): return button.text)

func invoke(button: Button) -> void:
	button.get_signal_connection_list("pressed")[0].callable.call()

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	World.enabled = false; World.docked = true
	State.recovery = 0; State.selected_mech = 0
	State.parts = State.PARTS.new(); State.parts.starter()
	State.expedition = State.EXPEDITION.new()
	State.credits = 5000; State.cores = 200
	State.sound_enabled = false
	main.show_page(1)
	var labels: Array = titles(main.body)
	check.call(labels.count("机库 · 更换机体")==1 and not labels.has("机体特性与词条 ›") and not labels.any(func(title): return "制造" in title),"hangar keeps one chassis picker and no manufacturing actions")
	main.show_parts()
	check.call(not titles(main.overlay).any(func(title): return "制造" in title),"warehouse exposes equipment management without manufacturing actions")
	main.close_modal(); main.show_page(4)
	invoke(main.refs.base_facility_hangar)
	invoke(main.refs.build_tools)
	var factory_entry: Button = null
	for button in buttons(main.overlay):
		if button.find_children("*","Label",true,false).any(func(label): return label.text=="制造工坊"): factory_entry = button
	check.call(factory_entry!=null,"hangar construction tools provide the dedicated manufacturing entry")
	if factory_entry!=null: invoke(factory_entry)
	var catalog: Dictionary = State.parts.export_save()
	var ui = main.manufacturing_ui
	ui.slot_filter = 1; ui.show_catalog()
	var list: Node = main.overlay.find_children("*","ScrollContainer",true,false)[0].get_child(0)
	check.call(list.get_child_count()==3 and State.credits==5000 and State.parts.export_save()==catalog,"browsing body-specific blueprints never spends resources or creates equipment")
	ui.show_design(15)
	check.call(not ui.refs.confirm.disabled and State.credits==5000 and State.cores==200,"blueprint selection shows an affordable confirmation without spending")
	var loadouts: Array = State.parts.loadouts.duplicate(true)
	var before: int = State.parts.inventory.size()
	invoke(ui.refs.confirm)
	check.call(State.credits==4550 and State.cores==185 and State.parts.inventory.size()==before+1 and State.parts.inventory.back().blueprint==15,"confirming manufacture charges once and creates exactly the selected blueprint")
	check.call(State.parts.loadouts==loadouts and titles(main.overlay).has("返回制造工坊"),"manufacturing displays its own receipt and preserves every chassis loadout")
	ui.craft()
	check.call(State.credits==4550 and State.parts.inventory.size()==before+1,"a queued duplicate manufacture action cannot charge again after the receipt opens")
	ui.show_design(17)
	check.call(ui.refs.confirm.disabled and "解锁条件" in ui.refs.status.text,"locked named blueprints show their unlock condition and cannot be manufactured")
	ui.craft()
	check.call(State.credits==4550,"locked blueprint attempts never charge resources")
	State.expedition.clears[0] = 1; ui.refresh()
	check.call(not ui.refs.confirm.disabled,"a newly unlocked named blueprint becomes available in the same confirmation")
	ui.craft()
	check.call(State.parts.inventory.back().blueprint==17 and State.parts.inventory.back().mechanism=="pierce","unlocked named blueprint manufacturing preserves its signature mechanism")
	ui.show_design(0)
	State.credits = 449; ui.refresh()
	ui.craft()
	check.call(ui.refs.confirm.disabled and State.credits==449,"resource changes while confirmation is open update affordability before purchase")
	State.credits = 1000; State.cores = 100
	while State.parts.inventory.size()<State.PARTS.LIMIT: State.parts.roll()
	ui.craft()
	check.call(ui.refs.confirm.disabled and State.credits==1000 and State.cores==100 and State.parts.inventory.size()==State.PARTS.LIMIT,"a warehouse filled after blueprint selection blocks manufacture before payment")
	main.show_region_detail(0)
	check.call(not titles(main.overlay).any(func(title): return "制造" in title),"region details describe blueprint unlocks without a second manufacturing action")
	World.docked = false
	ui.show_design(0)
	check.call(not titles(main.overlay).has("确认制造一件") and State.credits==1000,"workshop access outside the carrier cannot create a purchase confirmation")
	main.close_modal(); ui.slot_filter = -1
	State.import_game(original); World.enabled = enabled
