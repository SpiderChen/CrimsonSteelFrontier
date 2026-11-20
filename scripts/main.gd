extends Control
const INTERFACE = preload("res://scripts/interface_theme.gd")
var recruit_sequence: Control
const CONTENT = preload("res://scripts/production_art.gd")

const NAV_TEXTURES = [preload("res://assets/free/icons/target.png"), preload("res://assets/free/icons/wrench.png"), preload("res://assets/free/icons/singleplayer.png"), preload("res://assets/free/icons/star.png")]
const RESOURCE_TEXTURES = [preload("res://assets/free/icons/medal1.png"), preload("res://assets/free/icons/gear.png"), preload("res://assets/free/icons/star.png")]
const SOUND_ON = preload("res://assets/free/icons/audioOn.png")
const SOUND_OFF = preload("res://assets/free/icons/audioOff.png")
const HELP_ICON = preload("res://assets/free/icons/question.png")
const TRAINING = preload("res://scripts/training.gd")
const CARRIER = preload("res://scripts/carrier.gd")
const MAP = preload("res://scripts/world_map.gd")
const FIELD = preload("res://scripts/battlefield.gd")
const FONT = preload("res://assets/fonts/NotoSansSC.otf")
const SHEET = preload("res://assets/pilots/pilots.png")
const PILOT_PORTRAITS = ["", "", "", "res://assets/pilots/reina.png", "res://assets/pilots/aster.png", "res://assets/pilots/eve.png"]
const MECH_ART = preload("res://scripts/mech_art.gd")
const RED := Color("ff5368")
const WHITE := Color("f2f1f3")
const MUTED := Color("8894a8")
const GOLD := Color("e9c78e")
var page: int = 0
var body: Control
var overlay: Control
var toast_label: Label
var toast_timer: float = 0
var refs: Dictionary = {}
var icon_cache: Dictionary = {}
var portrait_index: int = 0
var portrait_cache: Dictionary = {}
var mech_page: int = 0
var part_slot: int = 0
var warehouse_slot: int = -1
const PART_GROUP_SLOTS = [0,1,2,3,5]
var mechanism_filter: String = "all"
var locked_only: bool = false
var region_focus: Array = [-1,-1,-1,-1]
var rebuilding_cloud_modal: bool = false
var battle_radar: bool = false
const HUD_UI = preload("res://scripts/hud_ui.gd")
var hud_ui = HUD_UI.new(self)
const CLOUD_UI = preload("res://scripts/cloud_ui.gd")
var cloud_ui = CLOUD_UI.new(self)
const PILOT_UI = preload("res://scripts/pilot_ui.gd")
var pilot_ui = PILOT_UI.new(self)
const STORY_UI = preload("res://scripts/story_ui.gd")
var story_ui = STORY_UI.new(self)
const SALVAGE_UI = preload("res://scripts/salvage_ui.gd")
var salvage_ui = SALVAGE_UI.new(self)
const MANUFACTURING_UI = preload("res://scripts/manufacturing_ui.gd")
var manufacturing_ui = MANUFACTURING_UI.new(self)
const RECYCLE_UI = preload("res://scripts/recycle_ui.gd")
var recycle_ui = RECYCLE_UI.new(self)
const CARRIER_UI = preload("res://scripts/carrier_ui.gd")
var carrier_ui = CARRIER_UI.new(self)
var loading := false
var browser_save_callback

func _ready() -> void:
	var theme_value := Theme.new()
	theme_value.default_font = FONT
	theme_value.default_font_size = 22
	theme = theme_value
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	State.changed.connect(refresh)
	State.message.connect(toast)
	State.victory.connect(on_victory)
	World.base_entered.connect(on_base_entered)
	build_shell()
	story_ui.setup()
	show_page(4 if World.docked else 0)
	if OS.has_feature("web"):
		browser_save_callback = JavaScriptBridge.create_callback(func(_args): State.save_game())
		var window = JavaScriptBridge.get_interface("window")
		window.addEventListener("pagehide", browser_save_callback)
		window.document.addEventListener("visibilitychange", browser_save_callback)
	if State.offline_seconds > 60 and World.docked:
		call_deferred("show_idle")

func sound() -> void:
	Sfx.activate()
	Sfx.play("click", -27)

func icon_texture(texture_value: Texture2D) -> Texture2D:
	var key: String = texture_value.resource_path if texture_value.resource_path!="" else str(texture_value.get_instance_id())
	if icon_cache.has(key): return icon_cache[key]
	var atlas := AtlasTexture.new()
	atlas.atlas = texture_value
	atlas.region = Rect2(texture_value.get_image().get_used_rect())
	icon_cache[key] = atlas
	return atlas

func icon(parent: Node, texture_value: Texture2D, rect: Rect2, tint_value: Color = WHITE) -> TextureRect:
	var n := TextureRect.new()
	n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	n.texture = icon_texture(texture_value)
	n.position = rect.position
	n.size = rect.size
	n.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	n.modulate = tint_value
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func part_icon(parent: Node, blueprint: int, rect: Rect2) -> TextureRect:
	var artwork := icon(parent,CONTENT.texture("equipment",blueprint),rect,Color.WHITE)
	artwork.name = "PartArt_%d"%blueprint
	return artwork

func box(parent: Node, rect: Rect2, color: Color, border: Color = Color.TRANSPARENT, radius: int = 0) -> Panel:
	var n := Panel.new()
	n.position = rect.position
	n.size = rect.size
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	n.add_theme_stylebox_override("panel",s)
	parent.add_child(n)
	return n

func label(parent: Node, value: String, rect: Rect2, font_size: int = 22, color: Color = WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var n := Label.new()
	n.position = rect.position
	n.size = rect.size
	n.text = value
	n.add_theme_font_size_override("font_size",font_size)
	n.add_theme_color_override("font_color",color)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.horizontal_alignment = align
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func button(parent: Node, value: String, rect: Rect2, action: Callable, primary: bool = false, color: Color = RED) -> Button:
	var n := Button.new()
	n.position = rect.position
	n.size = rect.size
	n.text = value
	n.add_theme_font_size_override("font_size",23)
	n.add_theme_color_override("font_color",WHITE if primary else Color("cbd1db"))
	n.add_theme_color_override("font_hover_color",WHITE)
	n.add_theme_color_override("font_pressed_color",WHITE)
	INTERFACE.button(n,primary,color)
	if rect.size.y<=64 and not primary: INTERFACE.compact(n,Color("8cdec3"),rect.size.x<=64)
	n.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	n.pressed.connect(func(): sound(); action.call(), CONNECT_DEFERRED)
	parent.add_child(n)
	return n

func portrait_texture(index: int, aspect: float = 2.0, compact: bool = false) -> Texture2D:
	index = clampi(index,0,State.PILOTS.size()-1)
	var atlas := AtlasTexture.new()
	if index<PILOT_PORTRAITS.size() and PILOT_PORTRAITS[index]!="" and ResourceLoader.exists(PILOT_PORTRAITS[index]):
		if not portrait_cache.has(index): portrait_cache[index] = load(PILOT_PORTRAITS[index])
		var texture_value: Texture2D = portrait_cache[index]
		atlas.atlas = texture_value
		var dimensions := texture_value.get_size()
		var width := dimensions.x*(0.7 if compact else 1.0)
		var height := minf(dimensions.y*(0.63 if compact else 1.0),width*aspect)
		atlas.region = Rect2((dimensions.x-width)/2,dimensions.y*0.025 if compact else 0,width,height)
	else:
		atlas.atlas = SHEET
		atlas.region = Rect2(mini(index,2)*512,0,512,minf(1024,512*aspect))
	return atlas

func photo(parent: Node, index: int, rect: Rect2, fade: bool = false) -> TextureRect:
	var n := TextureRect.new()
	n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	n.texture = portrait_texture(index,rect.size.y/maxf(rect.size.x,1),rect.size.x<180)
	n.position = rect.position
	n.size = rect.size
	n.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	n.clip_contents = true
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fade: n.modulate = Color(0.55,0.6,0.7,0.6)
	parent.add_child(n)
	if rect.size.x>=180 and index>=0 and index<State.pilot_roster.trust.size() and int(State.pilot_roster.trust[index])>=25:
		label(n,"◆ 归航",Rect2(10,10,150,32),20,GOLD)
	return n

func rule(parent: Node, y: float, x: float = 24, width: float = 672) -> void:
	box(parent,Rect2(x,y,width,1),Color("293243"))

func small_header(parent: Node, text_value: String, y: float, sub: String = "") -> void:
	box(parent,Rect2(24,y+8,4,24),RED)
	label(parent,text_value,Rect2(40,y,450,40),27)
	if sub != "": label(parent,sub,Rect2(40,y+44,620,30),17,MUTED)

func build_shell() -> void:
	var background := box(self,Rect2(0,0,720,1280),Color("0b101a"))
	background.clip_contents = true
	var ambience := TextureRect.new()
	ambience.texture = CONTENT.SHEETS.hangar
	ambience.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ambience.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ambience.size = Vector2(720,1280)
	ambience.modulate = Color(0.3,0.4,0.5,0.18)
	ambience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(ambience)
	var header := Control.new(); header.size = Vector2(720,168); header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header); refs.shell_header = header
	box(header,Rect2(0,0,720,4),RED)
	refs.brand_mark = box(header,Rect2(24,25,55,55),RED)
	refs.brand_text = label(header,"CF",Rect2(24,25,55,55),28,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	refs.home_back = button(header,"‹",Rect2(24,25,55,55),open_base)
	refs.home_back.add_theme_font_size_override("font_size",31)
	refs.home_back.tooltip_text = "返回母舰"
	label(header,"绯红战线",Rect2(94,19,300,42),29)
	label(header,"C R I M S O N   F R O N T",Rect2(96,61,330,20),12,MUTED)
	var help_button := button(header,"",Rect2(568,28,56,52),show_help)
	icon(help_button,HELP_ICON,Rect2(16,13,24,24),MUTED)
	refs.sound = button(header,"",Rect2(638,28,56,52),toggle_sound)
	refs.sound_icon = icon(refs.sound,SOUND_ON,Rect2(16,13,24,24),MUTED)
	var colors := [GOLD,Color("8dd6e3"),Color("bba2fc")]
	var names := ["信用点","合金芯","星晶"]
	for i in range(3):
		var x := 24+i*228
		box(header,Rect2(x,103,216,60),Color("141c29"),Color("293344"),4)
		icon(header,RESOURCE_TEXTURES[i],Rect2(x+15,122,26,26),colors[i])
		label(header,names[i],Rect2(x+50,107,90,19),12,MUTED)
		refs["resource%d"%i] = label(header,"0",Rect2(x+50,127,148,28),23,WHITE)
	body = Control.new()
	add_child(body)
	move_child(body,1)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	toast_label = label(self,"",Rect2(60,1202,600,46),19,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color("283449")
	toast_style.set_corner_radius_all(5)
	toast_label.add_theme_stylebox_override("normal",toast_style)
	toast_label.hide()

func show_page(index: int) -> void:
	if index in [1,2,3] and not World.docked:
		request_base()
		return
	page = index
	story_ui.guide_key = ""
	if page==1: State.story_event("hangar")
	refs.shell_header.visible = page!=0
	refs.home_back.visible = page in [1,2,3]
	refs.brand_mark.visible = not refs.home_back.visible
	refs.brand_text.visible = not refs.home_back.visible
	toast_label.position.y = 966 if page==0 else 1230 if page in [2,4] else 1202
	for n in body.get_children(): n.free()
	for key in refs.keys():
		if not is_instance_valid(refs[key]): refs.erase(key)
	match page:
		0: build_battle()
		1: build_hangar()
		2: build_pilots()
		3: build_recruit()
		4: build_base()
	refresh()

func on_base_entered() -> void:
	call_deferred("open_base")

func open_base() -> void:
	if not World.docked: return
	close_modal()
	show_page(4)

func request_base() -> void:
	if World.docked:
		open_base()
		return
	var m := modal("返回母舰","绯红方舟 / 机甲恢复点与设施中心",470)
	var text := label(m,"回航后恢复装甲并开放全部设施。\n副本中途回航会结算已获赏金、装备与样本；下次出击会重新生成探索地图。",Rect2(30,145,588,145),23)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(m,"回航并停泊",Rect2(30,340,588,76),func(): World.enter_base(); open_base(),true)

func launch_from_base() -> void:
	show_regions()

func build_base() -> void:
	hud_ui.build_base()

func show_training() -> void:
	if not World.docked: request_base(); return
	var m := modal("构筑训练舱","使用当前配装与战术 · 拖动可接管走位 · 不影响真实装甲",880)
	var view := Control.new()
	view.set_script(TRAINING)
	view.position = Vector2(16,230)
	view.size = Vector2(616,414)
	refs.training_view = view
	m.add_child(view)
	for i in range(3): button(m,["单体输出","怪群清场","生存压力"][i],Rect2(24+i*202,148,194,58),func(): view.reset(i))
	var names := PackedStringArray()
	for slot in [0,4]:
		var weapon: Dictionary = State.parts.equipped(State.selected_mech,slot)
		var mechanism: String = weapon.get("mechanism","")
		var suffix: String = " · "+State.PARTS.MECHANISMS[mechanism].name if mechanism!="" else ""
		if State.parts.equipped(State.selected_mech,3).get("mechanism","")=="ion": suffix += " · 核心电离"
		names.append(("左 / " if slot==0 else "右 / ")+State.parts.name_of(weapon)+suffix)
	var text := label(m,"\n".join(names),Rect2(24,654,600,52),18,GOLD)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refs.training_breakdown = label(m,"",Rect2(24,716,600,75),16,MUTED)

	button(m,"结束训练",Rect2(24,800,600,56),close_modal)

func refresh_training() -> void:
	if not is_instance_valid(refs.get("training_view")) or not is_instance_valid(refs.get("training_breakdown")): return
	var stats: Dictionary = refs.training_view.engine.stats
	refs.training_breakdown.text = "左手 %.0f · 右手 %.0f · 技能 %.0f · 反击 %.0f\n动能 %.0f · 热能 %.0f · 电能 %.0f · 格挡 %.0f\n近战 %.0f · 直击 %.0f · 光束 %.0f · 爆炸 %.0f · 灼烧 %.0f" % [stats.by_slot.get("0",0),stats.by_slot.get("4",0),stats.by_slot.get("skill",0),stats.by_slot.get("1",0),stats.by_type.get("kinetic",0),stats.by_type.get("thermal",0),stats.by_type.get("electric",0),refs.training_view.defense.guard_blocked,stats.by_kind.get("melee",0),stats.by_kind.get("direct",0),stats.by_kind.get("beam",0),stats.by_kind.get("explosion",0),stats.by_kind.get("burn",0)]

func show_presets() -> void:
	if not World.docked: request_base(); return
	var m := modal("配装档案库","保存装备与战术 3 套方案；引用的部件受到分解保护",720)
	for i in range(3):
		var ready: bool = State.parts.presets[State.selected_mech].size()>i
		label(m,"方案 %d / %s" % [i+1,"已保存" if ready else "未保存"],Rect2(30,155+i*140,270,44),24)
		button(m,"保存当前",Rect2(300,150+i*140,140,62),func(): State.save_configuration(i); show_presets())
		var apply := button(m,"装配",Rect2(456,150+i*140,160,62),func():
			if State.apply_configuration(i):
				toast("配装与战术已应用，跨机甲部件会自动转装")
			show_presets(),true)
		apply.disabled = not ready
	button(m,"完成",Rect2(30,622,588,62),close_modal)

func show_tactics() -> void:
	var m := modal("自动战术",State.mechs.name_of(State.selected_mech)+" / 即时生效，可随配装方案保存",960)
	var keys := ["target","distance","heat","survival","skill"]
	var titles := ["优先目标","交战距离","热量策略","生存策略","机师技能"]
	var descriptions := {
		"parts":"优先可破坏部位，其余目标按距离选择；手动部位锁定优先。",
		"nearest":"选择射程和射界内最近的目标；敌军剩余装甲保留。",
		"weak":"优先剩余装甲比例最低的目标，尽快减少战场威胁。",
		"balanced":"连射游击、轨道/光束定点、近战贴身；鸦羽稳态瞄准，兼顾两手射程。",
		"close":"接近到约120距离，集中压制；更容易遭到近身攻击。",
		"far":"保持交战射程的90%；混装近战武器时以近战距离为准。",
		"melee":"贴近至约60距离，拳套等短武器会进一步靠近；仍规避首领危险区。",
		"pressure":"持续开火；热量达到100会降频，仍然能够移动。",
		"conserve":"热量达到80，或预计开火后超过95时停火；冷却到45后恢复。",
		"alternate":"每手完成一轮射击再换手；另一手超出射程时继续单手射击。",
		"steady":"保持交战与距离策略，自动规避首领炮击。",
		"withdraw":"护盾低于20%时拉开距离，恢复60%后返回；装甲低于30%回舰。",
		"clear":"160范围内的近身敌军优先于远处精英和部位。",
		"ready":"充能达到100%且目标进入射程后自动使用。",
		"danger":"装甲低于50%、护盾撤离或敌方弹道/炮击接近时使用。"
	}
	for i in range(keys.size()):
		var key: String = keys[i]
		var current: String = State.active_tactics()[key]
		var y := 145+i*128
		label(m,titles[i],Rect2(30,y,150,36),23,GOLD)
		var caption: String = "精英出现时使用" if key=="skill" and current=="elite" else State.TACTICS.LABELS[current]
		button(m,caption+"  ›",Rect2(188,y-3,430,46),func():
			var choices: Array = State.TACTICS.OPTIONS[key]
			State.set_tactic(key,choices[(choices.find(current)+1)%choices.size()]); show_tactics(),true)
		var explanation: String = ("射程内出现精英时使用技能，仍可手动释放。" if key=="skill" else "射程与射界内的精英优先，其他目标按距离选择。") if current=="elite" else descriptions[current]
		var desc := label(m,explanation,Rect2(30,y+53,588,54),18,MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(m,"自动战斗负责选敌、接敌、开火和避险；技能遵循设置。\n拖动可手动接管；当前打法："+State.movement_tactics().style,Rect2(30,795,588,58),18,Color("8cdec3"))
	button(m,"完成设置",Rect2(30,878,588,56),close_modal)

func show_boss() -> void:
	# Legacy callers enter the unified map board. Existing saved battles can still finish.
	show_regions()

func show_regions() -> void:
	if not World.docked:
		if State.expedition.active(): show_map_status()
		else: request_base()
		return
	var m := modal("副本作战 · 选择地图","自由探索地图 · 发现物资与首领 · 母舰远程支援",1040)
	for i in range(4):
		var data: Dictionary = State.expedition.DATA.REGIONS[i]
		var y := 140+i*176
		button(m,"",Rect2(24,y,600,158),func(): show_region_detail(i),State.expedition.unlocked(i))
		label(m,data.name,Rect2(42,y+9,550,34),27)
		label(m,"开放 · 通关%d次 / 样本%d" % [State.expedition.clears[i],State.expedition.samples[i]] if State.expedition.unlocked(i) else "解锁条件：击败前一区域首领",Rect2(42,y+47,550,28),18,GOLD)
		var names := PackedStringArray()
		for blueprint in data.pool: names.append(State.PARTS.BLUEPRINTS[blueprint].name)
		var text := label(m,"定向回收 / "+"、".join(names),Rect2(42,y+83,550,66),18,MUTED)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not State.expedition.report.is_empty():
		var result: Dictionary = State.expedition.report
		label(m,"上次副本：%s / %s / 已结赏金 %d" % [State.expedition.DATA.REGIONS[int(result.region)].name,{"cleared":"肃清","withdrawn":"主动撤离","failed":"损毁回收"}.get(result.outcome,"结束"),result.bounty],Rect2(30,865,588,40),17,GOLD)
	button(m,"返回母舰",Rect2(30,942,588,62),close_modal)

func show_region_detail(region: int) -> void:
	var data: Dictionary = State.expedition.DATA.REGIONS[region]
	var opened: bool = State.expedition.unlocked(region)
	var focus: int = region_focus[region]
	var m := modal(data.name,"区域样本 %d / 首通 %s" % [State.expedition.samples[region],"已完成" if State.expedition.clears[region]>0 else "未完成"],960)
	var desc := label(m,data.theme+"\n"+data.condition,Rect2(30,140,588,78),23,GOLD)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var names := PackedStringArray()
	for blueprint in data.pool: names.append(State.PARTS.BLUEPRINTS[blueprint].name)
	var drops := label(m,"区域掉落池：\n"+"、".join(names)+"\n精英与重复首领产出所选型号，普通敌军从区域池掉落。",Rect2(30,240,588,126),20,MUTED)
	drops.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var first := label(m,"首通："+State.PARTS.BLUEPRINTS[data.blueprint].name+"蓝图与史诗成品\n"+("解锁："+State.expedition.DATA.REGIONS[region+1].name if region<3 else "完成全部地图首通"),Rect2(30,385,588,72),19,Color("8cdec3"))
	first.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(m,"定向型号："+("区域随机" if focus<0 else State.PARTS.BLUEPRINTS[focus].name)+"  ›",Rect2(30,476,588,56),func():
		var options: Array = [-1]+data.pool
		region_focus[region] = options[(options.find(focus)+1)%options.size()]; show_region_detail(region))
	var start := button(m,"进入地图 · 自由探索",Rect2(30,556,588,76),func():
		if State.expedition.begin(World,region,focus): close_modal(); show_page(0)
		else: toast("请完成解锁、母舰修复或调整装机约束后出发"),true)
	start.disabled = not opened or State.recovery>0 or not State.mech_configuration().valid
	var rules := label(m,"广域战区 · 探索敌营与分散的补给设施。\n接近设施后可交互；发现首领后，自主决定何时挑战。\n自动战斗负责附近选敌、接敌、开火与避险。",Rect2(30,658,588,112),21,MUTED)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var support := State.carrier.initial_support()
	label(m,"母舰已装填：舰炮 %d 次 / 维修 %d 次 · 战场直接呼叫\n样本前往母舰“副本物资”兑换；蓝图前往制造工坊。" % [support.cannon,support.repair],Rect2(30,792,588,66),18,Color("8cdec3"))
	button(m,"返回副本地图",Rect2(30,878,588,56),show_regions)

func show_map_status() -> void:
	if not State.expedition.active(): show_regions(); return
	var m := modal("探索概览","地图由机甲实地探索 · 查看概览时战斗继续",820)
	refs.exploration_title = label(m,"",Rect2(30,144,588,88),27,GOLD)
	refs.exploration_summary = label(m,"",Rect2(30,256,588,216),23)
	refs.exploration_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var desc := label(m,"拖动摇杆探索未知区域；可双指或右键查看已探区域。\n靠近设施后点击战场“交互”按钮，已用设施不会重复发奖。\n发现首领后可先继续搜集，准备好再靠近挑战。",Rect2(30,490,588,132),21,MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(m,"主动撤离 · 结算赏金并回舰",Rect2(30,650,588,62),func(): State.expedition.withdraw(World))
	button(m,"返回地图",Rect2(30,736,588,58),close_modal)
	refresh_map_status()

func refresh_map_status() -> void:
	if not is_instance_valid(refs.get("exploration_title")) or not State.expedition.active(): return
	var run: Dictionary = State.expedition.run
	refs.exploration_title.text = State.expedition.DATA.REGIONS[int(run.region)].name+"\n已探索 %d%%" % State.expedition.explored_percent()
	refs.exploration_summary.text = "已发现地点 %d · 已回收设施 %d\n已击破守军 %d · 区域样本 %d\n未结赏金 %d · 冷却增效 %.0f 秒\n首领情报 / %s" % [run.discovered.size(),run.used.size(),run.secured.size(),State.expedition.samples[int(run.region)],run.bounty,run.cooling_seconds,World.boss.display_name() if World.boss.active else "已发现，可靠近挑战" if State.expedition.boss_discovered() else "尚未发现"]

func show_map_interaction() -> void:
	var site: Dictionary = State.expedition.nearest_interaction(World)
	if site.is_empty(): return
	var mission: int = State.expedition.run.id
	var m := modal(site.name if site.kind!="boss_site" else "发现区域首领","靠近地点后交互 · 战斗会继续进行",650)
	var description: String = {"boss_site":"大型机体已进入视野。可以在此挑战，也可以继续探索地图。\n母舰火力支援与维修投送仍然可用。","cache":"可回收少量样本，或开启封存武器库。\n开启可获得定向稀有部件，同时提高首领炮击密度。","cooling":"可拆解回收赏金，或接入冷却设施。\n冷却增效持续90秒，但会降低移动速度。","supply":"可用于恢复装甲与排热，也可以拆解为物资。\n每处设施只可领取一次。"}.get(site.kind,"")
	var desc := label(m,description,Rect2(30,150,588,162),23,MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions: Array = State.expedition.options(site.id)
	for i in range(actions.size()):
		button(m,actions[i],Rect2(30,342+i*84,588,68),func():
			if State.expedition.interact(World,site.id,i,mission): close_modal()
			else: toast("已离开交互范围，或地点已被使用"),true)
	button(m,"稍后再说 · 返回地图",Rect2(30,558,588,62),close_modal)

func refresh_base() -> void:
	hud_ui.refresh_base()

func build_battle() -> void:
	hud_ui.build_battle()

func refresh_world() -> void:
	hud_ui.refresh_world()

func build_hangar() -> void:
	small_header(body,"机甲整备",188)
	label(body,"HANGAR / 机体与机师独立 · 专属特性与词条",Rect2(40,246,620,28),17,MUTED)
	button(body,"机库 · 更换机体",Rect2(452,190,244,52),show_mechs)
	var field := Control.new()
	field.set_script(FIELD)
	field.position = Vector2(196,278)
	field.size = Vector2(500,210)
	field.preview = true
	field.obscured = func(): return overlay.get_child_count()>0
	field.tint = State.MECHS.MODELS[State.mechs.units[State.selected_mech].model].color
	body.add_child(field)
	var pilot_card := button(body,"",Rect2(24,278,160,210),pilot_ui.open_active)
	pilot_card.name = "HangarPilotPortrait"; pilot_card.clip_contents = true
	photo(pilot_card,State.selected,Rect2(0,0,160,210))
	box(pilot_card,Rect2(0,176,160,34),Color(0.025,0.045,0.075,0.9))
	label(pilot_card,State.PILOTS[State.selected].name+"  ›",Rect2(10,178,140,30),19,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	var model: Dictionary = State.MECHS.MODELS[State.mechs.units[State.selected_mech].model]
	label(body,"特性 / "+model.trait,Rect2(418,438,260,32),19,GOLD)
	refs.hangar_level = label(body,"",Rect2(510,302,166,30),20,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	refs.hangar_name = label(body,"",Rect2(24,498,672,40),32)
	refs.hangar_stats = label(body,"",Rect2(24,540,672,32),21,MUTED)
	for i in range(6):
		var slot: int = State.PARTS.DISPLAY_SLOTS[i]
		var x := 24+(i%2)*342
		var y := 588+int(i/2.0)*78
		var card := button(body,"",Rect2(x,y,330,70),func(): part_slot=slot; warehouse_slot=0 if slot==4 else slot; show_parts())
		var equipped: Dictionary = State.parts.equipped(State.selected_mech,slot)
		refs["slot_art%d"%slot] = part_icon(card,int(equipped.get("blueprint",0)),Rect2(10,12,48,48))
		label(card,State.PARTS.SLOTS[slot],Rect2(68,6,70,24),15,MUTED)
		refs["slot_name%d"%slot] = label(card,"",Rect2(68,30,246,30),18)
		refs["slot_trait%d"%slot] = label(card,"",Rect2(140,6,174,24),13,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	refs.part_summary = label(body,"",Rect2(24,824,672,48),16,Color("8cdec3"))
	refs.parts_button = button(body,"部件仓库",Rect2(24,878,328,44),func(): warehouse_slot=-1; show_parts())
	refs.build_tools = button(body,"构筑工坊  ›",Rect2(368,878,328,44),func(): hud_ui.show_section("build"))
	refs.upgrade_cost = label(body,"",Rect2(24,930,672,40),23,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	button(body,"强化当前机体  ↑",Rect2(24,990,672,78),State.upgrade_mech,true)
	button(body,"更换主战机师  ›",Rect2(24,1084,324,62),func(): portrait_index = State.selected; show_page(2))
	button(body,"动作与特效检视",Rect2(372,1084,324,62),show_motion_review)
	refs.combat_style = label(body,"",Rect2(24,1162,672,54),19,MUTED)

func show_motion_review() -> void:
	var m := modal("3D 动作与特效检视","真实关节 · 多方向走跑 · 独立武器动作",1040)
	var stage := Control.new(); stage.set_script(preload("res://scripts/motion_review.gd"))
	stage.name = "MotionReview"; stage.position = Vector2(30,246); stage.size = Vector2(588,438); m.add_child(stage)
	for i in range(State.MECHS.MODELS.size()):
		var model: Dictionary = State.MECHS.MODELS[i]
		var select_model := button(m,model.name.get_slice(" · ",0),Rect2(30+(i%3)*198,144+int(i/3.0)*50,188,44),func(): stage.model=i,false,model.color)
		select_model.name = "ReviewChassis_%d"%i
	for i in range(6):
		button(m,["待机","步行","跑动","悬浮","冲刺","履带"][i],Rect2(30+i*99,704,93,46),func(): stage.mode=["idle","walk","run","hover","dash","treads"][i])
	for i in range(9):
		button(m,["连射","轨道炮","等离子","激光","脉冲","导弹","能量剑","拳套","重锤"][i],Rect2(30+(i%5)*119,756+int(i/5)*42,112,36),func(): stage.select_weapon(["burst","rail","plasma","laser","pulse","missile","blade","gauntlet","hammer"][i]))
	var pause := button(m,"暂停",Rect2(30,844,184,54),func(): pass)
	pause.pressed.connect(func(): stage.paused=not stage.paused; pause.text="继续" if stage.paused else "暂停")
	var slow := button(m,"半速播放",Rect2(228,844,184,54),func(): pass)
	slow.pressed.connect(func(): stage.rate=0.5 if stage.rate==1 else 1.0; slow.text="恢复原速" if stage.rate==0.5 else "半速播放")
	button(m,"护盾受击",Rect2(426,844,192,54),stage.impact)
	var turn := button(m,"360° 转向：关闭",Rect2(30,908,286,40),func(): pass)
	turn.pressed.connect(func(): stage.orbit_view=not stage.orbit_view; turn.text="360° 转向：开启" if stage.orbit_view else "360° 转向：关闭")
	var attack := button(m,"攻击演示：关闭",Rect2(326,908,292,40),func(): pass)
	attack.pressed.connect(func(): stage.set_attack_demo(not stage.attack_demo); attack.text="攻击演示：开启" if stage.attack_demo else "攻击演示：关闭")
	button(m,"返回整备",Rect2(30,960,588,54),close_modal)

func show_mechs(page_index: int = -1) -> void:
	if not World.docked: request_base(); return
	var pages := maxi(1,ceili(State.mechs.units.size()/3.0))
	mech_page = clampi(page_index if page_index>=0 else int(State.selected_mech/3.0),0,pages-1)
	var m := modal("机库 · 独立机体","%d 台机体 / %s · 各自保存装备、等级与词条"%[State.mechs.units.size(),State.PILOTS[State.selected].name],1040)
	for index in range(mech_page*3,mini((mech_page+1)*3,State.mechs.units.size())):
		var unit: Dictionary = State.mechs.units[index]
		var model: Dictionary = State.MECHS.MODELS[unit.model]
		var y := 146+(index%3)*250
		var card := Control.new(); card.name = "ChassisCard_%d"%index; card.position = Vector2(24,y); card.size = Vector2(600,232); m.add_child(card)
		box(card,Rect2(0,0,600,232),Color("1a293b"),model.color if index==State.selected_mech else Color("354258"),8)
		if int(unit.model)<MECH_ART.TEXTURES.size():
			icon(card,MECH_ART.TEXTURES[unit.model],Rect2(432,10,140,140),Color.WHITE)
		else:
			var preview := Control.new(); preview.name = "ChassisPreview_%d"%index
			preview.position = Vector2(432,10); preview.size = Vector2(140,140); preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(preview)
			var loadout := {"drive":"walk","weapons":[],"armor":-1,"core":-1,"backpack":-1}
			for slot in [0,4,1,3,5]:
				var part: Dictionary = State.parts.equipped(index,slot)
				if part.is_empty(): continue
				if slot in [0,4]: loadout.weapons.append({"slot":slot,"mode":State.PARTS.BLUEPRINTS[int(part.blueprint)].trait,"blueprint":int(part.blueprint)})
				else: loadout[{1:"armor",3:"core",5:"backpack"}[slot]] = int(part.blueprint)
			preview.draw.connect(func(): MECH_ART.render(preview,Vector2(70,65),0.48,model.color,false,0,{},loadout))
		label(card,model.name+" · Lv.%d" % unit.level,Rect2(16,12,400,38),26,model.color)
		var feature := label(card,"固定特性 / "+model.trait+" · "+model.desc,Rect2(16,56,400,50),17,GOLD)
		feature.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label(card,"机体词条 / "+State.mechs.affix_text(index),Rect2(16,112,400,30),16,Color("8cdec3"))
		var equipped_count: int = State.parts.loadouts[index].size()
		label(card,"独立配装 %d/6 · 机师可自由换乘" % equipped_count,Rect2(16,148,370,32),18,MUTED)
		var choose := button(card,"当前机体" if index==State.selected_mech else "换乘此机体",Rect2(392,158,190,54),func():
			if State.choose_mech(index): close_modal(); show_page(1),index==State.selected_mech)
		choose.name = "ChooseChassis_%d"%index
		choose.disabled = index==State.selected_mech or State.recovery>0
	var previous := button(m,"‹ 上一页",Rect2(30,898,152,42),func(): show_mechs(mech_page-1))
	previous.name = "MechPrevious"; previous.disabled = mech_page==0
	label(m,"%d / %d · 共 %d 台"%[mech_page+1,pages,State.mechs.units.size()],Rect2(190,898,268,42),20,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	var next := button(m,"下一页 ›",Rect2(466,898,152,42),func(): show_mechs(mech_page+1))
	next.name = "MechNext"; next.disabled = mech_page>=pages-1
	button(m,"返回整备",Rect2(30,952,588,56),func(): close_modal(); show_page(1))

func show_parts() -> void:
	if not World.docked: request_base(); return
	var m := modal("机甲部件仓库","%s / %d/%d · 按部位分组，点击部件查看与装配" % [State.mechs.name_of(State.selected_mech),State.parts.inventory.size(),State.PARTS.LIMIT],1040)
	var groups: Dictionary = {}
	var visible_count := 0
	for slot in PART_GROUP_SLOTS: groups[slot] = []
	for part in State.parts.inventory:
		if not State.parts.matches(part,-1,mechanism_filter,locked_only): continue
		groups[int(part.slot)].append(part)
		visible_count += 1
	var tabs: Array = [-1]+PART_GROUP_SLOTS
	for i in range(tabs.size()):
		var slot: int = tabs[i]
		var title: String = "全部" if slot<0 else "武器" if slot==0 else State.PARTS.SLOTS[slot]
		var count: int = visible_count if slot<0 else groups[slot].size()
		button(m,title+" · %d" % count,Rect2(24+(i%3)*202,138+int(i/3.0)*62,194,52),func(): warehouse_slot=slot; show_parts(),slot==warehouse_slot)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24,278)
	scroll.size = Vector2(600,590)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	for slot in PART_GROUP_SLOTS:
		if warehouse_slot>=0 and warehouse_slot!=slot: continue
		var group: Array = groups[slot]
		if group.is_empty(): continue
		var heading := Control.new()
		heading.custom_minimum_size = Vector2(572,48)
		list.add_child(heading)
		var title: String = "武器 · 左右手通用" if slot==0 else State.PARTS.SLOTS[slot]
		label(heading,title,Rect2(12,8,430,32),23,GOLD)
		label(heading,"%d 件" % group.size(),Rect2(440,8,114,32),19,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
		for part in group:
			var card := Control.new()
			card.custom_minimum_size = Vector2(572,176)
			list.add_child(card)
			var info: Dictionary = State.PARTS.BLUEPRINTS[part.blueprint]
			var owner: int = State.parts.owner(part.id)
			var equipped_slot: int = part.slot
			if owner>=0: equipped_slot = int(State.parts.loadouts[owner].find_key(part.id))
			var current: bool = owner==State.selected_mech
			var accent: Color = Color("8cdec3") if current else Color("78bdff") if owner>=0 else MUTED
			var background: Color = Color("142d2b") if current else Color("16283c") if owner>=0 else Color("182131")
			var entry := button(card,"",Rect2(0,0,572,176),func(): show_part_detail(part.id))
			for mode in ["normal","hover","pressed","disabled"]:
				var style := StyleBoxFlat.new()
				style.bg_color = background.lightened(0.08) if mode=="hover" else background.darkened(0.08) if mode=="pressed" else background
				style.border_color = accent if owner>=0 else Color("303c51")
				style.set_border_width_all(2 if owner>=0 else 1)
				style.set_corner_radius_all(8)
				entry.add_theme_stylebox_override(mode,style)
			label(card,State.parts.name_of(part)+" · Lv.%d" % part.get("level",1),Rect2(16,10,420,32),22,State.PARTS.COLORS[part.quality])
			label(card,State.PARTS.QUALITIES[part.quality],Rect2(440,10,114,32),18,State.PARTS.COLORS[part.quality],HORIZONTAL_ALIGNMENT_RIGHT)
			box(card,Rect2(16,48,148,30),Color(accent,0.14),Color(accent,0.55),5)
			label(card,"当前机体已装备" if current else "其他机体已装备" if owner>=0 else "未装备",Rect2(20,48,140,30),17,accent,HORIZONTAL_ALIGNMENT_CENTER)
			label(card,State.PARTS.SLOTS[equipped_slot] if owner>=0 else "武器 · 左右手通用" if part.slot==0 else State.PARTS.SLOTS[part.slot],Rect2(178,48,138 if owner>=0 else 378,30),17,accent)
			if owner>=0: label(card,State.mechs.name_of(owner),Rect2(322,48,234,30),17,accent,HORIZONTAL_ALIGNMENT_RIGHT)
			part_icon(card,part.blueprint,Rect2(16,88,52,70))
			label(card,"特性 / "+info.title+(" · 锁定" if State.parts.is_locked(part) else ""),Rect2(80,86,476,26),17,GOLD)
			var affixes := label(card,State.parts.affix_text(part)+("\n机制 / "+State.PARTS.MECHANISMS[part.mechanism].name if part.get("mechanism","")!="" else ""),Rect2(80,116,476,50),17,MUTED)
			affixes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if list.get_child_count()==0:
		var empty := label(list,"没有符合筛选的部件，可调整筛选条件。",Rect2(0,0,572,100),21,MUTED)
		empty.custom_minimum_size = Vector2(572,100)
	button(m,"机制筛选 / "+("全部" if mechanism_filter=="all" else "无机制" if mechanism_filter=="" else State.PARTS.MECHANISMS[mechanism_filter].name),Rect2(24,878,260,40),show_mechanism_filter)
	button(m,"只看锁定" if not locked_only else "锁定 ✓",Rect2(292,878,138,40),func(): locked_only=not locked_only; show_parts(),locked_only)
	button(m,"批量分解",Rect2(438,878,186,40),show_batch_recycle)
	button(m,"返回整备",Rect2(24,950,294,62),func(): close_modal(); show_page(1))
	refs.warehouse_overflow = button(m,"溢出仓 · %d" % State.parts.overflow.size(),Rect2(330,950,294,62),show_overflow)

func show_part_detail(id: int) -> void:
	var part: Dictionary = State.parts.find_part(id)
	if part.is_empty(): show_parts(); return
	var info: Dictionary = State.PARTS.BLUEPRINTS[part.blueprint]
	var target_slot: int = 4 if part.slot==0 and part_slot==4 else part.slot
	var current: Dictionary = State.parts.equipped(State.selected_mech,target_slot)
	var is_current: bool = not current.is_empty() and current.id==id
	var owner: int = State.parts.owner(id)
	var m := modal(State.parts.name_of(part),"%s / Lv.%d / %s / 属性成长 ×%.1f" % [State.PARTS.QUALITIES[part.quality],part.get("level",1),State.PARTS.SLOTS[part.slot],1.0+0.1*(int(part.get("level",1))-1)],960)
	var specs: Dictionary = State.parts.specs(part)
	label(m,"重量 %.0f · 供能 %.0f · %s %.0f" % [specs.weight,specs.power,"每轮热量" if State.MELEE.is_mode(info.trait) else "每发热量",specs.heat],Rect2(30,142,588,38),21,State.PARTS.COLORS[part.quality])
	label(m,"随机词条",Rect2(30,194,128,32),18,MUTED)
	button(m,"已锁定 · 点击解锁" if State.parts.is_locked(part) else "锁定 · 防止分解",Rect2(170,190,270,38),func(): State.set_part_flag(id,"locked",not State.parts.is_locked(part)); show_part_detail(id),State.parts.is_locked(part))
	button(m,"升级 / 校准",Rect2(450,190,168,38),func(): show_part_workshop(id))
	part_icon(m,part.blueprint,Rect2(476,235,128,112))
	for i in range(part.affixes.size()):
		var affix: Dictionary = part.affixes[i]
		var stat: Dictionary = State.PARTS.AFFIXES[affix.stat]
		label(m,"+ %s  %d%s" % [stat.name,affix.value,stat.unit],Rect2(30,235+i*38,588,34),22,Color("8cdec3"))
	rule(m,360,30,588)
	label(m,"特性 / "+info.title,Rect2(30,378,588,38),25,GOLD)
	var desc := label(m,info.desc+"\n"+State.parts.mechanism_text(part),Rect2(30,420,588,102),17)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(m,"当前装配："+State.parts.name_of(current),Rect2(30,525,588,34),20,MUTED)
	if not current.is_empty():
		var old := label(m,State.PARTS.BLUEPRINTS[current.blueprint].title+" / "+State.parts.affix_text(current),Rect2(30,566,588,62),17,MUTED)
		old.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var preview_parts = State.PARTS.new()
	preview_parts.import_save(State.parts.export_save())
	preview_parts.equip(State.selected_mech,id,target_slot)
	var before: Dictionary = State.equipment_stats()
	var after: Dictionary = State.equipment_stats(State.selected_mech,preview_parts)
	var compare := label(m,"换装变化  火力 %+d  ·  攻速 %+d%%  ·  移速 %+d%%\n减伤 %+d%%  ·  暴击 %+d%%  ·  每秒充能 %+d" % [after.attack-before.attack,after.haste-before.haste,after.speed-before.speed,after.armor-before.armor,after.crit-before.crit,after.energy-before.energy],Rect2(30,640,588,66),18,Color("a7d5e3"))
	var planned: Dictionary = State.mech_configuration(State.selected_mech,preview_parts)
	compare.text += "\n重量 %.0f/%.0f · 供能 %.0f/%.0f · %s" % [planned.weight,planned.capacity,planned.power,planned.supply,planned.reason]
	compare.add_theme_font_size_override("font_size",16)
	compare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(m,"装配于 "+State.mechs.name_of(owner)+" · 转装会从原机甲卸下" if owner>=0 else "闲置部件 · 分解可得 %d 合金芯" % (6*(int(part.quality)+1)),Rect2(30,738,588,28),17,GOLD)
	button(m,"卸下部件" if is_current else "装配至"+State.PARTS.SLOTS[target_slot],Rect2(30,774,280 if part.slot==0 else 374,66),func():
		if is_current: State.unequip_part(target_slot)
		else: State.equip_part(id,target_slot)
		show_part_detail(id),true)
	if part.slot==0:
		button(m,"换手",Rect2(326,774,120,66),func(): part_slot=0 if target_slot==4 else 4; show_part_detail(id))
	var recycle := button(m,"分解",Rect2(464 if part.slot==0 else 422,774,154 if part.slot==0 else 196,66),func():
		if State.recycle_part(id): show_parts())
	recycle.disabled = not State.parts.recyclable(part)
	button(m,"返回仓库",Rect2(30,866,588,56),show_parts)

func show_manufacturing() -> void:
	manufacturing_ui.show_catalog()

func show_mechanism_filter() -> void:
	var m := modal("仓库机制筛选","可与部位分组、锁定筛选组合使用",960)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24,140); scroll.size = Vector2(600,690)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8); scroll.add_child(list)
	var keys: Array = ["all",""]+State.PARTS.MECHANISMS.keys()
	for key in keys:
		var row := Control.new(); row.custom_minimum_size = Vector2(572,52); list.add_child(row)
		var title: String = "全部机制" if key=="all" else "无机制" if key=="" else State.PARTS.MECHANISMS[key].name
		button(row,title,Rect2(0,0,572,52),func(): mechanism_filter=key; show_parts(),key==mechanism_filter)
	button(m,"返回仓库",Rect2(30,866,588,56),show_parts)

func show_batch_recycle() -> void:
	recycle_ui.open()

func show_overflow() -> void:
	if not World.docked: request_base(); return
	while World.boss.pending_epics>0: World.boss.claim_reward()
	var m := modal("掉落溢出仓","满仓掉落保留完整品质和词条 / 不自动销毁",960)
	label(m,"保管 %d 件 · 主仓 %d/%d" % [State.parts.overflow.size(),State.parts.inventory.size(),State.PARTS.LIMIT],Rect2(30,140,588,40),24,GOLD)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24,205); scroll.size = Vector2(600,570)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10); scroll.add_child(list)
	for part in State.parts.overflow:
		var row := Control.new(); row.custom_minimum_size = Vector2(572,96); list.add_child(row)
		box(row,Rect2(0,0,572,96),Color("172434"))
		part_icon(row,part.blueprint,Rect2(12,16,58,64))
		label(row,State.parts.name_of(part)+" / "+State.PARTS.QUALITIES[part.quality],Rect2(82,8,480,32),23,State.PARTS.COLORS[part.quality])
		var text := label(row,State.parts.affix_text(part)+("\n"+State.PARTS.MECHANISMS[part.mechanism].name if part.get("mechanism","")!="" else ""),Rect2(82,43,480,49),17,MUTED)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if State.parts.overflow.is_empty():
		var empty := label(list,"暂无溢出掉落。主仓满时，战利品会保存在这里。",Rect2(0,0,572,100),21,MUTED)
		empty.custom_minimum_size = Vector2(572,100); empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var collect := button(m,"取回至部件仓库",Rect2(30,800,588,66),func(): State.collect_overflow(); show_overflow(),true)
	collect.disabled = State.parts.overflow.is_empty() or State.parts.inventory.size()>=State.PARTS.LIMIT
	button(m,"关闭仓库",Rect2(30,886,588,48),close_modal)

func show_part_workshop(id: int) -> void:
	var part: Dictionary = State.parts.find_part(id)
	if part.is_empty(): show_parts(); return
	if int(State.parts.reforge.get("id",0))==id: show_reforge_choices(); return
	var level: int = part.get("level",1)
	var cap: int = State.parts.upgrade_limit(State.stage)
	var m := modal("部件升级与校准",State.parts.name_of(part)+" / 品质和机制不因升级改变",960)
	label(m,"部件 Lv.%d / 当前区域上限 %d\n每级提高 10%% 基础属性与数值词条效果" % [level,cap],Rect2(30,140,588,64),21,GOLD)
	var upgrade := button(m,"升级 · C%d / 合金%d" % [300*level,10*level],Rect2(30,220,588,60),func(): State.upgrade_part(id); show_part_workshop(id),true)
	upgrade.disabled = level>=cap
	var index: int = part.get("reforge_slot",-1)
	label(m,"数值重铸 / 每次 C150 + 合金8\n首次选择后仅可重铸该条；三选一或保留旧结果。",Rect2(30,306,588,68),20,MUTED)
	for i in range(part.affixes.size()):
		var affix: Dictionary = part.affixes[i]
		var info: Dictionary = State.PARTS.AFFIXES[affix.stat]
		var row := button(m,"%s +%d%s%s  ›" % [info.name,affix.value,info.unit," · 校准位" if index==i else ""],Rect2(30,390+i*58,588,50),func():
			if State.reforge_part(id,i): show_reforge_choices())
		row.disabled = (index>=0 and index!=i) or not State.parts.reforge.is_empty()
	if not State.parts.reforge.is_empty():
		button(m,"继续上次未选择的重铸",Rect2(30,574,588,54),show_reforge_choices)
	else:
		button(m,"机制研究与定向安装",Rect2(30,574,588,60),func(): show_mechanism_research(id),true)
	var desc := label(m,"分解含机制的部件可获得研究进度（精良1 / 稀有2 / 史诗3）。累计6点后永久解锁，对兼容部件定向安装。",Rect2(30,658,588,108),21,MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(m,"返回部件详情",Rect2(30,866,588,56),func(): show_part_detail(id))

func show_reforge_choices() -> void:
	if State.parts.reforge.is_empty(): show_parts(); return
	var pending: Dictionary = State.parts.reforge
	var id: int = pending.id
	var part: Dictionary = State.parts.find_part(id)
	if part.is_empty(): show_parts(); return
	var old: Dictionary = part.affixes[part.reforge_slot]
	var info: Dictionary = State.PARTS.AFFIXES[old.stat]
	var m := modal("重铸结果 · 三选一","结果已保存，关闭或刷新后可继续选择 / 不重复扣费",760)
	label(m,"旧词条：%s +%d%s" % [info.name,old.value,info.unit],Rect2(30,145,588,44),24,GOLD)
	for i in range(3):
		var choice: Dictionary = pending.choices[i]
		var stat: Dictionary = State.PARTS.AFFIXES[choice.stat]
		button(m,"选择 / %s +%d%s" % [stat.name,choice.value,stat.unit],Rect2(30,220+i*98,588,78),func(): State.resolve_reforge(i); show_part_workshop(id),true)
	button(m,"保留旧词条",Rect2(30,556,588,66),func(): State.resolve_reforge(-1); show_part_workshop(id))
	button(m,"稍后选择 · 返回部件",Rect2(30,650,588,66),func(): show_part_detail(id))

func show_mechanism_research(id: int) -> void:
	var part: Dictionary = State.parts.find_part(id)
	if part.is_empty(): show_parts(); return
	var m := modal("机制研究与安装","拆解积累6点永久解锁 / 每次安装 C400 + 合金20",960)
	label(m,"研究资料 %d · 安装会替换原机制，保留数值词条。" % State.parts.research_materials,Rect2(30,140,588,45),20,GOLD)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24,205); scroll.size = Vector2(600,620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12); scroll.add_child(list)
	for key in State.PARTS.MECHANISMS:
		var info: Dictionary = State.PARTS.MECHANISMS[key]
		var compatible: bool = key in State.parts.mechanism_pool(part.blueprint)
		var ready: bool = State.parts.research_ready(key)
		var active: bool = part.get("mechanism","")==key
		var can_research: bool = not ready and State.parts.research_materials>0
		var row := Control.new(); row.custom_minimum_size = Vector2(572,138); list.add_child(row)
		box(row,Rect2(0,0,572,138),Color("172434"))
		label(row,info.name,Rect2(12,8,390,32),24,GOLD)
		var desc := label(row,info.desc,Rect2(12,48,386,82),17,MUTED); desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label(row,"已解锁" if ready else "%d / 6" % State.parts.research.get(key,0),Rect2(414,10,146,32),20,Color("8cdec3") if ready else MUTED,HORIZONTAL_ALIGNMENT_CENTER)
		var install := button(row,"研究 %d资料" % mini(State.parts.research_materials,6-int(State.parts.research.get(key,0))) if can_research else "已安装" if active else "不兼容" if not compatible else "安装" if ready else "研究中",Rect2(414,65,146,52),func():
			if can_research: State.invest_research(key)
			else: State.install_mechanism(id,key)
			show_mechanism_research(id),can_research or (ready and compatible and not active))
		install.add_theme_font_size_override("font_size",20)
		install.disabled = not can_research and (active or not ready or not compatible)
	button(m,"返回部件校准",Rect2(30,866,588,56),func(): show_part_workshop(id))

func build_pilots() -> void:
	small_header(body,"机师档案",188,"PILOTS / %d 位机师 · 自由换乘 · 独立技能与故事"%State.PILOTS.size())
	portrait_index = clampi(portrait_index,0,State.PILOTS.size()-1)
	for i in range(State.PILOTS.size()):
		var b := button(body,State.PILOTS[i].name + (" · 待招募" if not State.unlocked[i] else ""),Rect2(24+(i%3)*228,280+int(i/3.0)*58,216,48),func(): portrait_index=i; show_page(2),i==portrait_index,State.PILOTS[i].color.darkened(0.3))
		b.name = "PilotTab_%d"%i
		b.add_theme_font_size_override("font_size",20)
	var p: Dictionary = State.PILOTS[portrait_index]
	box(body,Rect2(24,400,672,475),Color("161e2b"),Color("323b4c"))
	photo(body,portrait_index,Rect2(25,401,360,473)).name = "PilotPortrait_%d"%portrait_index
	label(body,"SSR",Rect2(410,420,250,45),34,GOLD)
	label(body,p.code,Rect2(410,475,250,32),19,p.color)
	label(body,p.name,Rect2(410,517,250,68),49)
	label(body,p.role,Rect2(410,600,250,36),23,MUTED)
	label(body,"AGE  %d" % p.age,Rect2(410,645,250,32),16,MUTED)
	refs.pilot_level = label(body,"",Rect2(410,705,250,42),25,GOLD)
	refs.pilot_status = label(body,"",Rect2(410,782,250,36),18,p.color)
	var bio := label(body,p.bio,Rect2(24,891,672,78),20,MUTED)
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if State.unlocked[portrait_index]:
		refs.deploy = button(body,"",Rect2(24,991,324,76),func(): State.choose(portrait_index); toast("主战机师已切换"); show_page(2),true)
		button(body,"强化  ↑",Rect2(372,991,324,76),func(): State.upgrade(portrait_index))
		button(body,"技能与战术",Rect2(24,1084,324,54),func(): pilot_ui.show_abilities(portrait_index))
		button(body,"信赖与个人任务",Rect2(372,1084,324,54),func(): pilot_ui.show_relationship(portrait_index))
	else:
		refs.direct_recruit = button(body,"定向招募  ◇300",Rect2(24,991,324,76),func():
			if State.recruit_pilot(portrait_index): show_page(2); toast(p.name+"已加入小队"),true)
		refs.direct_recruit.name = "DirectRecruit"
		button(body,"随机招募  ›",Rect2(372,991,324,76),func(): show_page(3))
		button(body,"查看技能与战术",Rect2(24,1084,324,54),func(): pilot_ui.show_abilities(portrait_index))
		label(body,"定向招募直接解锁本机师",Rect2(372,1084,324,54),18,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	refs.pilot_recruit = button(body,"同调招募  ›",Rect2(24,1158,672,64),func(): show_page(3))

func build_recruit() -> void:
	small_header(body,"同调招募",188,"RESONANCE / 新的羁绊，新的战力")
	var banner := box(body,Rect2(24,280,672,564),Color("182236"),Color("354258"))
	INTERFACE.panel(banner)
	var scene := TextureRect.new()
	scene.texture=CONTENT.SHEETS.hangar;scene.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.position=Vector2(10,10);scene.size=Vector2(652,544)
	scene.modulate=Color(0.35,0.45,0.65,0.65);scene.mouse_filter=Control.MOUSE_FILTER_IGNORE
	banner.add_child(scene)
	var featured := portrait_index if portrait_index>=3 else 3
	featured = mini(featured,State.PILOTS.size()-1)
	var pilot: Dictionary = State.PILOTS[featured]
	photo(body,featured,Rect2(302,294,380,536))
	label(body,"六位机师集结",Rect2(48,396,310,70),34,WHITE)
	label(body,"自由驾驶全部机体",Rect2(52,474,258,36),21,GOLD)
	label(body,"RESONANCE / %02d"%State.PILOTS.size(),Rect2(52,521,238,26),16,MUTED)
	box(body,Rect2(40,301,167,39),Color("111b2a"))
	label(body,"常驻机师信标",Rect2(40,301,167,39),17,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	box(body,Rect2(40,664,285,150),Color(0.04,0.07,0.12,0.9))
	label(body,"SSR   "+pilot.name,Rect2(59,678,250,53),37,GOLD)
	label(body,pilot.skill,Rect2(59,741,250,32),21)
	label(body,pilot.code+" / "+pilot.role,Rect2(59,782,250,21),12,MUTED)
	refs.recruit_hint = label(body,"",Rect2(24,865,672,38),21,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	var hint := label(body,"首次招募解锁「凛」；后续六位机师等概率 1/6。未拥有则加入小队，已拥有则等级 +1；机师档案支持 ◇300 定向招募。",Rect2(38,914,644,76),17,MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(body,"单次招募  ◇100",Rect2(24,1012,324,77),func(): pull(1),true)
	button(body,"十次招募  ◇1000",Rect2(372,1012,324,77),func(): pull(10))
	label(body,"招募消耗游戏内星晶 · 无付费入口",Rect2(24,1115,672,30),16,MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func refresh() -> void:
	if refs.is_empty(): return
	manufacturing_ui.refresh()
	recycle_ui.refresh()
	for i in range(3):
		refs["resource%d"%i].text = number([State.credits,State.cores,State.gems][i])
	refs.sound_icon.texture = icon_texture(SOUND_ON if State.sound_enabled else SOUND_OFF)
	refresh_world()
	if is_instance_valid(refs.get("hangar_name")):
		refs.combat_style.text = "武器节奏 · "+State.weapon_style_summary()
		refs.hangar_name.text = State.mechs.name_of(State.selected_mech)
		refs.hangar_level.text = "Lv.%02d" % State.mech_level()
		refs.hangar_stats.text = "小队攻击  %d      基础移速  %d      战力  %s" % [State.total_attack(),State.mech_configuration().base_speed,number(State.power())]
		for slot in range(6):
			var part: Dictionary = State.parts.equipped(State.selected_mech,slot)
			refs["slot_art%d"%slot].visible = not part.is_empty()
			if not part.is_empty(): refs["slot_art%d"%slot].texture = CONTENT.texture("equipment",int(part.blueprint))
			refs["slot_name%d"%slot].text = State.parts.name_of(part)
			refs["slot_name%d"%slot].add_theme_color_override("font_color",MUTED if part.is_empty() else State.PARTS.COLORS[part.quality])
			refs["slot_trait%d"%slot].text = "点击装配 ›" if part.is_empty() else State.PARTS.BLUEPRINTS[part.blueprint].title+" ›"
		refs.parts_button.text = "部件仓库  %d/%d  ›" % [State.parts.inventory.size(),State.PARTS.LIMIT]
		var stats: Dictionary = State.equipment_stats()
		var build: Dictionary = State.mech_configuration()
		refs.part_summary.text = "重量 %.0f/%.0f · 供能 %.0f/%.0f · 散热 %.0f/秒\n%s · 当前移速 %.0f · 减伤 %.0f%%" % [build.weight,build.capacity,build.power,build.supply,build.cooling,build.reason,World.move_speed(),stats.armor]
		refs.part_summary.add_theme_color_override("font_color",Color("8cdec3") if build.valid else RED)
		refs.upgrade_cost.text = "消耗   %s 信用点    /    %s 合金芯" % [State.mech_upgrade_cost(),State.mech_core_cost()]
	if is_instance_valid(refs.get("pilot_level")):
		refs.pilot_level.text = "Lv.%02d" % State.levels[portrait_index]
		refs.pilot_status.text = "主战中 / ACTIVE" if portrait_index == State.selected else "小队支援中" if State.unlocked[portrait_index] else "尚未加入小队"
		if is_instance_valid(refs.get("deploy")):
			refs.deploy.text = "已设为主战" if portrait_index == State.selected else "设为主战"
		if is_instance_valid(refs.get("direct_recruit")):
			refs.direct_recruit.disabled = State.gems<300 or State.unlocked[portrait_index]
	if is_instance_valid(refs.get("recruit_hint")):
		var owned: int = State.unlocked.count(true)
		refs.recruit_hint.text = "首次招募必得 SSR「凛」" if not State.unlocked[2] else "全员集结 · 重复同调提升等级" if owned==State.PILOTS.size() else "已集结 %d / %d 位 · 新同伴等待回应"%[owned,State.PILOTS.size()]

func number(v: int) -> String:
	if v >= 1000000: return "%.2fM" % (v/1000000.0)
	if v >= 10000: return "%.1fK" % (v/1000.0)
	return str(v)

func toast(text_value: String) -> void:
	toast_label.text = text_value
	toast_label.show()
	toast_timer = 3.5

func _process(delta: float) -> void:
	story_ui.tick(delta)
	if is_instance_valid(story_ui.stage): return
	if (Cloud.pending_claim!="" or (Cloud.busy and Cloud.mutating)) and not is_instance_valid(refs.get("cloud_status")): cloud_ui.show_cloud()
	cloud_ui.refresh()
	salvage_ui.refresh_all()
	carrier_ui.refresh()
	refresh_map_status()
	refresh_training()
	refresh_base()
	refresh_world()
	if toast_timer > 0:
		toast_timer -= delta
		if toast_timer <= 0: toast_label.hide()
	hud_ui.refresh_skill()

func on_victory() -> void:
	if State.wins == 1: toast("首战告捷！敌军据点已肃清，可继续探索。")

func toggle_sound() -> void:
	State.sound_enabled = not State.sound_enabled
	if not State.sound_enabled: Sfx.stop_all()
	State.save_game()
	refresh()

func close_modal() -> void:
	if Cloud.pending_claim!="" and not rebuilding_cloud_modal:
		toast("请先恢复结算或下载最新云档案"); return
	story_ui.suspend()
	for n in overlay.get_children(): n.free()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func modal(title: String, subtitle: String, height_value: float = 610) -> Control:
	if is_instance_valid(refs.get("map")): refs.map.reset_input()
	close_modal()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.015,0.025,0.045,0.9)
	dim.size = Vector2(720,1280)
	overlay.add_child(dim)
	var container := Control.new()
	container.position = Vector2(36,(1280-height_value)/2)
	container.size = Vector2(648,height_value)
	overlay.add_child(container)
	INTERFACE.panel(box(container,Rect2(0,0,648,height_value),Color("141e2c"),Color("425066"),8))
	box(container,Rect2(0,0,648,4),RED)
	label(container,title,Rect2(30,30,500,52),31)
	label(container,subtitle,Rect2(30,90,570,30),16,MUTED)
	button(container,"×",Rect2(560,29,56,56),close_modal)
	return container

func show_idle() -> void:
	salvage_ui.show_idle()

func show_certificates() -> void:
	salvage_ui.show_certificates()

func show_certification_progress() -> void:
	salvage_ui.show_certification_progress()

func show_missions() -> void:
	if not World.docked: request_base(); return
	var m := modal("行动任务","前线成长目标 / 奖励可用于机师招募",640)
	var titles := ["肃清 5 个区域","完成 3 次机甲强化","进行 1 次机师招募"]
	for i in range(3):
		var y := 155 + i*130
		label(m,titles[i],Rect2(30,y,400,35),23)
		label(m,"进度 %d/%d    ◇ +%d" % [mini(State.mission_progress(i),State.mission_goal(i)),State.mission_goal(i),[200,200,100][i]],Rect2(30,y+44,400,30),17,MUTED)
		var done: bool = i in State.claimed
		var ready: bool = State.mission_progress(i) >= State.mission_goal(i)
		var b := button(m,"已领取" if done else "领取" if ready else "进行中",Rect2(458,y+5,160,65),func(): State.claim_mission(i); show_missions(),ready and not done)
		b.disabled = done or not ready
		if i < 2: rule(m,y+103,30,588)

	button(m,"返回母舰",Rect2(30,550,588,56),close_modal)

func show_help() -> void:
	var m := modal("指挥官手册","CRIMSON FRONT / 竖屏机甲放置战斗",760)
	var lines := ["01  自由探索\n全屏按下即浮动摇杆，拖动走位，松手停。\n双指拖图/缩放，桌面支持 WASD。", "02  地图交互\n实地行进揭开迷雾，靠近设施后点击交互。\n发现首领后可继续探索，准备好再挑战。", "03  自动战斗\n自动选敌、接敌、开火与避险；拖动接管。\n两种模式都自动开火，满能按战术释放技能。", "04  母舰与小队\n回舰结算、整备；机师休息室可交流。\n航行日志回看剧情，机师带教学习实际操作。"]
	var y := 150
	for text_value in lines:
		var l := label(m,text_value,Rect2(30,y,588,110),21,Color("bbc5d4"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		y += 125
	button(m,"机师带教",Rect2(30,657,284,70),story_ui.show_guide,true)
	button(m,"航行日志",Rect2(330,657,288,70),story_ui.show_archive)

func pull(count: int) -> void:
	if is_instance_valid(recruit_sequence): return
	if not State.recruit(count): return
	close_modal()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	recruit_sequence = preload("res://scripts/recruit_sequence.gd").new()
	recruit_sequence.name = "RecruitSequence"
	overlay.add_child(recruit_sequence)
	recruit_sequence.setup(self,State.last_pull.duplicate())

func finish_recruit() -> void:
	close_modal()
	show_page(3)
