extends RefCounted

func settle(main: Node) -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	World.import_save({"docked":true}); World.enabled = false
	State.recovery = 0; State.selected_mech = 0; State.selected = 0
	State.gems = 600; State.unlocked[3] = false; State.unlocked[5] = false
	main.portrait_index = 3; main.show_page(2)
	var tabs: Array = []
	var fits := true
	for index in range(State.PILOTS.size()):
		var tab: Button = main.body.get_node("PilotTab_%d"%index)
		tabs.append(tab)
		fits = fits and Rect2(24,280,672,106).encloses(tab.get_rect()) and tab.size.y>=48
		for other in tabs.slice(0,tabs.size()-1): fits = fits and not tab.get_rect().intersects(other.get_rect())
	check.call(tabs.size()==6 and fits,"all six pilot tabs retain separate touch targets above the portrait")
	check.call(is_instance_valid(main.refs.direct_recruit) and not main.refs.direct_recruit.disabled,"locked pilot exposes an affordable directed recruitment action")
	main.refs.direct_recruit.pressed.emit()
	await settle(main)
	check.call(State.unlocked[3] and State.gems==300 and is_instance_valid(main.refs.get("deploy")) and not is_instance_valid(main.refs.get("direct_recruit")),"direct recruitment unlocks the selected pilot once and refreshes the profile actions")
	main.body.get_node("PilotTab_5").pressed.emit()
	await settle(main)
	check.call(main.portrait_index==5 and main.body.has_node("PilotPortrait_5"),"second-row pilot selection opens the correct profile")
	State.gems = 0; main.refresh()
	check.call(main.refs.direct_recruit.disabled,"directed recruitment disables while star crystals are insufficient")
	for index in range(3,6):
		var full: AtlasTexture = main.portrait_texture(index,1.6)
		var compact: AtlasTexture = main.portrait_texture(index,1.2,true)
		check.call(full.atlas.resource_path==main.PILOT_PORTRAITS[index] and compact.atlas==full.atlas and compact.region.size.x<full.region.size.x and Rect2(Vector2.ZERO,full.atlas.get_size()).encloses(compact.region),"pilot %d uses its own portrait asset and a bounded head crop"%index)
	main.show_mechs(0)
	check.call(main.overlay.find_child("ChassisCard_0",true,false)!=null and main.overlay.find_child("ChassisCard_2",true,false)!=null and main.overlay.find_child("ChassisCard_3",true,false)==null,"first hangar page presents three original chassis without overflow")
	main.overlay.find_child("MechNext",true,false).pressed.emit()
	await settle(main)
	var new_cards := true
	for index in range(3,6):
		var card: Control = main.overlay.find_child("ChassisCard_%d"%index,true,false)
		var preview: Control = main.overlay.find_child("ChassisPreview_%d"%index,true,false)
		new_cards = new_cards and is_instance_valid(card) and Rect2(0,130,648,750).encloses(card.get_rect()) and is_instance_valid(preview) and not preview.get_meta("mech_3d_views",{}).is_empty()
	check.call(main.mech_page==1 and new_cards,"second hangar page fits three new chassis and instantiates their real 3D previews")
	main.overlay.find_child("ChooseChassis_5",true,false).pressed.emit()
	await settle(main)
	check.call(State.selected_mech==5 and State.selected==0 and main.page==1,"new chassis can be selected from its card without replacing the active pilot")
	main.show_mechs()
	check.call(main.mech_page==1 and main.overlay.find_child("ChooseChassis_5",true,false).disabled,"opening the hangar follows the selected chassis page")
	main.show_motion_review()
	var stage: Control = main.overlay.find_child("MotionReview",true,false)
	var review_fits := true
	for index in range(6):
		var option: Button = main.overlay.find_child("ReviewChassis_%d"%index,true,false)
		review_fits = review_fits and is_instance_valid(option) and not option.get_rect().intersects(stage.get_rect())
	main.overlay.find_child("ReviewChassis_5",true,false).pressed.emit()
	await settle(main)
	check.call(review_fits and stage.model==5,"motion review exposes all six chassis above a usable live preview")
	main.close_modal()
	var sequence := preload("res://scripts/recruit_sequence.gd").new()
	main.overlay.add_child(sequence)
	sequence.setup(main,["SSR  雷娜 · 新机师","SSR  星澜 · 新机师","SSR  伊芙 · 新机师"])
	var matched := true
	for index in range(3):
		var portraits: Array = sequence.cards[index].find_children("*","TextureRect",true,false)
		matched = matched and portraits.size()==1 and portraits[0].texture.atlas.resource_path==main.PILOT_PORTRAITS[index+3]
	check.call(matched,"recruitment results map all three new names to their own portrait assets")
	sequence.free(); main.show_page(0)
	var auto_present: bool = main.story_ui.auto_present
	main.story_ui.auto_present = true; State.narrative.radio_enabled = true
	for index in range(3,6):
		main.story_ui.last_radio.clear()
		main.story_ui.on_radio("skill",index)
		if not is_instance_valid(main.story_ui.radio):
			check.call(false,"new pilot %d can appear in skill radio without a roster cap"%index)
			continue
		var portraits: Array = main.story_ui.radio.find_children("*","TextureRect",true,false)
		check.call(portraits.size()==1 and portraits[0].texture.atlas.resource_path==main.PILOT_PORTRAITS[index],"new pilot %d can appear in skill radio without a roster cap"%index)
	main.story_ui.auto_present = auto_present
	State.import_game(original); main.open_base()
