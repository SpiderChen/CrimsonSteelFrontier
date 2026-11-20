extends RefCounted
const CONTENT = preload("res://scripts/story_content.gd")
var radios: Array = []
func hear(kind: String, pilot: int) -> void: radios.append([kind,pilot])

func run(check: Callable, main: Node) -> void:
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	var combat_flags := [State.auto,State.auto_skill]
	var save_override: String = State.save_override
	var ui = main.story_ui
	ui.auto_present = false; main.close_modal()
	State.expedition = State.EXPEDITION.new(); State.parts = State.PARTS.new(); State.parts.starter()
	State.rig = State.RIG_RUNTIME.new(); State.defense = State.DEFENSE_RUNTIME.new()
	State.defense.configure(State.equipment_stats(),true)
	State.selected = 0; State.selected_mech = 0; State.recovery = 0; State.auto = true; State.auto_skill = false
	State.levels = State.initial_pilot_levels(); State.unlocked = State.initial_pilot_unlocks(); State.pilot_roster = State.PILOT_ROSTER.new()
	State.narrative = State.NARRATIVE.new(); State.narrative.import_save(null)
	World.import_save({"docked":true}); World.enabled = true
	main.open_base()
	await main.get_tree().process_frame
	check.call(State.narrative.pending==["prologue"] and State.narrative.objective().key=="launch","new commanders receive a queued prologue and an actionable first-sortie objective")
	var content_ok := true
	for key in CONTENT.ids():
		var data: Dictionary = CONTENT.scene(key)
		content_ok = content_ok and data.lines.size()>=3 and not data.cast.is_empty()
		for entry in data.lines: content_ok = content_ok and entry[0]>=-2 and entry[0]<State.PILOTS.size() and not entry[1].is_empty() and (entry[0]<0 or entry[0] in data.cast)
	check.call(content_ok and CONTENT.SCENES.size()==25,"all campaign, pilot, recovery and personal scenes have complete dialogue and matching portraits")
	ui.auto_present = true; ui.tick(0.01)
	check.call(is_instance_valid(ui.stage) and ui.id=="prologue" and State.story_paused and ui.portraits.size()==2,"first launch automatically presents a two-pilot cinematic and pauses simulation")
	var first_x: float = ui.portraits[0].position.x
	# Give both the UI process and the Tween a frame after long synchronous
	# combat suites; a timer can expire in that first delayed frame.
	for _frame in range(12):
		await main.get_tree().create_timer(0.05).timeout
		if ui.portraits[0].position.x<first_x and ui.dialogue.visible_characters>0: break
	check.call(ui.portraits[0].position.x<first_x and ui.dialogue.visible_characters>0,"portraits animate into frame while dialogue reveals progressively")
	ui.advance(); check.call(ui.line==0 and ui.dialogue.visible_characters==-1,"first advance reveals the current line instead of skipping unread dialogue")
	ui.advance(); check.call(ui.line==1 and State.narrative.cursor==1,"second advance changes speakers and persists the next dialogue cursor")
	State.save_override = ProjectSettings.globalize_path("res://tests/story_save_fixture.json")
	State.save_game(); ui.suspend(); State.load_game(); ui.tick(0.01)
	check.call(ui.id=="prologue" and ui.line==1,"an actual disk reload resumes the unfinished scene at its saved line")
	while ui.line<ui.scene.lines.size()-1: ui.typing = 10000; ui.advance()
	ui.typing = 10000; ui.advance()
	check.call(ui.choosing and not ui.next_button.visible,"the prologue offers an explicit commander response after its dialogue")
	ui.choose_reply(1); State.save_game(); ui.suspend(); State.load_game(); ui.tick(0.01)
	check.call(State.narrative.choices.get("prologue")==1 and "每一个路口" in ui.dialogue.text,"chosen responses survive JSON disk persistence and resume on the actual reply")
	ui.finish(); ui.auto_present = false
	var economy := [State.credits,State.cores,State.gems,State.pilot_roster.export_save()]
	ui.play("prologue"); ui.finish()
	check.call(not State.story_paused and economy==[State.credits,State.cores,State.gems,State.pilot_roster.export_save()] and State.narrative.seen.count("prologue")==1,"skipping or replaying a scene releases pause and cannot duplicate rewards or read records")
	ui.play("debrief_3")
	check.call(not is_instance_valid(ui.stage),"undiscovered final chapters cannot be played from the archive")
	State.narrative.unlock("briefing_1",false); ui.play("briefing_1")
	check.call(not ui.portraits.has(2),"campaign briefings do not portray an unrecruited pilot as a member of the crew")
	ui.finish(); State.unlocked[2] = true; ui.play("briefing_1")
	check.call(ui.portraits.has(2) and ui.scene.lines.any(func(entry): return entry[0]==2),"recruited Frost actively participates in campaign scenes with her own portrait and dialogue")
	ui.line = ui.scene.lines.size()-2; ui.render_line()
	check.call(ui.portraits[2].visible and not ui.portraits[0].visible,"a third speaker enters the conversation without stacking three portraits on screen")
	ui.finish(); State.unlocked[2] = false
	State.narrative.restart_tutorial(); main.open_base(); ui.update_guide()
	check.call(is_instance_valid(ui.guide) and ui.focus_target==main.refs.base_launch,"the carrier tutorial names the real launch control and highlights it")
	check.call(ui.guide.clip_contents and ui.guide.get_children().any(func(n): return n is Label and n.max_lines_visible==3),"compact tutorial hints cannot overflow the carrier facility layout")
	State.expedition.begin(World,0); main.show_page(0)
	check.call(State.narrative.objective().key=="move" and "briefing_0" in State.narrative.pending,"real map launch progresses the guide and queues the correct chapter")
	main.refs.map.camera += Vector2(500,0); World.advance(0.05)
	check.call(not State.narrative.milestones.has("move"),"panning the camera and idle time cannot complete movement training")
	main.refs.map.pointer_press(Vector2(200,650)); main.refs.map.pointer_move(Vector2(270,650))
	for i in range(15): World.advance(0.05)
	main.refs.map.pointer_release(Vector2(270,650))
	check.call(State.narrative.objective().key=="fleet" and not World.patrol,"actual joystick travel advances directly to fleet coordination and leaves movement under player control")
	main.carrier_ui.show_bridge(); State.carrier.ops.set_doctrine("assault"); main.close_modal()
	check.call(State.narrative.objective().key=="interact","choosing a real escort doctrine advances fleet instruction to facility interaction")
	var supply: Dictionary = State.expedition.locations.filter(func(site): return site.kind=="supply")[0]
	World.set_patrol(false); World.navigate(supply.p)
	for i in range(200):
		World.advance(0.05)
		if World.position.distance_to(supply.p)<100: break
	State.expedition.reveal(World.position)
	check.call(State.expedition.interact(World,supply.id,0,State.expedition.run.id) and State.narrative.objective().key=="return","walking to and using an actual facility advances the guide")
	State.expedition.withdraw(World); main.open_base()
	check.call(State.narrative.objective().key=="hangar" and "first_return" in State.narrative.pending,"real extraction queues a return conversation and guides the player into the hangar")
	main.show_page(1)
	check.call(State.narrative.objective().key=="talk","opening the real hangar advances the onboarding objective to pilot interaction")
	main.show_page(2); main.pilot_ui.show_talk(0,0)
	check.call(State.narrative.objective().is_empty() and ui.id=="talk_0_0","an actual pilot conversation completes onboarding through the cinematic interface")
	ui.finish(); main.close_modal()
	State.narrative.tutorial_enabled = false; State.save_game(); State.load_game()
	check.call(not State.narrative.tutorial_enabled and State.narrative.milestones.has("talk"),"guide dismissal and earned learning milestones survive a disk reload")
	State.narrative.restart_tutorial()
	check.call(State.narrative.objective().key=="launch" and State.narrative.milestones.is_empty(),"restarting the guide reopens all lessons without resetting game progress")
	# Each chapter must be discovered through the corresponding real campaign event.
	for region in range(4):
		World.enter_base(); State.hp = 100; State.recovery = 0
		State.expedition.begin(World,region)
		var boss: Dictionary = State.expedition.boss_site()
		World.position = boss.p+Vector2(-180,0); State.expedition.reveal(World.position)
		check.call(State.expedition.start_boss(World,boss.id) and "boss_%d"%region in State.narrative.pending,"region %d boss challenge triggers its pre-battle story"%region)
		ui.play("boss_%d"%region)
		var before := [World.position,World.boss.elapsed,State.hp,State.rig.heat]
		State.advance(2)
		check.call(before==[World.position,World.boss.elapsed,State.hp,State.rig.heat],"region %d cinematic freezes actual movement, boss warnings, damage and heat"%region)
		ui.finish(); State.advance(0.05)
		check.call(World.boss.elapsed>float(before[1]),"region %d simulation resumes after ending the conversation"%region)
		World.boss.hit(World,World.boss.BODY,100000,"rail",World.boss.position)
		check.call("debrief_%d"%region in State.narrative.pending and State.expedition.clears[region]>0,"region %d actual victory unlocks its story conclusion"%region)
	main.open_base(); State.unlocked[2] = false; State.gems = maxi(100,State.gems)
	State.recruit(1)
	check.call("arrival_2" in State.narrative.pending,"first successful Frost recruitment queues her arrival scene")
	State.choose(2); State.choose(2)
	check.call(State.narrative.pending.count("bond_2")==1,"selecting a pilot queues her personal introduction only once")
	State.pilot_radio.connect(hear)
	World.import_save({}); World.enabled = true; World.grace = 0
	World.position = World.START+Vector2(150,170); World.advance(0.01)
	main.show_page(0); main.close_modal(); ui.auto_present = true
	for pilot in range(3):
		State.selected = pilot; State.energy = 100; State.hp = 100; ui.age += 15
		var cast := State.ultimate()
		check.call(cast and ["skill",pilot] in radios and is_instance_valid(ui.radio) and ui.radio.mouse_filter==Control.MOUSE_FILTER_IGNORE and not State.story_paused,"pilot %d actual skill emits a portrait cut-in without intercepting movement or pausing combat"%pilot)
	State.narrative.radio_enabled = false
	var old_radio = ui.radio; ui.age += 15; ui.on_radio("skill",0)
	check.call(ui.radio==old_radio,"disabling battlefield communications suppresses new cut-ins")
	State.pilot_radio.disconnect(hear); ui.auto_present = false
	var prior: Dictionary = State.narrative.export_save()
	var simulator = load("res://scripts/certification.gd")
	var job = simulator.new(simulator.capture(State),0)
	job.actor.story_event("launch",0); job.actor.story_event("skill"); job.actor.record_story_movement(100)
	check.call(prior==State.narrative.export_save(),"detached certification cannot advance real narrative or tutorial progress")
	job.dispose()
	var legacy: Dictionary = State.save_payload(); legacy.erase("narrative")
	State.import_game(legacy)
	check.call(not State.narrative.tutorial_enabled and State.narrative.pending.is_empty() and "debrief_3" in State.narrative.unlocked,"veteran saves gain completed-chapter archives without forced onboarding or queued spoilers")
	State.story_event("launch",3); State.story_event("boss",3); State.story_event("clear",3)
	check.call(State.narrative.pending.is_empty(),"revisiting a completed region in a legacy save does not automatically play archived chapters")
	State.narrative = State.NARRATIVE.new()
	State.story_event("launch",0); State.story_event("boss",0)
	check.call(State.narrative.pending==["briefing_0","boss_0"],"first discovery still queues the sortie briefing and boss conversation")
	State.story_event("return",0); State.narrative.finish("first_return")
	State.save_game(); State.load_game()
	State.story_event("launch",0); State.story_event("boss",0); State.story_event("return",0)
	check.call(State.narrative.pending.is_empty() and "briefing_0" not in State.narrative.seen and "boss_0" not in State.narrative.seen,"unread scenes removed on return stay archived after disk reload and another sortie")
	ui.play("boss_0")
	check.call(is_instance_valid(ui.stage) and ui.id=="boss_0","an archived unread boss conversation remains available for manual reading")
	ui.finish(); State.save_game(); State.load_game(); State.story_event("boss",0)
	ui.auto_present = true; ui.tick(0.01); ui.auto_present = false
	check.call(State.narrative.pending.is_empty() and not is_instance_valid(ui.stage),"skipped scenes stay read after reload and repeated events cannot automatically replay them")
	State.narrative.import_save({"unlocked":["prologue","bogus",7],"seen":["debrief_3"],"pending":["prologue","prologue","bogus"],"active":"bogus","cursor":{},"choices":{"prologue":99},"milestones":{"move":true,"bogus":true},"manual_distance":"bad"})
	check.call(State.narrative.pending==["prologue"] and State.narrative.active=="" and State.narrative.choices.is_empty() and State.narrative.milestones=={"move":true},"malformed narrative saves are bounded and cannot unlock unsupported chapters or choices")
	# Build every scene and each speaking state, including all nine personal chapters.
	State.unlocked = [true,true,true,true,true,true]; main.open_base()
	await main.get_tree().process_frame
	var presentation_ok := true
	for key in CONTENT.ids():
		State.narrative.unlock(key,false); ui.play(key)
		presentation_ok = presentation_ok and is_instance_valid(ui.stage) and Rect2(Vector2.ZERO,Vector2(720,1280)).encloses(Rect2(ui.next_button.position,ui.next_button.size))
		for index in range(ui.scene.lines.size()):
			ui.line = index; ui.render_line()
			presentation_ok = presentation_ok and ui.dialogue.text.length()>0 and ui.portraits.values().filter(func(p): return p.visible).size()<=2
			presentation_ok = presentation_ok and ui.dialogue.get_line_count()*ui.dialogue.get_theme_font("font").get_height(26)<=ui.dialogue.size.y
		ui.finish()
	check.call(presentation_ok,"all 37 authored and personal scenes render every speaker with bounded controls and at most two visible portraits")
	ui.show_archive(); check.call(main.overlay.find_children("*","ScrollContainer",true,false).size()==1,"the replay archive scrolls through unlocked story and personal chapters")
	main.close_modal(); ui.auto_present = false
	DirAccess.remove_absolute(State.save_path()); State.save_override = save_override
	State.import_game(original); World.enabled = enabled; main.open_base()
	State.auto = combat_flags[0]; State.auto_skill = combat_flags[1]
