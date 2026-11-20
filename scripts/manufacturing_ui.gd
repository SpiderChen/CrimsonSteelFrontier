extends RefCounted
## The workshop owns blueprint selection, purchase confirmation and production receipts.
var app: Node
var slot_filter: int = -1
var blueprint: int = -1
var refs: Dictionary = {}

func _init(owner: Node) -> void:
	app = owner

func unlocked(index: int) -> bool:
	return index in State.PARTS.BASIC_BLUEPRINTS or State.expedition.blueprint_unlocked(index)

func show_catalog() -> void:
	if not World.docked: app.request_base(); return
	var m: Control = app.modal("制造工坊","选择蓝图并确认制造 · 成品自动收入部件仓库",1040)
	var tabs: Array = [-1]+app.PART_GROUP_SLOTS
	for i in range(tabs.size()):
		var slot: int = tabs[i]
		var title: String = "全部" if slot<0 else "武器" if slot==0 else State.PARTS.SLOTS[slot]
		app.button(m,title,Rect2(24+(i%3)*202,138+int(i/3.0)*62,194,52),func(): slot_filter=slot; show_catalog(),slot==slot_filter)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24,278); scroll.size = Vector2(600,590)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	m.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	var designs: Array = State.PARTS.MELEE_BLUEPRINTS+State.PARTS.HAND_SHIELDS
	for index in range(State.PARTS.BLUEPRINTS.size()):
		if index not in designs: designs.append(index)
	for index in designs:
		var info: Dictionary = State.PARTS.BLUEPRINTS[index]
		if slot_filter>=0 and int(info.slot)!=slot_filter: continue
		var row := Control.new(); row.custom_minimum_size = Vector2(572,122); list.add_child(row)
		app.button(row,"",Rect2(0,0,572,122),func(): show_design(index))
		app.label(row,info.name,Rect2(16,8,414,34),23)
		app.label(row,"可制造" if unlocked(index) else "未解锁",Rect2(436,8,120,34),18,app.GOLD if unlocked(index) else app.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
		app.part_icon(row,index,Rect2(16,48,58,60))
		app.label(row,"特性 / "+info.title,Rect2(88,47,468,28),18,app.GOLD)
		app.label(row,("近战基础蓝图" if index in State.PARTS.MELEE_BLUEPRINTS else "手持盾牌蓝图" if index in State.PARTS.HAND_SHIELDS else "基础蓝图")+" · 品质与词条随机" if index in State.PARTS.BASIC_BLUEPRINTS else "首通蓝图 · "+State.expedition.DATA.REGIONS[State.PARTS.NAMED_BLUEPRINTS.find(index)].name,Rect2(88,82,468,28),17,app.MUTED)
	app.label(m,"每件 C450 / 合金15 · 仓库 %d/%d" % [State.parts.inventory.size(),State.PARTS.LIMIT],Rect2(30,886,588,32),20,app.GOLD)
	app.button(m,"返回母舰",Rect2(24,950,600,62),func(): app.close_modal(); app.show_page(4))

func show_design(index: int) -> void:
	if not World.docked: app.request_base(); return
	if index<0 or index>=State.PARTS.BLUEPRINTS.size(): show_catalog(); return
	blueprint = index
	var info: Dictionary = State.PARTS.BLUEPRINTS[index]
	var m: Control = app.modal(info.name,"制造确认 / "+("武器 · 左右手通用" if info.slot==0 else State.PARTS.SLOTS[info.slot]),900)
	app.label(m,"型号特性 / "+info.title,Rect2(30,145,430,40),25,app.GOLD)
	app.part_icon(m,index,Rect2(470,142,128,46))
	var description: Label = app.label(m,info.desc,Rect2(30,205,588,150),21)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.label(m,"品质与词条在制造时随机生成；选择蓝图不消耗材料。",Rect2(30,378,588,66),20,app.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.label(m,"制造费用：信用点 450 / 合金芯 15",Rect2(30,476,588,42),24,app.GOLD)
	refs.resources = app.label(m,"",Rect2(30,536,588,40),21,app.MUTED)
	refs.status = app.label(m,"",Rect2(30,594,588,58),20,app.GOLD)
	refs.status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refs.confirm = app.button(m,"确认制造一件",Rect2(30,692,588,66),craft,true)
	app.button(m,"返回蓝图列表",Rect2(30,800,588,56),show_catalog)
	refresh()

func refresh() -> void:
	if not is_instance_valid(refs.get("confirm")): return
	refs.resources.text = "持有 C%d / 合金%d · 仓库 %d/%d" % [State.credits,State.cores,State.parts.inventory.size(),State.PARTS.LIMIT]
	var reason := ""
	if not World.docked: reason = "回到母舰后可制造。"
	elif not unlocked(blueprint): reason = "解锁条件：击败"+State.expedition.DATA.REGIONS[State.PARTS.NAMED_BLUEPRINTS.find(blueprint)].name+"首领。"
	elif State.parts.inventory.size()>=State.PARTS.LIMIT: reason = "部件仓库已满，请先整理仓库。"
	elif State.credits<450 or State.cores<15: reason = "信用点或合金芯不足。"
	refs.confirm.disabled = reason!=""
	refs.status.text = reason if reason!="" else "制造一件成品，不会自动装配或替换当前装备。"

func craft() -> void:
	refresh()
	if not is_instance_valid(refs.get("confirm")) or refs.confirm.disabled: return
	var part: Dictionary = State.craft_part(blueprint)
	if part.is_empty(): refresh(); return
	show_result(part)

func show_result(part: Dictionary) -> void:
	var m: Control = app.modal("制造完成","成品已收入部件仓库",820)
	app.label(m,State.parts.name_of(part),Rect2(30,145,588,48),30,State.PARTS.COLORS[part.quality])
	app.label(m,State.PARTS.QUALITIES[part.quality]+" · Lv.%d" % part.level,Rect2(30,208,588,38),22,State.PARTS.COLORS[part.quality])
	var info: Dictionary = State.PARTS.BLUEPRINTS[part.blueprint]
	app.part_icon(m,part.blueprint,Rect2(448,208,150,160))
	var feature: Label = app.label(m,info.title+"\n"+State.parts.mechanism_text(part),Rect2(30,286,400,136),21,app.GOLD)
	feature.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var affixes: Label = app.label(m,State.parts.affix_text(part),Rect2(30,456,588,98),22,Color("8cdec3"))
	affixes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.label(m,"剩余 C%d / 合金%d · 仓库 %d/%d" % [State.credits,State.cores,State.parts.inventory.size(),State.PARTS.LIMIT],Rect2(30,594,588,42),20,app.MUTED)
	app.button(m,"返回制造工坊",Rect2(30,708,588,66),show_catalog,true)
