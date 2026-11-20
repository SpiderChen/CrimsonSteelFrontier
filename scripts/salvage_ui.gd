extends RefCounted
const GOLD := Color("e9c78e")
const MUTED := Color("8894a8")
const WHITE := Color("f2f1f3")
var app: Node
var certification_region: int = 0
var refs: Dictionary:
	get: return app.refs

func _init(owner: Node) -> void: app = owner
func modal(title: String, subtitle: String, height: float) -> Control: return app.modal(title,subtitle,height)
func label(parent: Node, text: String, rect: Rect2, size: int = 22, color: Color = WHITE) -> Label: return app.label(parent,text,rect,size,color)
func button(parent: Node, text: String, rect: Rect2, action: Callable, primary: bool = false) -> Button: return app.button(parent,text,rect,action,primary)
func box(parent: Node, rect: Rect2, color: Color) -> Control: return app.box(parent,rect,color)
func close_modal() -> void: app.close_modal()

func refresh_all() -> void:
	refresh_salvage(); refresh_certification()

func show_idle() -> void:
	if not World.docked: app.request_base(); return
	var m := modal("前线回收与挂机","前24小时全额 / 24—72小时半额 / 超出停止累计",1040)
	refs.salvage_source = label(m,"",Rect2(30,140,588,70),24,GOLD)
	refs.salvage_credits = label(m,"",Rect2(30,228,588,58),39)
	refs.salvage_time = label(m,"",Rect2(30,300,588,44),20,MUTED)
	refs.salvage_resources = label(m,"",Rect2(30,364,588,80),22,Color("8cdec3"))
	refs.salvage_explanation = label(m,"",Rect2(30,470,588,126),20,MUTED)
	refs.salvage_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(m,"收益分账明细",Rect2(30,650,286,56),show_salvage_accounts)
	button(m,"认证回收方案",Rect2(332,650,286,56),show_certificates,true)
	refs.salvage_recycle = button(m,"",Rect2(30,738,588,52),func(): State.salvage.auto_recycle=not State.salvage.auto_recycle; State.save_game(); refresh_salvage())
	refs.salvage_claim = button(m,"领取全部回收",Rect2(30,826,588,72),func(): State.claim_idle(); show_idle(),true)
	button(m,"返回母舰",Rect2(30,942,588,62),close_modal)
	refresh_salvage()

func refresh_salvage() -> void:
	if not is_instance_valid(refs.get("salvage_source")): return
	var record: Dictionary = State.salvage.active_record()
	var due: Dictionary = State.salvage.pending()
	refs.salvage_source.text = "当前回收："+record.name+"\n"+(State.expedition.DATA.REGIONS[int(record.region)].name if int(record.region)>=0 else "基础方案 / 信用点与合金")
	refs.salvage_credits.text = "C  +%s" % app.number(due.credits)
	refs.salvage_time.text = "累计 %.2f小时 · 有效收益 %.2f小时" % [State.salvage.age/3600.0,State.SALVAGE.effective(State.salvage.age)/3600.0]
	refs.salvage_resources.text = "合金 +%d · 部件 %d · 样本 %d\n研究资料 +%d · 未满一份的进度会保留" % [due.cores,due.parts,due.samples,due.research]
	refs.salvage_explanation.text = "认证快照指导回收队；更换当前机甲装备，不会改变正在使用的回收方案。\n切换方案先结算旧方案，在线探索期间也继续累计。"
	refs.salvage_recycle.text = "精良自动分解："+("开启" if State.salvage.auto_recycle else "关闭")+" / 稀有以上始终保留"
	refs.salvage_recycle.add_theme_font_size_override("font_size",21)
	refs.salvage_claim.disabled = due.credits+due.cores+due.parts+due.research+due.samples<=0

func show_salvage_accounts(history: bool = false) -> void:
	var m := modal("回收收益分账","各方案按各自认证效率记账 / 共享24—72小时额度",960)
	button(m,"当前未领分账",Rect2(30,138,286,46),func(): show_salvage_accounts(false),not history)
	button(m,"上次结算记录",Rect2(332,138,286,46),func(): show_salvage_accounts(true),history)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24,208); scroll.size = Vector2(600,602)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; m.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",12); scroll.add_child(list)
	var sources: Array = State.salvage.last_claim.get("sources",[]) if history else State.salvage.rows
	for row in sources:
		var card := Control.new(); card.custom_minimum_size = Vector2(572,155); list.add_child(card)
		box(card,Rect2(0,0,572,155),Color("172434"))
		label(card,row.name,Rect2(12,8,548,32),22,GOLD)
		label(card,"原时间 %.2fh / 有效 %.2fh\n信用点 %.1f · 合金 %.2f\n部件进度 %.2f · 研究 %.2f · 样本 %.2f" % [row.raw_seconds/3600.0,row.effective_seconds/3600.0,row.credits,row.cores,row.parts,row.research,row.samples],Rect2(12,48,548,96),19,MUTED)
	if sources.is_empty():
		var empty := label(list,"暂无未领取收益；小数进度会在这里保留。",Rect2(0,0,572,90),21,MUTED); empty.custom_minimum_size = Vector2(572,90)
	button(m,"返回回收仓",Rect2(30,866,588,56),show_idle)

func show_certificates() -> void:
	if not World.docked: app.request_base(); return
	var m := modal("回收认证档案","使用认证快照回收已控制区域 / 不影响当前出战配装",1040)
	for i in range(4):
		button(m,State.expedition.DATA.REGIONS[i].name,Rect2(30+(i%2)*302,140+int(i/2.0)*58,286,48),func(): certification_region=i; show_certificates(),i==certification_region)
	var controlled: bool = State.expedition.clears[certification_region]>0
	var desc := label(m,"连续三次真实自动清剿，记录耗时与装甲稳定性。\n"+("使用开始认证时的装备、机师与战术快照。" if controlled else "先击败该区域首领，才能认证对应回收点。"),Rect2(30,270,588,66),20,MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var start := button(m,"以当前配装进行认证",Rect2(30,358,588,64),func():
		if State.start_certification(certification_region): show_certification_progress(),true)
	start.disabled = not controlled or (State.certification_job!=null and not State.certification_job.done)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(24,454); scroll.size = Vector2(600,356)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; m.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",10); scroll.add_child(list)
	refs.certificate_list = list; refs.certificate_count = State.salvage.certificates.size()
	for record in State.salvage.certificates:
		if int(record.region)!=certification_region: continue
		var card := Control.new(); card.custom_minimum_size = Vector2(572,120); list.add_child(card)
		button(card,"",Rect2(0,0,572,120),func(): show_certificate_detail(record.id),record.id==State.salvage.active_id)
		label(card,record.name+(" · 使用中" if record.id==State.salvage.active_id else ""),Rect2(12,8,548,30),22,GOLD)
		label(card,"平均 %.1f秒 / 最低装甲 %.0f%%\n每小时 C%.0f / 部件%.2f / 研究%.2f" % [record.seconds,record.minimum_hp,record.rates.credits,record.rates.parts,record.rates.research],Rect2(12,47,548,62),18,MUTED)
	if list.get_child_count()==0:
		var empty := label(list,"暂无认证档案，完成认证后可在此启用。",Rect2(0,0,572,90),21,MUTED); empty.custom_minimum_size = Vector2(572,90)
	button(m,"使用基础回收队（无装备与研究产出）",Rect2(30,846,588,50),func(): State.activate_salvage("base"); show_idle())
	button(m,"返回回收仓",Rect2(30,942,588,62),show_idle)

func show_certification_progress() -> void:
	if State.certification_job==null: show_certificates(); return
	var m := modal("自动清剿认证","三次独立自动清剿 / 不耗实际装甲，不发放试验战利品",880)
	refs.certification_status = label(m,"",Rect2(30,145,588,110),25,GOLD)
	var snapshot: Dictionary = State.certification_job.snapshot
	var equipment = State.PARTS.new(); equipment.import_save(snapshot.parts)
	var lines := PackedStringArray()
	for slot in State.PARTS.DISPLAY_SLOTS:
		lines.append(State.PARTS.SLOTS[slot]+" / "+equipment.name_of(equipment.equipped(int(snapshot.get("mech",snapshot.pilot)),slot)))
	label(m,"\n".join(lines),Rect2(30,285,588,212),21,MUTED)
	refs.certification_metrics = label(m,"",Rect2(30,520,588,128),20,Color("8cdec3"))
	refs.certification_enable = button(m,"启用本次认证方案",Rect2(30,686,588,66),func():
		if State.activate_salvage(State.certification_result_id): show_idle(),true)
	button(m,"结束认证并返回",Rect2(30,778,286,56),func(): State.cancel_certification(); show_certificates())
	button(m,"返回档案 · 后台继续",Rect2(332,778,286,56),show_certificates)
	refresh_certification()

func refresh_certification() -> void:
	if is_instance_valid(refs.get("certificate_list")) and refs.get("certificate_count",0)!=State.salvage.certificates.size(): show_certificates()
	if not is_instance_valid(refs.get("certification_status")) or State.certification_job==null: return
	var job = State.certification_job
	refs.certification_status.text = State.expedition.DATA.REGIONS[int(job.region)].name+" / "+str(job.snapshot.pilot_name)+"\n"+(job.reason if job.done else "清剿 %d / 3 · 实战计时 %.1f秒" % [job.trial+1,job.total_elapsed])
	refs.certification_metrics.text = "认证使用真实的移动、命中、防御与热量规则。\n完成后按耗时与生存稳定性确定回收效率。"
	if job.done and job.success:
		var result: Dictionary = job.result()
		refs.certification_metrics.text = "%s级稳定性 · 平均 %.2f秒 · 最低装甲 %.1f%%\n每小时 C%.0f / 合金%.1f\n部件%.2f / 研究资料%.2f / 样本%.2f" % [result.grade,result.seconds,result.minimum_hp,result.rates.credits,result.rates.cores,result.rates.parts,result.rates.research,result.rates.samples]
	refs.certification_enable.disabled = not job.done or not job.success or State.certification_result_id.is_empty()

func show_certificate_detail(id: String) -> void:
	var record: Dictionary = {}
	for candidate in State.salvage.certificates:
		if candidate.id==id: record = candidate
	if record.is_empty(): show_certificates(); return
	var m := modal(record.name,"已保存的配装与战术快照 / 当前装备变化不会改变此档案",960)
	var equipment = State.PARTS.new(); equipment.import_save(record.snapshot.parts)
	var lines := PackedStringArray()
	for slot in State.PARTS.DISPLAY_SLOTS: lines.append(State.PARTS.SLOTS[slot]+" / "+equipment.name_of(equipment.equipped(int(record.snapshot.get("mech",record.snapshot.pilot)),slot)))
	label(m,"\n".join(lines),Rect2(30,148,588,222),22,MUTED)
	var policy: Dictionary = State.TACTICS.sanitize(record.snapshot.tactics)
	label(m,"目标：%s / 距离：%s\n热量：%s / 技能：%s" % [State.TACTICS.LABELS[policy.target],State.TACTICS.LABELS[policy.distance],State.TACTICS.LABELS[policy.heat],State.TACTICS.LABELS[policy.skill]],Rect2(30,394,588,68),20,GOLD)
	label(m,"平均 %.2f秒 / 最低装甲 %.1f%% / %s级稳定性\n每小时 C%.0f · 合金%.1f · 部件%.2f\n研究资料%.2f · 区域样本%.2f" % [record.seconds,record.minimum_hp,record.grade,record.rates.credits,record.rates.cores,record.rates.parts,record.rates.research,record.rates.samples],Rect2(30,500,588,116),21,Color("8cdec3"))
	button(m,"启用该回收方案",Rect2(30,660,588,66),func(): State.activate_salvage(id); show_idle(),true)
	var remove := button(m,"删除档案 · 已累计收益保留",Rect2(30,754,588,56),func(): State.delete_certificate(id); show_certificates())
	remove.disabled = id==State.salvage.active_id
	button(m,"返回认证档案",Rect2(30,866,588,56),show_certificates)
