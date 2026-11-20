extends Node
var checks: int = 0
var failures: int = 0

func check(value: bool, description: String) -> void:
	if not value:
		push_error("FAIL: " + description)
		failures += 1
		return
	checks += 1
	print("PASS: " + description)

func _ready() -> void:
	State.set_process(false)
	World.enabled = false
	State.auto_skill = false
	check(State.test_mode, "tests never write player save")
	if "--weapon-vfx-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		await load("res://tests/weapon_vfx_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--theme-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		World.import_save({"docked":true})
		await load("res://tests/interface_checks.gd").new().check_command_surfaces(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--base-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/base_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--weapon-behavior-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/weapon_behavior_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--large-map-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		await load("res://tests/large_map_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--scenery-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		await load("res://tests/battlefield_scenery_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--units-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		await load("res://tests/unit_3d_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--motion-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		await load("res://tests/motion_visual_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--identity-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/combat_identity_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--fleet-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/fleet_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--story-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		await load("res://tests/story_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--movement-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/movement_mode_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--interface-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		await load("res://tests/interface_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--production-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		await load("res://tests/production_art_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--vehicles-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		await load("res://tests/vehicle_art_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--assets-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/asset_audio_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--carrier-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/carrier_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--shields-only" in OS.get_cmdline_user_args() or "--recycle-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/shield_checks.gd" if "--shields-only" in OS.get_cmdline_user_args() else "res://tests/recycle_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--melee-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/melee_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--manufacturing-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/manufacturing_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--mechs-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/mech_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--cloud-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		await load("res://tests/cloud_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--pilots-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/pilot_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--salvage-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/salvage_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--regions-only" in OS.get_cmdline_user_args():
		var screen = load("res://scenes/main.tscn").instantiate()
		add_child(screen)
		load("res://tests/region_checks.gd").new().run(check,screen)
		Sfx.stop_all(); screen.queue_free()
		await get_tree().process_frame
		print("CHECKS: %d passed, %d failed" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	var initial_cursor := Sfx.cursor
	Sfx.play("click")
	check(Sfx.cursor==initial_cursor,"audio waits for user activation")
	Sfx.activate()
	State.sound_enabled=false
	Sfx.play("laser")
	check(Sfx.cursor==initial_cursor,"global mute suppresses combat audio")
	State.sound_enabled=true
	Sfx.play("click")
	check(Sfx.players[initial_cursor].stream==Sfx.CLIPS["click"],"button feedback uses imported CC0 OGG")
	Sfx.stop_all()
	check(not Sfx.players[initial_cursor].playing,"mute immediately stops active voices")
	Sfx.activated=false
	var base_attack := State.total_attack()
	var cost := State.upgrade_cost(0)
	var cores := State.core_cost(0)
	var previous_credits := State.credits
	var previous_cores := State.cores
	check(State.upgrade(0), "affordable upgrade succeeds")
	check(State.credits==previous_credits-cost and State.cores==previous_cores-cores, "upgrade charges both currencies exactly")
	check(State.total_attack()==base_attack+7, "upgrading increases live squad attack")
	State.credits=0
	var old_level: int=State.levels[0]
	check(not State.upgrade(0) and State.levels[0]==old_level, "insufficient resources cannot upgrade")
	check(not State.upgrade(2), "locked pilots cannot be upgraded")
	State.choose(2)
	check(State.selected==0,"locked pilots cannot be selected")
	var old_gems := State.gems
	check(State.recruit(1), "recruit with stars succeeds")
	check(State.unlocked[2] and State.gems==old_gems-100,"first recruit guarantees third pilot and exact cost")
	check(State.total_attack()>base_attack+7,"new recruit contributes to squad attack")
	State.choose(2)
	check(State.selected==2,"unlocked pilot can become leader")
	var previous_levels: Array=State.levels.duplicate()
	var previous_unlocks: Array=State.unlocked.duplicate()
	State.gems=1100
	check(State.recruit(10),"ten pull works")
	var total_gain:=0
	for i in range(State.PILOTS.size()):
		total_gain += int(State.levels[i])-int(previous_levels[i])
		if State.unlocked[i] and not previous_unlocks[i]: total_gain += 1
	check(total_gain==10 and State.last_pull.size()==10 and State.gems==100,"each pull unlocks one pilot or improves one owned pilot")
	check(not State.recruit(10) and State.gems==100,"unaffordable recruit cannot spend stars")
	State.stage=5
	State.reset_enemy()
	var gems_before:=State.gems
	var wins_before:=State.wins
	State.damage_enemy(100000)
	check(State.stage==6 and State.wins==wins_before+1 and State.gems==gems_before+100,"boss victory advances stage and gives stars")
	check(State.enemy_hp==State.enemy_max,"new enemy has full health")
	State.energy=99
	check(not State.ultimate(),"skill cannot fire without full energy")
	State.energy=100
	check(State.ultimate() and State.energy==0,"charged skill fires and spends energy")
	State.pending_credits=1000
	State.pending_cores=30
	previous_credits=State.credits
	check(State.claim_idle(),"idle resources can be claimed")
	check(State.credits==previous_credits+1000 and State.pending_credits==0 and State.pending_cores==0,"idle claim transfers once")
	check(not State.claim_idle(),"idle reward cannot be claimed twice")
	State.wins=5
	gems_before=State.gems
	check(State.claim_mission(0) and State.gems==gems_before+200,"completed mission grants reward")
	check(not State.claim_mission(0),"mission cannot be claimed twice")
	State.auto=false
	var hp_before:=State.enemy_hp
	State.advance(2.0)
	check(State.enemy_hp==hp_before and State.pending_credits>0,"pause stops combat but production continues")
	State.auto=true
	State.hp=1
	State.stage=200
	State.reset_enemy()
	State.advance(1.0)
	check(State.recovery>0,"defeat enters repair state")
	State.advance(6.0)
	check(State.hp==100 and State.recovery<=0,"repair restarts combat")
	State.save_override=ProjectSettings.globalize_path("res://tests/save_fixture.json")
	State.credits=12345
	State.cores=77
	State.gems=432
	State.stage=6
	State.save_game()
	State.credits=0
	State.load_game()
	check(State.credits==12345 and State.cores==77 and State.gems==432 and State.stage==6,"save roundtrip restores progress")
	var saved=JSON.parse_string(FileAccess.get_file_as_string(State.save_path()))
	var frozen_now := int(Time.get_unix_time_from_system())
	State.settlement_clock_override = frozen_now
	saved.last_seen=frozen_now-48*3600
	saved.salvage.cursor = frozen_now-48*3600
	saved.salvage.age = 0
	saved.salvage.rows = []
	saved.pending_credits=0
	saved.pending_cores=0
	var f=FileAccess.open(State.save_path(),FileAccess.WRITE)
	f.store_string(JSON.stringify(saved))
	f.close()
	State.load_game()
	check(State.offline_seconds==48*3600 and State.pending_credits==State.idle_rate()*36*3600 and State.pending_cores==4320,"forty-eight offline hours receive twenty-four full and twenty-four half-rate hours")
	State.settlement_clock_override = -1
	f=FileAccess.open(State.save_path(),FileAccess.WRITE)
	f.store_string('{"version":1,"levels":[],"unlocked":[]}')
	f.close()
	State.load_game()
	check(State.credits==12345,"malformed save arrays are ignored safely")
	DirAccess.remove_absolute(State.save_path())
	State.save_override=""
	load("res://tests/attack_checks.gd").new().run(check)
	load("res://tests/weapon_family_checks.gd").new().run(check)
	load("res://tests/world_checks.gd").new().run(check)
	load("res://tests/enemy_ai_checks.gd").new().run(check)
	load("res://tests/parts_checks.gd").new().run(check)
	load("res://tests/defense_checks.gd").new().run(check)
	load("res://tests/boss_checks.gd").new().run(check)
	var main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	load("res://tests/base_checks.gd").new().run(check,main)
	World.docked = true
	for i in range(5):
		main.show_page(i)
		check(main.page==i,"portrait navigation page %d builds" % i)
	main.show_page(0)
	load("res://tests/movement_block_checks.gd").new().run(check,main)
	var view = main.refs.map
	for origin in [Vector2(80,100),Vector2(620,870),Vector2(360,500)]:
		view.pointer_press(origin)
		check(view.joystick and view.stick_origin==origin,"floating joystick starts at any screen point %s" % origin)
		check(World.steering==Vector2.ZERO,"press without drag does not move the mech")
		view.pointer_move(origin+Vector2(4,0))
		check(World.steering==Vector2.ZERO,"thumb jitter is suppressed by the dead zone")
		view.pointer_move(origin+Vector2(100,0))
		check(is_equal_approx(World.steering.length(),1.0),"floating stick reaches bounded full speed")
		view.pointer_release(origin+Vector2(100,0))
		check(World.steering==Vector2.ZERO and not World.is_moving(),"lifting thumb stops movement without starting a path")
	var touch := InputEventScreenTouch.new()
	touch.index=0;touch.position=Vector2(250,600);touch.pressed=true
	view._gui_input(touch)
	touch=InputEventScreenTouch.new();touch.index=1;touch.position=Vector2(430,600);touch.pressed=true
	view._gui_input(touch)
	var previous_camera: Vector2=view.camera
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(310,650)
	view._gui_input(drag)
	check(view.pinch and not view.joystick and World.steering==Vector2.ZERO,"second finger switches to camera control without movement")
	check(view.camera!=previous_camera,"two-finger drag pans the map")
	touch=InputEventScreenTouch.new();touch.index=0;touch.position=drag.position;touch.pressed=false
	view._gui_input(touch)
	drag=InputEventScreenDrag.new();drag.index=1;drag.position=Vector2(450,620)
	view._gui_input(drag)
	check(World.steering==Vector2.ZERO,"remaining pinch finger cannot become a stuck joystick")
	touch=InputEventScreenTouch.new();touch.index=1;touch.position=drag.position;touch.pressed=false
	view._gui_input(touch)
	view.recenter()
	check(view.camera==World.position and view.following,"recenter restores camera follow")
	view.zoom_at(10,Vector2(360,400))
	check(view.zoom==1.4,"map zoom upper bound is enforced")
	view.zoom_at(0.01,Vector2(360,400))
	check(is_equal_approx(view.zoom,0.38),"map zoom lower bound is enforced")
	view.primary_finger=7
	view.fingers[7]=Vector2(300,900)
	view.pointer_press(Vector2(300,900));view.pointer_move(Vector2(360,900))
	view.release_fallback(7)
	check(World.steering==Vector2.ZERO and view.fingers.is_empty(),"release over another control cannot leave the joystick stuck")
	view.pointer_press(Vector2(300,900));view.pointer_move(Vector2(350,900));view.reset_input()
	check(World.steering==Vector2.ZERO and view.fingers.is_empty(),"focus loss clears all movement input")
	view.pointer_press(Vector2(200,900));view.pointer_move(Vector2(260,900))
	main.show_missions()
	check(World.steering==Vector2.ZERO,"opening a modal cancels held joystick input")
	check(main.overlay.get_child_count()>0,"mission modal opens")
	main.close_modal()
	check(main.overlay.get_child_count()==0,"modal closes without blocking navigation")
	main.show_page(1)
	main.show_parts()
	check(main.overlay.get_child_count()>0,"parts inventory modal builds")
	for part in State.parts.inventory:
		main.show_part_detail(part.id)
		check(main.overlay.get_child_count()>0,"part detail and comparison build for %s" % State.parts.name_of(part))
	main.close_modal()
	main.show_idle()
	main.close_modal()
	main.show_help()
	main.close_modal()
	load("res://tests/rig_checks.gd").new().run(check)
	load("res://tests/build_checks.gd").new().run(check,main)
	load("res://tests/workshop_checks.gd").new().run(check,main)
	load("res://tests/tactics_checks.gd").new().run(check,main)
	load("res://tests/movement_mode_checks.gd").new().run(check,main)
	load("res://tests/combat_identity_checks.gd").new().run(check,main)
	load("res://tests/weapon_behavior_checks.gd").new().run(check,main)
	await load("res://tests/motion_visual_checks.gd").new().run(check,main)
	await load("res://tests/story_checks.gd").new().run(check,main)
	load("res://tests/fleet_checks.gd").new().run(check,main)
	load("res://tests/region_checks.gd").new().run(check,main)
	load("res://tests/salvage_checks.gd").new().run(check,main)
	load("res://tests/pilot_checks.gd").new().run(check,main)
	load("res://tests/mech_checks.gd").new().run(check,main)
	load("res://tests/manufacturing_checks.gd").new().run(check,main)
	load("res://tests/melee_checks.gd").new().run(check,main)
	load("res://tests/shield_checks.gd").new().run(check,main)
	load("res://tests/recycle_checks.gd").new().run(check,main)
	load("res://tests/carrier_checks.gd").new().run(check,main)
	await load("res://tests/unit_3d_checks.gd").new().run(check,main)
	Sfx.stop_all()
	main.queue_free()
	await get_tree().process_frame
	print("CHECKS: %d passed, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)
