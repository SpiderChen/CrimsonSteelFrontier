extends RefCounted
const CONTENT = preload("res://scripts/story_content.gd")
var app: Node
var auto_present: bool = false
var layer: Control
var stage: Control
var guide: Control
var radio: Control
var dialogue: Label
var speaker: Label
var counter: Label
var next_button: Button
var portraits: Dictionary = {}
var id: String = ""
var scene: Dictionary = {}
var line: int = 0
var replay: bool = false
var completion: Callable
var typing: float = 0
var age: float = 0
var radio_until: float = 0
var last_radio: Dictionary = {}
var guide_key: String = ""
var danger_announced: bool = false
var choice_box: Control
var choosing: bool = false
var ring: Control
var focus_target: Control

func _init(owner: Node) -> void: app = owner

func setup() -> void:
	auto_present = not State.test_mode
	layer = Control.new(); layer.name = "PilotPresence"; layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = Vector2(720,1280); app.add_child(layer); app.move_child(layer,app.overlay.get_index())
	ring = Control.new(); ring.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(ring)
	ring.draw.connect(func():
		if is_instance_valid(focus_target) and focus_target.is_visible_in_tree():
			var rect := Rect2(focus_target.global_position-app.global_position,focus_target.size).grow(4)
			ring.draw_rect(rect,Color(0.9,0.78,0.55,0.55+sin(age*3)*0.25),false,3,true))
	State.pilot_radio.connect(on_radio)

func tick(delta: float) -> void:
	age += delta
	if is_instance_valid(stage):
		typing += delta*34
		dialogue.visible_characters = int(typing)
		next_button.text = "显示全文" if dialogue.visible_characters<dialogue.text.length() else "继续  ›" if line<scene.lines.size()-1 else "回应" if scene.has("choice") and not State.narrative.choices.has(id) else "结束通讯"
		return
	if not auto_present: return
	if not State.narrative.radio_enabled and is_instance_valid(radio): radio.hide()
	if app.overlay.get_child_count()==0 and not Cloud.holds_combat():
		var held: bool = is_instance_valid(app.refs.get("map")) and (app.refs.map.joystick or app.refs.map.manual_steering)
		if not held:
			var next: String = State.narrative.active if State.narrative.active!="" else str(State.narrative.pending[0]) if not State.narrative.pending.is_empty() else ""
			if next!="": play(next); return
	update_guide()
	layer.visible = app.overlay.get_child_count()==0
	ring.queue_redraw()
	if is_instance_valid(radio):
		radio.visible = State.narrative.radio_enabled and app.page==0 and age<radio_until
		radio.modulate.a = minf(1,(radio_until-age)*2)
	if World.docked: danger_announced = false
	elif State.hp<=30 and State.hp>0 and not danger_announced:
		danger_announced = true; on_radio("danger",State.selected)

func play(scene_id: String, after: Callable = Callable()) -> void:
	if is_instance_valid(stage) or scene_id not in State.narrative.unlocked: return
	scene = CONTENT.scene(scene_id)
	if scene.is_empty(): return
	if scene.has("guest_line") and State.unlocked[2]:
		scene.cast.append(2); scene.lines.insert(scene.lines.size()-1,[2,scene.guest_line])
	if scene_id=="first_return" and State.narrative.choices.get("prologue",0)==1:
		scene.lines[3][1] = "你说要一起找回航路。今天带回来的每个坐标，我都会记进下一张航图里。"
	app.close_modal()
	if app.overlay.get_child_count()>0: return
	id = scene_id; completion = after; replay = id in State.narrative.seen
	line = clampi(State.narrative.cursor,0,scene.lines.size()-1) if State.narrative.active==id and not replay else 0
	if not replay:
		State.narrative.active = id; State.narrative.cursor = line; State.narrative.pending.erase(id)
		State.save_game()
	if is_instance_valid(app.refs.get("map")): app.refs.map.reset_input()
	State.story_paused = true
	layer.hide()
	stage = Control.new(); stage.name = "StoryScene"; stage.size = Vector2(720,1280)
	stage.mouse_filter = Control.MOUSE_FILTER_STOP; app.add_child(stage)
	stage.tree_exiting.connect(func(): State.story_paused = false)
	app.box(stage,Rect2(0,0,720,1280),Color("07101b"))
	var background := TextureRect.new(); background.name = "SceneBackdrop"
	background.texture = app.CONTENT.SHEETS.hangar; background.size = Vector2(720,1280)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.4,0.48,0.65,0.45); background.mouse_filter = Control.MOUSE_FILTER_IGNORE; stage.add_child(background)
	app.box(stage,Rect2(0,0,720,170),Color(0.025,0.045,0.075,0.92))
	app.label(stage,scene.title,Rect2(32,44,480,52),30,app.GOLD)
	app.label(stage,scene.place,Rect2(34,105,580,34),19,app.MUTED)
	app.button(stage,"跳过本段",Rect2(530,45,158,58),finish)
	portraits.clear()
	for i in range(scene.cast.size()):
		var pilot: int = scene.cast[i]
		var rect := Rect2(150,180,420,730) if scene.cast.size()==1 else Rect2(-28+mini(i,1)*360,180,416,730)
		var portrait: TextureRect = app.photo(stage,pilot,rect)
		portrait.name = "SpeakingPilot_%d"%pilot; portraits[pilot] = portrait
		portrait.position.x += 36 if i==0 else -36; portrait.modulate.a = 0
		var tween := stage.create_tween().set_parallel(true)
		tween.tween_property(portrait,"position:x",rect.position.x,0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(portrait,"modulate:a",1.0,0.4)
	app.INTERFACE.panel(app.box(stage,Rect2(24,836,672,422),Color("101e30"),Color("59647a"),12))
	speaker = app.label(stage,"",Rect2(46,858,500,50),30)
	counter = app.label(stage,"",Rect2(550,868,120,30),18,app.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	dialogue = app.label(stage,"",Rect2(46,930,628,205),26)
	dialogue.vertical_alignment = VERTICAL_ALIGNMENT_TOP; dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.label(stage,"通讯中 · 战斗已暂停",Rect2(46,1186,315,36),18,app.MUTED)
	next_button = app.button(stage,"继续  ›",Rect2(388,1174,284,64),advance,true)
	next_button.grab_focus()
	render_line()

func render_line() -> void:
	var entry: Array = scene.lines[line]
	var pilot: int = entry[0]
	speaker.text = State.PILOTS[pilot].name if pilot>=0 else "指挥官" if pilot==-1 else "航行记录"
	speaker.add_theme_color_override("font_color",State.PILOTS[pilot].color if pilot>=0 else app.GOLD)
	dialogue.text = entry[1]; dialogue.visible_characters = 0; typing = 0
	if line==scene.lines.size()-1 and scene.has("choice") and State.narrative.choices.has(id):
		dialogue.text = scene.choice.replies[int(State.narrative.choices[id])]; speaker.text = "小队频道"
	counter.text = "%02d / %02d"%[line+1,scene.lines.size()]
	var visible_cast: Array = scene.cast.slice(0,2)
	if pilot>=0 and pilot not in visible_cast: visible_cast[visible_cast.size()-1] = pilot
	for index in portraits:
		portraits[index].visible = index in visible_cast
		var color := Color.WHITE if index==pilot or pilot<0 else Color(0.42,0.47,0.57,0.7)
		portraits[index].self_modulate = color
	if not replay: State.narrative.cursor = line; State.save_game()

func advance() -> void:
	if not is_instance_valid(stage) or choosing: return
	if typing<dialogue.text.length():
		typing = dialogue.text.length(); dialogue.visible_characters = -1; return
	if line<scene.lines.size()-1: line += 1; render_line(); return
	if scene.has("choice") and not State.narrative.choices.has(id): show_choice(); return
	finish()

func show_choice() -> void:
	choosing = true; next_button.hide()
	dialogue.text = scene.choice.prompt; dialogue.visible_characters = -1; typing = 10000
	choice_box = Control.new(); stage.add_child(choice_box)
	for i in range(scene.choice.options.size()):
		app.button(choice_box,scene.choice.options[i],Rect2(46,1010+i*84,628,68),func(): choose_reply(i),true)

func choose_reply(index: int) -> void:
	if not choosing or index<0 or index>=scene.choice.options.size(): return
	State.narrative.choices[id] = index; State.save_game()
	choice_box.free(); choosing = false
	dialogue.text = scene.choice.replies[index]; typing = 10000; dialogue.visible_characters = -1
	speaker.text = "小队频道"; next_button.show(); next_button.text = "结束通讯"

func finish() -> void:
	if not is_instance_valid(stage): return
	if not replay: State.narrative.finish(id); State.save_game()
	var callback := completion; completion = Callable()
	stage.free(); stage = null; choosing = false; portraits.clear(); id = ""
	State.story_paused = false; layer.show(); guide_key = ""
	if callback.is_valid(): callback.call()

func suspend() -> void:
	if not is_instance_valid(stage): return
	stage.free(); stage = null; portraits.clear(); choosing = false; completion = Callable()
	State.story_paused = false; layer.show(); guide_key = ""

func on_radio(kind: String, pilot: int) -> void:
	if not auto_present or not State.narrative.radio_enabled or not CONTENT.RADIO.has(kind) or pilot<0 or pilot>=State.PILOTS.size() or pilot>=CONTENT.RADIO[kind].size(): return
	if kind=="launch": danger_announced = false
	if is_instance_valid(stage) or app.page!=0: return
	if age-float(last_radio.get(kind,-100))<(12 if kind=="victory" else 8): return
	if is_instance_valid(radio) and age<radio_until and kind not in ["danger","discovery","skill"]: return
	last_radio[kind] = age
	if is_instance_valid(radio): radio.free()
	var skill: bool = kind=="skill"
	radio = app.box(layer,Rect2(24,790,516,160 if skill else 132),Color(0.04,0.09,0.15,0.94),State.PILOTS[pilot].color,8)
	radio.name = "PilotRadio"; radio.clip_contents = true; radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.photo(radio,pilot,Rect2(0,0,116,180 if skill else 160))
	app.label(radio,State.PILOTS[pilot].name+" · "+(State.PILOTS[pilot].skill if skill else "战场通讯"),Rect2(130,10,370,32),21,State.PILOTS[pilot].color)
	var text: Label = app.label(radio,CONTENT.RADIO[kind][pilot],Rect2(130,48,366,100 if skill else 76),21)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio.position.x = -516; var tween := radio.create_tween()
	tween.tween_property(radio,"position:x",24.0,0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	radio_until = age+4.5

func update_guide() -> void:
	var goal: Dictionary = current_goal()
	var key := str(app.page)+":"+str(goal.get("key",""))
	if key==guide_key: return
	guide_key = key; focus_target = null
	if is_instance_valid(guide): guide.free()
	for name in ["base_status","base_chassis","base_pilot"]:
		if is_instance_valid(app.refs.get(name)): app.refs[name].visible = goal.is_empty()
	if goal.is_empty() or app.page not in [0,4]: return
	var rect := Rect2(24,218,672,116) if app.page==0 else Rect2(36,342,372,132)
	guide = app.button(layer,"",rect,show_guide); guide.name = "TutorialObjective"
	var offset := 14
	if app.page==0: app.photo(guide,int(goal.pilot),Rect2(0,0,76,116)); offset = 88
	app.label(guide,"%s · %s"%[State.PILOTS[int(goal.pilot)].name,goal.title],Rect2(offset,8,rect.size.x-offset-12,30),21,app.GOLD)
	var hint: Label = app.label(guide,goal.hint,Rect2(offset,42,rect.size.x-offset-12,70),17)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.max_lines_visible = 3; hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	guide.clip_contents = true
	var target: String = {"launch":"base_launch","interact":"hud_interact","return":"hud_return","hangar":"base_facility_hangar","talk":"base_facility_pilots"}.get(goal.key,"")
	if is_instance_valid(app.refs.get(target)): focus_target = app.refs[target]
	if goal.key=="fleet": focus_target = app.refs.get("base_fleet" if World.docked else "hud_carrier")
	if World.docked and goal.key in ["move","interact"]: focus_target = app.refs.get("base_launch")
	if not World.docked and goal.key in ["launch","hangar","talk"]: focus_target = app.refs.get("hud_return")

func current_goal() -> Dictionary:
	var goal: Dictionary = State.narrative.objective().duplicate()
	if goal.is_empty(): return goal
	if World.docked and goal.key in ["move","interact"]: goal.hint = "先从母舰进入地图，再继续这一课。"+goal.hint
	if not World.docked and goal.key in ["launch","hangar","talk"]: goal.hint = "先点右下回舰图标，回到母舰继续这一课。"
	if World.docked and goal.key=="fleet": goal.hint = "在母舰点「舰务 → 战舰指挥」，选择一种护航战术；下次出击会沿用。"
	return goal

func show_guide() -> void:
	var goal: Dictionary = current_goal()
	var m: Control = app.modal("机师带教","真实操作完成后推进 · 可随时暂停或重新学习",780)
	State.story_paused = true
	m.tree_exiting.connect(func(): State.story_paused = false)
	var pilot: int = int(goal.get("pilot",State.selected))
	app.photo(m,pilot,Rect2(26,146,200,350))
	app.label(m,goal.get("title","基础训练已完成"),Rect2(250,160,370,70),28,app.GOLD)
	var text: Label = app.label(m,goal.get("hint","接下来可以继续探索、挑战首领，或到机师休息室听听她们的故事。"),Rect2(250,250,364,230),23)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.button(m,"继续操作",Rect2(30,532,588,64),app.close_modal,true)
	app.button(m,"暂停引导" if State.narrative.tutorial_enabled else "继续引导",Rect2(30,612,284,58),func(): State.narrative.tutorial_enabled = not State.narrative.tutorial_enabled; State.save_game(); guide_key=""; app.close_modal())
	app.button(m,"从头练习",Rect2(330,612,288,58),func(): State.narrative.restart_tutorial(); State.save_game(); guide_key=""; app.close_modal())
	app.button(m,"剧情档案",Rect2(30,690,588,54),show_archive)

func show_archive() -> void:
	var m: Control = app.modal("航行日志","已发现剧情可回看 · 回看不会发放奖励或改变战斗进度",1060)
	app.button(m,"新手引导",Rect2(30,140,284,60),show_guide)
	app.button(m,"战场通讯 · "+("开" if State.narrative.radio_enabled else "关"),Rect2(330,140,288,60),func(): State.narrative.radio_enabled = not State.narrative.radio_enabled; State.save_game(); show_archive())
	var scroll := ScrollContainer.new(); scroll.position = Vector2(24,220); scroll.size = Vector2(600,744); m.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := VBoxContainer.new(); rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",10); scroll.add_child(rows)
	for key in CONTENT.ids():
		if key not in State.narrative.unlocked: continue
		var data: Dictionary = CONTENT.scene(key)
		var b: Button = app.button(rows,("回看 · " if key in State.narrative.seen else "未读 · ")+data.title,Rect2(0,0,570,74),func(): play(key,show_archive))
		b.custom_minimum_size = Vector2(560,74); b.add_theme_font_size_override("font_size",21)
	app.button(m,"返回",Rect2(30,982,588,54),app.close_modal)
