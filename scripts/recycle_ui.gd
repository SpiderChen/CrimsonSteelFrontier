extends RefCounted
## Batch recycling requires an explicit selection and a separate confirmation.
var app: Node
var selected: Dictionary = {}
var rows: Dictionary = {}
var statuses: Dictionary = {}
var refs: Dictionary = {}
var preview: bool = false

func _init(owner: Node) -> void: app = owner

func matches(part: Dictionary) -> bool:
	return State.parts.matches(part,app.warehouse_slot,app.mechanism_filter,app.locked_only)

func protection(part: Dictionary) -> String:
	var owner: int = State.parts.owner(part.id)
	if owner>=0: return State.mechs.name_of(owner)+"已装备"
	if State.parts.is_locked(part): return "已锁定"
	if State.parts.protected(part.id): return "配装预设引用"
	if int(State.parts.reforge.get("id",0))==int(part.id): return "待选重铸结果"
	return ""

func candidates() -> Array:
	return State.parts.recycle_candidates(app.warehouse_slot,app.mechanism_filter,app.locked_only)

func chosen() -> Array:
	var result: Array = []
	for part in candidates():
		if selected.has(part.id): result.append(part)
	return result

func open() -> void:
	selected.clear()
	show_list()

func show_list() -> void:
	if not World.docked: app.request_base(); return
	preview = false; rows.clear(); statuses.clear()
	var m: Control = app.modal("批量分解 · 勾选部件","仅显示可分解部件 · 已装备、锁定及其他受保护部件自动隐藏",1040)
	refs.all = app.button(m,"全选当前可分解项",Rect2(24,140,390,52),func():
		for part in candidates(): selected[part.id] = true
		refresh())
	app.button(m,"清空选择",Rect2(426,140,198,52),func(): selected.clear(); refresh())
	app.label(m,"当前筛选 / "+("全部部位" if app.warehouse_slot<0 else "武器" if app.warehouse_slot==0 else State.PARTS.SLOTS[app.warehouse_slot]),Rect2(30,204,588,28),18,app.MUTED)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24,244); scroll.size = Vector2(600,504)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.follow_focus = true
	m.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8); scroll.add_child(list)
	for part in candidates():
		var row := Control.new(); row.custom_minimum_size = Vector2(572,120); list.add_child(row)
		app.box(row,Rect2(0,0,572,120),Color("182131"),Color("303c51"),8)
		var checkbox := CheckBox.new(); checkbox.size = Vector2(572,120)
		checkbox.disabled = not State.parts.recyclable(part)
		checkbox.set_pressed_no_signal(selected.has(part.id) and not checkbox.disabled)
		checkbox.tooltip_text = protection(part)
		checkbox.toggled.connect(func(value: bool):
			if value and State.parts.recyclable(part) and matches(part): selected[part.id] = true
			else: selected.erase(part.id)
			refresh())
		row.add_child(checkbox); rows[part.id] = checkbox
		app.label(row,State.parts.name_of(part)+" · Lv.%d" % part.get("level",1),Rect2(52,10,406,30),21,State.PARTS.COLORS[part.quality])
		app.label(row,State.PARTS.QUALITIES[part.quality],Rect2(468,10,88,30),17,State.PARTS.COLORS[part.quality],HORIZONTAL_ALIGNMENT_RIGHT)
		var reason := protection(part)
		app.part_icon(row,part.blueprint,Rect2(52,48,48,58))
		statuses[part.id] = app.label(row,reason if reason!="" else "可分解 · 合金芯 +%d" % (6*(int(part.quality)+1)),Rect2(112,46,444,28),18,app.GOLD if reason!="" else app.MUTED)
		app.label(row,State.parts.affix_text(part),Rect2(112,82,444,28),16,app.MUTED).clip_text = true
	refs.empty = app.label(list,"当前筛选下没有可分解的部件。",Rect2(0,0,572,80),21,app.MUTED)
	refs.empty.custom_minimum_size = Vector2(572,80)
	refs.summary = app.label(m,"",Rect2(30,770,588,64),23,app.GOLD)
	refs.confirm = app.button(m,"预览分解",Rect2(24,864,600,62),show_preview,true)
	app.button(m,"返回仓库",Rect2(24,952,600,56),app.show_parts)
	refresh()

func refresh() -> void:
	if not is_instance_valid(refs.get("confirm")): return
	var eligible: Array = candidates()
	var ids: Array = eligible.map(func(part): return part.id)
	for id in selected.keys():
		if id not in ids: selected.erase(id)
	for id in rows:
		if not is_instance_valid(rows[id]): continue
		rows[id].get_parent().visible = id in ids
		rows[id].disabled = id not in ids
		rows[id].set_pressed_no_signal(selected.has(id) and id in ids)
		var part: Dictionary = State.parts.find_part(int(id))
		if not part.is_empty():
			var reason := protection(part)
			rows[id].tooltip_text = reason
			if is_instance_valid(statuses.get(id)):
				statuses[id].text = reason if reason!="" else "可分解 · 合金芯 +%d" % (6*(int(part.quality)+1))
				statuses[id].add_theme_color_override("font_color",app.GOLD if reason!="" else app.MUTED)
	var count := 0
	var reward := 0
	for part in eligible:
		if selected.has(part.id): count += 1; reward += 6*(int(part.quality)+1)
	refs.summary.text = "已选 %d 件 · 合金芯 +%d\n仅分解勾选部件，未选部件会保留。" % [count,reward]
	refs.confirm.text = ("确认分解 %d 件" if preview else "预览分解 %d 件") % count
	refs.confirm.disabled = count==0 or not World.docked
	if is_instance_valid(refs.get("all")): refs.all.disabled = eligible.is_empty()
	if is_instance_valid(refs.get("empty")): refs.empty.visible = eligible.is_empty()

func show_preview() -> void:
	refresh()
	var parts: Array = chosen()
	if parts.is_empty(): show_list(); return
	preview = true
	var m: Control = app.modal("确认批量分解","仅处理本次勾选的部件 · 确认后无法恢复",900)
	refs.summary = app.label(m,"",Rect2(30,145,588,76),23,app.GOLD)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(24,250); scroll.size = Vector2(600,350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; m.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(list)
	var research: Dictionary = {}
	for part in parts:
		var row := Control.new(); row.custom_minimum_size = Vector2(572,38); list.add_child(row)
		app.label(row,State.parts.name_of(part)+" / "+State.PARTS.QUALITIES[part.quality],Rect2(12,0,548,38),20,State.PARTS.COLORS[part.quality])
		var mechanism: String = part.get("mechanism","")
		if mechanism!="": research[mechanism] = int(research.get(mechanism,0))+int(part.quality)+1
	var lines := PackedStringArray()
	for key in research:
		var gain := mini(int(research[key]),maxi(0,State.PARTS.RESEARCH_TARGET-int(State.parts.research.get(key,0))))
		if gain>0: lines.append(State.PARTS.MECHANISMS[key].name+"研究 +%d" % gain)
	for line in lines:
		var row := Control.new(); row.custom_minimum_size = Vector2(572,38); list.add_child(row)
		app.label(row,line,Rect2(12,0,548,38),18,app.GOLD)
	app.label(m,"可提升 %d 项机制研究，明细见上方列表。" % lines.size() if not lines.is_empty() else "本次没有新增机制研究进度。",Rect2(30,614,588,58),17,app.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refs.confirm = app.button(m,"确认分解",Rect2(30,692,588,66),confirm,true)
	app.button(m,"返回选择",Rect2(30,800,588,56),show_list)
	refresh()

func confirm() -> void:
	if not preview or not is_instance_valid(refs.get("confirm")): return
	refresh()
	if refs.confirm.disabled: return
	var ids: Array = chosen().map(func(part): return part.id)
	State.recycle_batch(ids)
	selected.clear(); preview = false
	app.show_parts()
