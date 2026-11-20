extends RefCounted

func run(check: Callable, main: Control) -> void:
	# This fixture exercises actual battlefield death/recall even in --base-only.
	var original_enabled: bool = World.enabled
	World.enabled = true
	World.import_save({"docked":false})
	World.position = Vector2(1600,1200)
	World.steering = Vector2.RIGHT
	World.patrol = true
	World.encounter_id = "respawn-test"
	State.enemy_hp = 37
	State.enemy_max = 200
	State.hp = 1
	State.recovery = 0
	State.receive_enemy_hit(10000)
	check.call(World.docked and World.position==World.START and State.recovery==5,"armor depletion recalls the mech to its carrier recovery point")
	check.call(World.steering==Vector2.ZERO and not World.patrol and World.path.is_empty(),"carrier recovery cancels held input, route and patrol")
	check.call(World.enemy_health["respawn-test"].hp==37,"recall preserves damage on the abandoned enemy")
	main.open_base()
	check.call(main.page==4 and is_instance_valid(main.refs.base_status),"defeat opens the carrier facility hub")
	check.call(not World.launch(),"launch is blocked while carrier repair is incomplete")
	State.save_override = ProjectSettings.globalize_path("res://tests/base_save_fixture.json")
	State.save_game()
	World.position = Vector2.ZERO
	World.docked = false
	State.recovery = 0
	State.hp = 100
	State.load_game()
	check.call(World.docked and World.position==World.START and State.recovery==5 and State.hp==0,"reload preserves the carrier recovery state")
	DirAccess.remove_absolute(State.save_path())
	State.save_override = ""
	State.advance(5.1)
	check.call(State.hp==100 and State.recovery<=0 and World.docked,"repair completes with full armor inside the carrier")
	check.call(not State.receive_enemy_hit(10000),"docked mechs are protected from enemy damage")
	State.advance(10)
	check.call(World.position==World.START and World.encounter_id=="","carrier stays stationary and does not acquire battlefield targets")
	check.call(World.launch() and not World.docked and World.position==World.START,"departure launches from the carrier rather than the death location")
	main.show_page(0)
	main.show_page(1)
	check.call(main.page==0 and main.overlay.get_child_count()>0,"field access to facilities asks the player to return to the carrier")
	main.close_modal()
	World.position = Vector2(1600,1200)
	World.enter_base()
	main.open_base()
	main.show_page(1)
	check.call(main.page==1 and World.position==World.START,"manual recall unlocks the carrier facilities at the recovery point")
	check.call(not main.refs.has("shell_nav") and main.refs.home_back.visible and main.toast_label.position.y>1169,"facility pages use a top return control and release the former bottom navigation space")
	var pilot: int = State.selected
	var mech: int = State.selected_mech
	for page in [1,2,3]:
		main.show_page(page)
		main.refs.home_back.get_signal_connection_list("pressed")[0].callable.call()
		check.call(main.page==4 and not main.refs.home_back.visible and World.docked and State.selected==pilot and State.selected_mech==mech,"top return from page %d reaches the carrier without changing pilot or chassis" % page)
	var facilities: Array = main.body.find_children("Facility_*","Button",false,false)
	check.call(facilities.size()==4 and main.body.find_children("*","ScrollContainer",true,false).is_empty(),"carrier home exposes only four frequent facilities without scrolling")
	var fits := true
	for i in range(facilities.size()):
		var card: Button = facilities[i]
		fits = fits and card.is_visible_in_tree() and Rect2(24,640,672,340).encloses(card.get_rect()) and card.size.y>=80
		fits = fits and main.refs.base_launch.get_rect().end.y<card.position.y
		for j in range(i): fits = fits and not card.get_rect().intersects(facilities[j].get_rect())
	check.call(fits,"carrier facilities retain generous separate hit areas below the prominent departure action")
	for id in ["hangar","parts","pilots","salvage"]:
		main.open_base()
		activate(main.refs["base_facility_"+id])
		var destination: int = {"hangar":1,"pilots":2}.get(id,4)
		check.call(main.page==destination and (destination!=4 or main.overlay.get_child_count()>0),"carrier home opens %s directly with one facility click" % id)
		main.close_modal()
	var balance: Array = [State.credits,State.cores,State.gems]
	var sections := {"build":["manufacturing","training","presets","tactics"],"fleet":["carrier","exchange","missions"],"archive":["cloud","story"]}
	for section in sections:
		var entries: Array = sections[section]
		for id in entries:
			main.open_base()
			if section=="build":
				activate(main.refs.base_facility_hangar)
				activate(main.refs.build_tools)
			else:
				activate(main.refs.base_fleet if section=="fleet" else main.refs.base_archive)
			var menu: Control = main.overlay.get_child(main.overlay.get_child_count()-1)
			var control: Button = main.refs["base_facility_"+id]
			check.call(control.is_visible_in_tree() and Rect2(0,0,menu.size.x,menu.size.y).encloses(control.get_rect()),"secondary navigation exposes a usable %s control" % id)
			check.call([State.credits,State.cores,State.gems]==balance,"opening the %s section spends no resources" % section)
			activate(control)
			check.call(not is_instance_valid(menu) and main.overlay.get_child_count()>0,"selecting %s replaces its section with the destination" % id)
			main.close_modal()
			check.call(main.overlay.get_child_count()==0 and World.docked,"closing %s returns to the docked page without a leftover blocking menu" % id)
		main.open_base()
		if section=="build":
			activate(main.refs.base_facility_hangar)
			activate(main.refs.build_tools)
		else:
			activate(main.refs.base_fleet if section=="fleet" else main.refs.base_archive)
		activate(find_button(main.overlay,"返回"))
		check.call(main.overlay.get_child_count()==0 and main.page==(1 if section=="build" else 4),"the %s section return button reaches its parent page" % section)
	main.open_base()
	activate(main.refs.base_facility_pilots)
	activate(main.refs.pilot_recruit)
	check.call(main.page==3,"recruitment remains reachable from the pilot page")
	main.open_base()
	activate(main.refs.base_facility_parts)
	var overflow_button: Button = find_button(main.overlay,"溢出")
	check.call(is_instance_valid(overflow_button),"the warehouse retains an overflow storage entrance even when no home notice is needed")
	if is_instance_valid(overflow_button):
		activate(overflow_button)
		check.call(main.overlay.get_child_count()>0,"the warehouse overflow entrance opens storage")
	main.close_modal()
	var saved_claimed: Array = State.claimed.duplicate()
	var saved_wins: int = State.wins
	var saved_overflow: Array = State.parts.overflow.duplicate(true)
	State.claimed = [0,1,2]
	State.parts.overflow.clear()
	main.open_base()
	check.call(not main.refs.base_notice_missions.visible and not main.refs.base_notice_overflow.visible,"empty or already claimed tasks leave no home notification buttons")
	State.claimed.erase(0)
	State.wins = maxi(State.wins,State.mission_goal(0))
	State.parts.overflow.append(State.parts.inventory[0].duplicate(true))
	main.refresh_base()
	check.call(main.refs.base_notice_missions.visible and main.refs.base_notice_overflow.visible,"claimable rewards and retained loot reveal their contextual shortcuts")
	var notice_claimed: Array = State.claimed.duplicate()
	activate(main.refs.base_notice_missions)
	check.call(State.claimed==notice_claimed and [State.credits,State.cores,State.gems]==balance,"opening a reward notice never claims or spends automatically")
	main.close_modal()
	activate(main.refs.base_notice_overflow)
	check.call(State.parts.overflow.size()==1,"opening an overflow notice never retrieves or removes loot automatically")
	main.close_modal()
	State.claimed = saved_claimed
	State.wins = saved_wins
	State.parts.overflow = saved_overflow
	main.open_base()
	World.enabled = original_enabled

func activate(control: Button) -> void:
	control.get_signal_connection_list("pressed")[0].callable.call()

func find_button(parent: Node, fragment: String) -> Button:
	for child in parent.get_children():
		if child is Button and fragment in child.text: return child
		var found := find_button(child,fragment)
		if is_instance_valid(found): return found
	return null
