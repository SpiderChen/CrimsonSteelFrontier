extends RefCounted
## Keep the carrier focused on departure; specialist facilities live in their own sections.
const WHITE := Color("f2f1f3")
const MUTED := Color("8c9caf")
const MINT := Color("8cdec3")
const GOLD := Color("e9c78e")
const FACILITY_PANEL = preload("res://assets/free/ui/facility_panel.png")
const FACILITY_ICONS = {
	"hangar":preload("res://assets/free/icons/wrench.png"),
	"parts":preload("res://assets/free/icons/menuGrid.png"),
	"manufacturing":preload("res://assets/free/icons/power.png"),
	"training":preload("res://assets/free/icons/gamepad.png"),
	"presets":preload("res://assets/free/icons/save.png"),
	"tactics":preload("res://assets/free/icons/joystick.png"),
	"pilots":preload("res://assets/free/icons/singleplayer.png"),
	"recruit":preload("res://assets/free/icons/star.png"),
	"missions":preload("res://assets/free/icons/trophy.png"),
	"carrier":preload("res://assets/free/icons/home.png"),
	"exchange":preload("res://assets/free/icons/gear.png"),
	"salvage":preload("res://assets/free/icons/medal1.png"),
	"overflow":preload("res://assets/free/icons/menuGrid.png"),
	"cloud":preload("res://assets/free/icons/share1.png"),
	"story":preload("res://assets/free/icons/singleplayer.png")
}
var app: Node
func _init(owner: Node) -> void: app = owner
func text(parent: Node, value: String, rect: Rect2, font_size: int = 22, color: Color = WHITE) -> Label:
	var result: Label = app.label(parent,value,rect,font_size,color)
	result.clip_text = true
	return result
func action(parent: Node, value: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var result: Button = app.button(parent,value,rect,callback,primary)
	return result
func bar(parent: Node, rect: Rect2, color: Color) -> Range:
	var result = preload("res://scripts/hud_meter.gd").new()
	result.position = rect.position; result.size = rect.size; result.color = color
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result
func facility(parent: Node, id: String, title: String, caption: String, rect: Rect2, accent: Color = MINT) -> Button:
	var card := action(parent,"",rect,func(): open_facility(id))
	app.INTERFACE.facility(card,accent)
	card.name = "Facility_"+id
	app.icon(card,FACILITY_ICONS[id],Rect2(22,24,30,30),accent)
	text(card,title,Rect2(66,20,rect.size.x-90,40),25)
	var detail := text(card,caption,Rect2(24,76,rect.size.x-48,28),19,MUTED)
	app.refs["base_facility_"+id] = card
	app.refs["base_caption_"+id] = detail
	return card

func open_facility(id: String) -> void:
	app.close_modal()
	if app.overlay.get_child_count()>0: return
	match id:
		"hangar": app.show_page(1)
		"parts": app.warehouse_slot=-1; app.show_parts()
		"pilots": app.portrait_index=State.selected; app.show_page(2)
		"recruit": app.show_page(3)
		"salvage": app.show_idle()
		"manufacturing": app.show_manufacturing()
		"training": app.show_training()
		"presets": app.show_presets()
		"tactics": app.show_tactics()
		"carrier": app.carrier_ui.show_bridge()
		"exchange": app.carrier_ui.show_exchange()
		"missions": app.show_missions()
		"overflow": app.show_overflow()
		"cloud": app.cloud_ui.show_cloud()
		"story": app.story_ui.show_archive()

func show_section(section: String) -> void:
	var groups := {
		"build":{"title":"构筑工坊","caption":"制造、试验与配置你的机甲","entries":[
			["manufacturing","制造工坊","按蓝图制造部件"],
			["training","构筑训练舱","验证输出与生存能力"],
			["presets","配装档案库","保存与切换构筑"],
			["tactics","自动战术","索敌、走位与技能策略"]]},
		"fleet":{"title":"舰务中心","caption":"管理战舰支援与行动物资","entries":[
			["carrier","战舰指挥","护航、战术指令与改造"],
			["exchange","副本物资","区域样本兑换部件"],
			["missions","行动任务","查看目标与领取奖励"]]},
		"archive":{"title":"档案中心","caption":"保存航行进度，回看小队故事","entries":[
			["cloud","云端档案","账号与跨设备存档"],
			["story","航行日志","剧情回看与机师带教"]]}
	}
	if not groups.has(section): return
	var group: Dictionary = groups[section]
	var m: Control = app.modal(group.title,group.caption,760)
	m.name = "FacilitySection_"+section
	for i in range(group.entries.size()):
		var entry: Array = group.entries[i]
		var id: String = entry[0]
		var row := action(m,"",Rect2(24,150+i*104,600,88),func(): open_facility(id))
		row.name = "Facility_"+id
		app.icon(row,FACILITY_ICONS[id],Rect2(20,27,30,30),MINT)
		text(row,entry[1],Rect2(68,8,460,34),24)
		text(row,entry[2],Rect2(68,46,460,28),18,MUTED)
		text(row,"›",Rect2(548,22,28,40),30,MINT)
		app.refs["base_facility_"+id] = row
	action(m,"返回整备" if section=="build" else "返回母舰",Rect2(24,656,600,64),app.close_modal)

func build_base() -> void:
	var pilot: Dictionary = State.PILOTS[State.selected]
	var bay: Control = app.box(app.body,Rect2(24,190,672,300),Color("101f2b"),Color("293f4d"))
	app.INTERFACE.panel(bay)
	bay.clip_contents = true
	var backdrop := TextureRect.new()
	backdrop.texture = preload("res://scripts/production_art.gd").SHEETS.hangar
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.position = Vector2(8,8); backdrop.size = Vector2(656,284)
	backdrop.modulate = Color(0.4,0.5,0.6,0.4)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bay.add_child(backdrop)
	text(app.body,"绯红方舟 / 机师待命",Rect2(44,206,356,30),19,MUTED)
	text(app.body,pilot.name,Rect2(44,244,350,52),40,pilot.color)
	text(app.body,pilot.role,Rect2(44,300,350,28),20)
	var portrait := action(app.body,"",Rect2(420,190,276,300),app.pilot_ui.open_active)
	portrait.name = "HomePilotPortrait"; portrait.clip_contents = true
	app.photo(portrait,State.selected,Rect2(4,4,268,292))
	app.box(portrait,Rect2(4,258,268,38),Color(0.025,0.045,0.075,0.88))
	text(portrait,"查看机师  ›",Rect2(12,261,252,30),19).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	app.refs.base_portrait = portrait
	app.refs.base_status = text(app.body,"",Rect2(44,340,356,46),18,MINT)
	app.refs.base_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.refs.base_chassis = text(app.body,"",Rect2(44,392,356,26),18,MUTED)
	app.refs.base_pilot = text(app.body,"",Rect2(44,430,350,44),18,MUTED)
	app.refs.base_pilot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.refs.base_pilot.max_lines_visible = 2
	var launch := action(app.body,"",Rect2(24,516,672,104),app.launch_from_base,true)
	app.INTERFACE.launch(launch,app.RED)
	launch.name = "LaunchOperation"; launch.tooltip_text = "副本作战 · 选择地图"
	text(launch,"副本作战",Rect2(30,16,500,42),30)
	text(launch,"选择地图 · 准备出击",Rect2(32,60,500,26),18,Color("ffd6dd"))
	app.refs.base_launch = launch
	text(app.body,"常用设施",Rect2(24,650,480,30),21,MUTED)
	facility(app.body,"hangar","机甲整备","装配 · 强化 · 构筑工坊",Rect2(24,696,328,120))
	facility(app.body,"parts","部件仓库","比较 · 装配 · 整理",Rect2(368,696,328,120),Color("8cc9eb"))
	facility(app.body,"pilots","机师","技能 · 信赖 · 招募",Rect2(24,838,328,120),Color("c7b3ed"))
	facility(app.body,"salvage","前线回收","回收队正在作业",Rect2(368,838,328,120),GOLD)
	app.refs.base_fleet = action(app.body,"舰务  /  指挥与物资  ›",Rect2(24,1010,328,68),func(): show_section("fleet"))
	app.refs.base_archive = action(app.body,"档案  /  存档与日志  ›",Rect2(368,1010,328,68),func(): show_section("archive"))
	for utility in [app.refs.base_fleet,app.refs.base_archive]:
		app.INTERFACE.compact(utility,MUTED)
		utility.add_theme_font_size_override("font_size",20)
	app.refs.base_notice_missions = action(app.body,"",Rect2(24,1110,328,72),func(): open_facility("missions"))
	app.refs.base_notice_overflow = action(app.body,"",Rect2(368,1110,328,72),func(): open_facility("overflow"))
	for notice in [app.refs.base_notice_missions,app.refs.base_notice_overflow]:
		app.INTERFACE.compact(notice,GOLD)
		notice.add_theme_font_size_override("font_size",20)
	refresh_base()

func refresh_base() -> void:
	if not is_instance_valid(app.refs.get("base_status")): return
	var build: Dictionary = State.mech_configuration()
	app.refs.base_status.text = "装甲重建中 · %.1f 秒后复活"%State.recovery if State.recovery>0 else "整备完成 · 装甲 100%"
	app.refs.base_chassis.text = State.mechs.name_of(State.selected_mech)+" · Lv.%d" % State.mech_level()
	app.refs.base_pilot.text = "“"+app.pilot_ui.greeting()+"”"
	app.refs.base_launch.disabled = false
	if State.recovery<=0 and not build.valid: app.refs.base_status.text = build.reason+" · 前往机库调整"
	app.refs.base_caption_salvage.text = "待领取 C%s  ›"%app.number(State.pending_credits) if State.pending_credits>0 else "回收队正在作业"
	app.refs.base_caption_salvage.add_theme_color_override("font_color",GOLD if State.pending_credits>0 else MUTED)
	var ready := 0
	for i in range(3):
		if i not in State.claimed and State.mission_progress(i)>=State.mission_goal(i): ready += 1
	app.refs.base_notice_missions.visible = ready>0
	app.refs.base_notice_missions.text = "任务奖励 · %d 项可领取  ›" % ready
	app.refs.base_notice_overflow.visible = not State.parts.overflow.is_empty()
	app.refs.base_notice_overflow.text = "溢出仓 · %d 件待取回  ›" % State.parts.overflow.size()

func build_battle() -> void:
	var map := Control.new(); map.set_script(app.MAP); map.size = Vector2(720,1280)
	map.radar_visible = app.battle_radar
	app.body.add_child(map); app.refs.map = map
	map.carrier_selected.connect(func(): app.carrier_ui.show_bridge() if State.expedition.active() else app.request_base())
	app.INTERFACE.panel(app.box(app.body,Rect2(12,8,696,104),Color("192839")))
	app.box(app.body,Rect2(24,24,3,70),MINT)
	app.refs.world_region = text(app.body,"",Rect2(38,20,420,38),27)
	app.refs.world_status = text(app.body,"",Rect2(38,65,410,28),18,MINT)
	app.refs.world_coords = text(app.body,"",Rect2(),17,MUTED); app.refs.world_coords.hide()
	app.refs.battle_tools = action(app.body,"更多",Rect2(616,16,80,80),show_tools)
	app.refs.battle_tools.add_theme_font_size_override("font_size",20)
	app.refs.hud_exploration = action(app.body,"探索概览",Rect2(24,124,196,72),app.show_map_status)
	app.refs.hud_target = action(app.body,"首领部位",Rect2(24,124,196,72),show_boss_targets)
	app.refs.hud_carrier = action(app.body,"战舰指挥",Rect2(440,124,256,72),app.carrier_ui.show_bridge)
	app.refs.hud_carrier.add_theme_font_size_override("font_size",18)
	app.INTERFACE.compact(app.refs.hud_carrier,MINT)
	app.refs.support_cannon = action(app.body,"舰炮支援",Rect2(24,1016,176,80),func(): State.carrier.call_support(World,"cannon"))
	app.refs.support_repair = action(app.body,"维修投送",Rect2(212,1016,176,80),func(): State.carrier.call_support(World,"repair"))
	app.refs.hud_interact = action(app.body,"交互",Rect2(412,1016,192,80),app.show_map_interaction,true)
	app.refs.hud_interact.add_theme_font_size_override("font_size",18)
	app.refs.support_cannon.add_theme_font_size_override("font_size",18)
	app.refs.support_repair.add_theme_font_size_override("font_size",18)
	app.refs.follow = action(app.body,"",Rect2(616,920,80,80),func(): map.recenter())
	var return_button := action(app.body,"",Rect2(616,1016,80,80),app.request_base)
	app.refs.hud_return = return_button
	return_button.icon=FACILITY_ICONS.carrier
	return_button.expand_icon=true;return_button.add_theme_constant_override("icon_max_width",26)
	app.refs.follow.icon=FACILITY_ICONS.tactics
	app.refs.follow.expand_icon=true;app.refs.follow.add_theme_constant_override("icon_max_width",26)
	return_button.tooltip_text="母舰回航"
	app.refs.hud_return=return_button
	app.refs.follow.tooltip_text="定位机甲"
	app.refs.battle_tools.text=""
	app.refs.battle_tools.icon=FACILITY_ICONS.parts
	app.refs.battle_tools.expand_icon=true
	app.refs.battle_tools.add_theme_constant_override("icon_max_width",26)
	app.refs.battle_tools.tooltip_text="战场工具"
	for control in [app.refs.follow,return_button,app.refs.battle_tools]:
		app.INTERFACE.compact(control,MINT,true)
		control.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var caption: String="定位" if control==app.refs.follow else "回舰" if control==return_button else "工具"
		var texture: Texture2D=control.icon
		control.icon=null
		app.icon(control,texture,Rect2(27,15,26,26),MINT)
		text(control,caption,Rect2(4,47,72,22),14,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for control in [app.refs.hud_exploration,app.refs.hud_target,app.refs.support_cannon,app.refs.support_repair]:
		app.INTERFACE.compact(control)
	app.INTERFACE.compact(app.refs.hud_interact,GOLD)
	var vitals: Control = app.box(app.body,Rect2(24,1120,444,136),Color(0.035,0.065,0.095,0.96),Color("304653"),12)
	app.INTERFACE.panel(vitals)
	vitals.mouse_filter = Control.MOUSE_FILTER_STOP
	app.refs.battle_portrait = app.photo(app.body,State.selected,Rect2(32,1128,116,120))
	app.box(app.body,Rect2(32,1246,116,2),State.PILOTS[State.selected].color)
	app.refs.active_name = text(app.body,"",Rect2(160,1128,292,30),22)
	app.refs.hud_armor = text(app.body,"",Rect2(160,1163,292,27),19,MINT)
	app.refs.hud_hp_bar = bar(app.body,Rect2(160,1193,292,10),MINT)
	app.refs.heat = text(app.body,"",Rect2(160,1209,292,25),18,GOLD)
	app.refs.hud_heat_bar = bar(app.body,Rect2(160,1239,292,8),GOLD)
	app.refs.ultimate = action(app.body,"",Rect2(536,1120,160,136),func(): State.ultimate(),true)
	app.INTERFACE.compact(app.refs.ultimate,GOLD,true)
	app.refs.ultimate.add_theme_font_size_override("font_size",18)
	app.icon(app.refs.ultimate,FACILITY_ICONS.manufacturing,Rect2(8,8,20,20),GOLD)
	app.refs.hud_energy = bar(app.body,Rect2(558,1233,116,6),Color("fff0d7"))
	refresh_world(); refresh_skill()

func refresh_world() -> void:
	if not is_instance_valid(app.refs.get("map")): return
	app.refs.world_region.text = World.boss.display_name() if World.boss.active else World.region_name(World.position)
	app.refs.world_coords.text = "X %06d  Y %06d · 已探索 %d 区块"%[World.position.x,World.position.y,World.explored.size()]
	if State.recovery>0: app.refs.world_status.text = "母舰回收中 · %.1f 秒后复活"%State.recovery
	elif World.boss.active: app.refs.world_status.text = "阶段 %d · 核心 %.0f%%"%[World.boss.phase,100*World.boss.hp/World.boss.maximum]
	elif World.movement_blocked: app.refs.world_status.text = "前方有障碍 · 换方向绕行" if not World.blocked_cells.is_empty() else "地图边界 · 请换方向"
	elif World.encounter_id!="": app.refs.world_status.text = ("自动战斗 · "+World.tactical.status if World.patrol else "手动移动 · 自动开火")+" · 敌方 %d%%"%(100*State.enemy_hp/State.enemy_max)
	elif State.expedition.active(): app.refs.world_status.text = "自动战斗待敌 · 拖动摇杆探索" if World.patrol else "手动移动 · 拖动摇杆探索"
	else: app.refs.world_status.text = "正在搜索目标" if World.patrol else "移动中" if World.actual_velocity.length()>1 else "拖动空白处移动"
	app.refs.follow.visible = not app.refs.map.following
	app.refs.active_name.text = "%s  Lv.%02d"%[State.PILOTS[State.selected].name,State.levels[State.selected]]
	app.refs.hud_armor.text = "装甲 %d%%    护盾 %.0f"%[State.hp,State.defense.total_shield()]
	if State.defense.max_guard>0:
		app.refs.hud_armor.text = "装甲 %d%% · 护盾%.0f · %s" % [State.hp,State.defense.total_shield(),"破防" if State.defense.guard_break>0 else "格挡%.0f" % State.defense.guard]
	app.refs.hud_armor.add_theme_font_size_override("font_size",17 if State.defense.max_guard>0 else 19)
	app.refs.hud_armor.add_theme_color_override("font_color",Color("ff7b82") if State.hp<=30 else MINT)
	app.refs.hud_hp_bar.value = State.hp
	app.refs.heat.text = "热量 %.0f%%"%State.rig.heat+(" · 过热降频" if State.rig.overheated else " · 控热停火" if State.rig.cooling_hold else "")
	app.refs.hud_heat_bar.value = State.rig.heat
	app.refs.hud_exploration.visible = State.expedition.active()
	app.refs.hud_carrier.visible = State.expedition.active()
	if State.expedition.active():
		app.refs.hud_carrier.text = "战舰 · 舰能 %.0f\n%s"%[State.carrier.ops.data().energy,State.carrier.OPS.DOCTRINES[State.carrier.doctrine]]
	if State.expedition.active(): app.refs.hud_exploration.text = "探索 %d%%  ›" % State.expedition.explored_percent()
	var interaction: Dictionary = State.expedition.nearest_interaction(World)
	app.refs.hud_interact.visible = not interaction.is_empty()
	if not interaction.is_empty(): app.refs.hud_interact.text = "挑战首领" if interaction.kind=="boss_site" else interaction.name+" ›"
	for kind in ["cannon","repair"]:
		var control: Button = app.refs["support_"+kind]
		control.visible = State.expedition.active()
		if not State.expedition.active(): continue
		var support: Dictionary = State.expedition.run.support
		var reason := State.carrier.blocked(World,kind)
		control.disabled = reason!=""
		control.tooltip_text = reason if reason!="" else "锁定当前目标，1.2秒后范围炮击" if kind=="cannon" else "恢复装甲并排出热量"
		var status := "就绪" if reason=="" else "落弹中" if not support.pending.is_empty() else "%.0fs"%ceilf(float(support.cooldown)) if support.cooldown>0 else "已用尽" if support[kind]<=0 else "无需维修" if kind=="repair" and State.hp>=100 and State.rig.heat<=0 else "无目标"
		control.text = ("舰炮" if kind=="cannon" else "维修")+" ×%d\n" % support[kind]+status
	if is_instance_valid(app.refs.get("hud_target")):
		app.refs.hud_target.visible = World.boss.active
		app.refs.hud_target.position.x = 232 if State.expedition.active() else 24
		app.refs.hud_target.text = "目标 · "+{"auto":"自动","tracks":"履带","cannon":"肩炮","core":"核心"}.get(World.boss.selected,"自动")

func refresh_skill() -> void:
	if not is_instance_valid(app.refs.get("ultimate")): return
	app.refs.ultimate.text = "%s\n%d%%"%[State.PILOTS[State.selected].skill,State.energy]
	app.refs.hud_energy.value = State.energy

func show_tools() -> void:
	var m: Control = app.modal("战场工具","按需查看，战斗会继续进行",800)
	var titles: Array = ["机体与战区状态","自动战术","隐藏雷达" if app.battle_radar else "显示雷达","定位机甲","操作说明","声音 · 关闭" if State.sound_enabled else "声音 · 开启"]
	var callbacks: Array[Callable] = [show_status,app.show_tactics,func():
		app.battle_radar = not app.battle_radar
		if is_instance_valid(app.refs.get("map")): app.refs.map.radar_visible = app.battle_radar
		app.close_modal(),func():
		if is_instance_valid(app.refs.get("map")): app.refs.map.recenter()
		app.close_modal(),app.show_help,func(): app.toggle_sound(); show_tools()]
	for i in range(titles.size()): action(m,titles[i],Rect2(30,148+i*94,588,72),callbacks[i])

func show_status() -> void:
	var m: Control = app.modal("机体与战区状态","装甲、热量与当前构筑",850)
	var build: Dictionary = State.combat_configuration()
	var lines := PackedStringArray([State.PILOTS[State.selected].name+" / "+State.mechs.name_of(State.selected_mech),"装甲 %.0f%% · 护盾 %.0f"%[State.hp,State.defense.total_shield()],"热量 %.0f%% · 散热 %.0f/秒"%[State.rig.heat,build.cooling],"重量 %.0f/%.0f · 供能 %.0f/%.0f"%[build.weight,build.capacity,build.power,build.supply],"移速 %.0f · 基础 %.0f · 攻击 %d"%[World.move_speed(),build.base_speed,State.total_attack()],app.refs.world_coords.text,"当前战术："+World.tactical.status,"机师状态："+State.pilot_runtime.status(State.selected)])
	var info := text(m,"\n\n".join(lines),Rect2(30,154,588,560),22)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action(m,"返回战场工具",Rect2(30,748,588,64),show_tools)

func show_boss_targets() -> void:
	if not World.boss.active: return
	var m: Control = app.modal("首领部位","选择集火部位，也可交给自动战术",640)
	var keys := ["auto","tracks","cannon","core"]
	var titles := ["自动选择","履带 · 限制转向","肩炮 · 压低火力","核心 · 集中输出"]
	for i in range(4):
		var target: String = keys[i]
		var selected: bool = World.boss.selected==target
		var b := action(m,("✓  " if selected else "")+titles[i],Rect2(30,148+i*104,588,80),func():
			World.boss.selected = target; State.save_game(); app.close_modal())
		b.disabled = target in ["tracks","cannon"] and float(World.boss.parts[target])<=0
