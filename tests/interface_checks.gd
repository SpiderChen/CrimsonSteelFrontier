extends RefCounted
func run(check: Callable, main: Node) -> void:
	var original: Dictionary=State.save_payload().duplicate(true)
	World.import_save({"docked":true});World.enabled=false
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	await check_command_surfaces(check,main)
	State.gems=2500;State.unlocked[2]=false
	main.show_page(3)
	main.pull(1)
	var sequence=main.recruit_sequence
	sequence.set_process(false)
	check.call(State.gems==2400 and State.unlocked[2],"recruitment commits cost and first pilot before presentation")
	check.call(sequence.cards.size()==1 and not sequence.confirm.visible,"single recruit begins with hidden result and confirmation")
	var committed: Array=State.last_pull.duplicate()
	main.pull(10)
	check.call(State.gems==2400 and State.last_pull==committed,"repeated activation during animation cannot charge or reroll")
	sequence._process(0.9)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	check.call(not sequence.complete and sequence.heading.text=="同调链路已锁定","recruitment advances through the signal-lock stage")
	sequence._process(0.9)
	check.call(sequence.cards[0].modulate.a>0 and sequence.cards[0].modulate.a<1,"portrait progressively reveals after charge")
	sequence.reveal_all()
	check.call(sequence.complete and sequence.confirm.visible and not sequence.skip.visible,"skip reveals the committed card and enables confirmation")
	sequence.finish()
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	check.call(not is_instance_valid(main.recruit_sequence) and main.page==3,"confirm closes presentation and returns to recruitment")
	main.pull(10);sequence=main.recruit_sequence;sequence.set_process(false)
	check.call(State.gems==1400 and sequence.cards.size()==10,"ten-pull renders ten real committed results for one charge")
	sequence._process(1.8)
	check.call(sequence.cards[0].modulate.a>0 and sequence.cards[9].modulate.a==0,"ten-pull reveals cards in order")
	sequence._process(2)
	check.call(sequence.complete and sequence.cards.all(func(c):return c.modulate.a==1),"ten-pull naturally completes with every result visible")
	check.call(sequence.cards.all(func(c):return Rect2(0,210,720,900).encloses(c.get_rect())),"all ten cards fit above the confirmation button")
	sequence.finish()
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	State.gems=0;main.pull(1)
	check.call(not is_instance_valid(main.recruit_sequence),"insufficient currency never starts an empty animation")
	main.show_page(0)
	var style=main.refs.ultimate.get_theme_stylebox("normal")
	check.call(style is StyleBoxFlat and style.corner_radius_top_left>=32,"primary skill uses a rounded silhouette distinct from equipment cards")
	check.call(main.refs.hud_hp_bar.size.y>=10 and main.refs.hud_heat_bar.size.y>=8,"combat meters have readable thickness")
	var controls: Array=[main.refs.support_cannon,main.refs.support_repair,main.refs.hud_interact,main.refs.hud_return,main.refs.ultimate]
	var fits := true
	for i in range(controls.size()):
		fits = fits and Rect2(0,0,720,1280).encloses(controls[i].get_rect()) and controls[i].size.y>=72
		for j in range(i):fits = fits and not controls[i].get_rect().intersects(controls[j].get_rect())
	check.call(fits,"compact combat controls retain separate generous touch areas inside the viewport")
	check.call(main.refs.support_cannon.position.y>=1016 and main.refs.hud_return.size.x==80,"support row frees the former lower-map button band and return is compact")
	main.refs.map.queue_redraw();await main.get_tree().process_frame;await main.get_tree().process_frame
	await preload("res://tests/roster_ui_checks.gd").new().run(check,main)
	State.import_game(original);main.open_base()

func check_command_surfaces(check: Callable, main: Node) -> void:
	main.open_base()
	var holder := Control.new()
	main.add_child(holder);holder.hide()
	var regular: Button = main.button(holder,"普通操作",Rect2(0,0,240,80),func(): pass)
	var launch: Button = main.refs.base_launch
	var facility: Button = main.refs.base_facility_hangar
	var compact: Button = main.refs.base_archive
	var skins: Array = []
	var readable := true
	for control in [launch,facility,regular]:
		var style := control.get_theme_stylebox("normal") as StyleBoxTexture
		readable = readable and style!=null
		if style!=null:
			var picture: Image = style.texture.get_image()
			readable = readable and not picture.is_empty() and picture.get_pixel(picture.get_width()/2,picture.get_height()/2).a>0.9
			skins.append(picture.get_data())
	check.call(readable and skins.size()==3 and skins[0]!=skins[1] and skins[1]!=skins[2] and skins[0]!=skins[2] and compact.get_theme_stylebox("normal") is StyleBoxFlat,"departure, facilities, ordinary actions and compact utilities have distinct readable surfaces")
	var different_states := true
	var clear_focus := true
	for control in [launch,facility,regular]:
		var images: Array = []
		for state in ["normal","hover","pressed","disabled","focus"]:
			var style := control.get_theme_stylebox(state) as StyleBoxTexture
			if style==null or style.texture==null:
				different_states = false
				continue
			var picture: Image = style.texture.get_image()
			if picture.is_empty():
				different_states = false
				continue
			var bytes: PackedByteArray = picture.get_data()
			for previous in images: different_states = different_states and bytes!=previous
			images.append(bytes)
			if state=="focus":
				clear_focus = clear_focus and picture.get_pixel(picture.get_width()/2,picture.get_height()/2).a==0 and picture.get_used_rect().has_area()
				var cut_x: int = picture.get_width()-3 if control==facility else 2
				clear_focus = clear_focus and picture.get_pixel(cut_x,2).a==0
	check.call(different_states,"armored controls render distinguishable hover, pressed, disabled and keyboard focus skins")
	check.call(clear_focus,"keyboard focus preserves transparent cut corners and never paints over button content")
	var sizes: Array = []
	for height in [40,52,64]:
		for primary in [false,true]:
			var button: Button = main.button(holder,"确认",Rect2(0,0,120,height),func(): pass,primary)
			sizes.append([button,Vector2(120,height)])
	await main.get_tree().process_frame
	var sizes_fit := true
	for entry in sizes:
		var minimum: Vector2 = entry[0].get_combined_minimum_size()
		sizes_fit = sizes_fit and minimum.x<=entry[1].x and minimum.y<=entry[1].y and entry[0].size==entry[1]
	check.call(sizes_fit,"both primary and compact skins preserve 40 to 64 pixel button bounds without enlarging hit areas")
	# These are individual generated skins, not screenshots of an unrendered interface.
	if "--skin-artifacts" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://.local/ui-refresh")
		for sample in [["launch",launch],["facility",facility],["standard",regular]]:
			for state in ["normal","hover","pressed","disabled","focus"]:
				var style: StyleBoxTexture = sample[1].get_theme_stylebox(state)
				style.texture.get_image().save_png("res://.local/ui-refresh/skin-%s-%s.png" % [sample[0],state])
	holder.free()
