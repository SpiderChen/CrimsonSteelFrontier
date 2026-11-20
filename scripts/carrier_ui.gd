extends RefCounted
var app: Node
var refs: Dictionary = {}
var bridge: Dictionary = {}
func _init(owner: Node) -> void: app = owner

func show_bridge() -> void:
	var m: Control = app.modal("绯红方舟 · 战舰指挥","定点警戒 / 舰能持续恢复 / 指令冷却独立于重型支援",1080)
	bridge.clear()
	var art := Control.new(); art.set_script(app.CARRIER)
	art.position = Vector2(38,124); art.size = Vector2(570,190); m.add_child(art)
	bridge.status = app.label(m,"",Rect2(30,308,588,64),21,app.GOLD)
	bridge.status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in range(3):
		var mode: String = ["assault","guard","silent"][i]
		bridge[mode] = app.button(m,State.carrier.OPS.DOCTRINES[mode],Rect2(30+i*198,388,188,54),func(): State.carrier.ops.set_doctrine(mode); refresh_bridge())
	var info: Label = app.label(m,"火力：每6秒攻击距战舰650内的敌军；防护：近舰补盾。\n战舰固定驻守；每次消耗6舰能，静默可储备舰能。",Rect2(30,452,588,68),18,app.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var descriptions := {
		"barrage":"40舰能 · 锁定附近落点，连续3轮范围轰击",
		"barrier":"30舰能 · 原地展开8秒护盾区，区内承伤降低35%",
		"rally":"45舰能 · 在战舰原地开启补给，靠近后安全时维修与排热"
	}
	for i in range(3):
		var kind: String = ["barrage","barrier","rally"][i]
		var b: Button = app.button(m,"",Rect2(30,536+i*106,588,94),func():
			if State.carrier.ops.command(World,kind): app.close_modal()
			else: app.toast(State.carrier.ops.blocked(World,kind)); refresh_bridge(),true)
		b.add_theme_font_size_override("font_size",21); bridge[kind] = b
		b.tooltip_text = descriptions[kind]
	bridge.follow = app.button(m,"恢复警戒",Rect2(30,866,184,58),func(): State.carrier.ops.follow(); app.close_modal())
	bridge.locate = app.button(m,"定位战舰",Rect2(228,866,184,58),func():
		app.close_modal()
		if is_instance_valid(app.refs.get("map")):
			app.refs.map.camera = State.carrier.ops.position(); app.refs.map.following = false)
	app.button(m,"模块改造",Rect2(426,866,192,58),show_upgrades).disabled = not World.docked
	bridge.summary = app.label(m,"",Rect2(30,936,588,58),18,app.MUTED)
	bridge.summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.button(m,"返回母舰" if World.docked else "返回战场",Rect2(30,1006,588,54),app.close_modal)
	refresh_bridge()

func refresh_bridge() -> void:
	if not is_instance_valid(bridge.get("status")): return
	var active: bool = State.expedition.active() and not World.docked
	var current: Dictionary = State.carrier.ops.data()
	bridge.status.text = "固定驻守 · 自动攻击舰体650范围内的敌军" if not active else "舰能 %.0f / 100 · 固定驻守\n%s · %s"%[current.energy,"驻留补给" if current.mode=="station" else "定点警戒","链路就绪" if current.clock<=0 else "链路冷却 %.0fs"%ceilf(current.clock)]
	for mode in State.carrier.OPS.DOCTRINES:
		bridge[mode].text = ("✓ " if State.carrier.doctrine==mode else "")+State.carrier.OPS.DOCTRINES[mode]
	for kind in State.carrier.OPS.COSTS:
		var reason: String = State.carrier.ops.blocked(World,kind)
		bridge[kind].disabled = reason!=""
		bridge[kind].text = State.carrier.OPS.TITLES[kind]+" · %d舰能\n"%State.carrier.OPS.COSTS[kind]+(reason if reason!="" else {"barrage":"三轮覆盖轰击 · 延迟落弹","barrier":"8秒定点护盾 · 区内减伤35%","rally":"战舰原地补给 · 脱战后靠近"}[kind])
	bridge.follow.disabled = not active or current.get("mode")=="escort"
	bridge.locate.disabled = not active
	var stats: Dictionary = current if active else State.expedition.report.get("carrier",{})
	bridge.summary.text = "护航贡献 · 射击%d轮 / 伤害%.0f\n屏障减伤%.0f / 驻舰补给维修%.0f"%[stats.get("shots",0),stats.get("damage",0),stats.get("prevented",0),stats.get("repaired",0)]

func show_upgrades() -> void:
	if not World.docked: app.request_base(); return
	var m: Control = app.modal("母舰改造","永久升级舰载模块 · 每趟副本重新装填支援",1040)
	refs.clear()
	for i in range(3):
		var module: String = State.carrier.MODULES[i]
		var y := 144+i*246
		app.box(m,Rect2(24,y,600,228),Color("10212c"),Color("304653"),10)
		refs[module+"_title"] = app.label(m,"",Rect2(42,y+14,560,38),27,app.GOLD)
		var desc: Label = app.label(m,"",Rect2(42,y+58,560,82),17,app.MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		refs[module+"_description"] = desc
		refs[module+"_button"] = app.button(m,"",Rect2(42,y+144,564,62),func():
			State.carrier.upgrade(module); refresh(),true)
	app.label(m,"重型支援按整趟计算次数；护航与指令使用可恢复舰能。\n战场顶部“战舰指挥”可切换护航、齐射、护盾与驻舰补给。",Rect2(30,898,588,64),18,Color("8cdec3"))
	app.button(m,"返回母舰",Rect2(30,974,588,48),app.close_modal)
	refresh()

func refresh() -> void:
	if not State.test_mode and World.docked and app.page==4 and app.overlay.get_child_count()==0 and not is_instance_valid(app.story_ui.stage):
		var report: Dictionary = State.expedition.report
		if int(report.get("id",0))>0 and int(report.id)!=State.carrier.report_seen: show_report()
	refresh_bridge()
	if not is_instance_valid(refs.get("cannon_title")): return
	for module in State.carrier.MODULES:
		var level: int = State.carrier.levels[module]
		var price: Dictionary = State.carrier.cost(module)
		refs[module+"_title"].text = State.carrier.TITLES[module]+" · Lv.%d / 5" % level
		refs[module+"_description"].text = State.carrier.description(module)
		refs[module+"_button"].text = "已完成全部改造" if level>=5 else "改造 · C%d / 合金 %d" % [price.credits,price.cores]
		refs[module+"_button"].disabled = not World.docked or State.recovery>0 or level>=5 or State.credits<int(price.credits) or State.cores<int(price.cores)

func show_report() -> void:
	var report: Dictionary = State.expedition.report
	if report.is_empty() or not World.docked: return
	var m: Control = app.modal("舰队归航","绯红方舟 / 本次行动与护航记录",960)
	app.photo(m,State.selected,Rect2(30,140,190,224))
	app.label(m,State.PILOTS[State.selected].name+" · 归航通讯",Rect2(244,146,374,40),25,State.PILOTS[State.selected].color)
	var response: String = "航路打通了。下次，还和我一起出发吧。" if report.outcome=="cleared" else "收获已送回母舰，先一起歇一会儿吧。" if report.outcome=="withdrawn" else "我回来了。机体修好后，我们再试一次。"
	var reply: Label = app.label(m,response,Rect2(244,204,368,128),23)
	reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var outcome: String = {"cleared":"航路威胁解除","withdrawn":"主动撤离 · 收获已带回","failed":"紧急回收 · 机体正在修复"}.get(report.outcome,"行动结束")
	app.label(m,outcome,Rect2(30,380,588,56),29,app.GOLD)
	var stats: Dictionary = report.get("carrier",{})
	var lines := "护航射击  %d 轮\n实际输出  %.0f\n护盾承伤减免  %.0f\n驻舰补给维修  %.0f\n补给站部署  %d 次"%[stats.get("shots",0),stats.get("damage",0),stats.get("prevented",0),stats.get("repaired",0),stats.get("deployments",0)]
	app.label(m,lines,Rect2(46,458,556,240),25)
	app.label(m,"本次结算赏金 C%d · 已发现%d处地点\n装备与样本已保留，舰能与支援会在下次出击装填。"%[report.bounty,report.discovered],Rect2(30,720,588,78),19,app.MUTED)
	app.button(m,"调整护航战术",Rect2(30,834,284,66),show_bridge)
	app.button(m,"回到母舰",Rect2(330,834,288,66),app.close_modal,true)
	State.carrier.report_seen = int(report.get("id",0)); State.save_game()

func show_exchange(region: int = -1, focus: int = -1) -> void:
	if not World.docked: app.request_base(); return
	if region<0:
		var m: Control = app.modal("副本物资兑换","区域样本来自副本节点、武器库与首领",900)
		for i in range(4):
			var data: Dictionary = State.expedition.DATA.REGIONS[i]
			var b: Button = app.button(m,data.name+"\n样本 %d" % State.expedition.samples[i],Rect2(30,146+i*156,588,132),func(): show_exchange(i))
			b.disabled = not State.expedition.unlocked(i)
		app.button(m,"返回母舰",Rect2(30,806,588,60),app.close_modal)
		return
	var data: Dictionary = State.expedition.DATA.REGIONS[region]
	if focus not in data.pool: focus = data.pool[0]
	var m: Control = app.modal(data.name+" · 兑换","持有区域样本 %d" % State.expedition.samples[region],690)
	app.label(m,"选择型号兑换稀有部件；首通后开放命名史诗。\n获得的部件直接入库，满仓时进入溢出仓。",Rect2(30,148,588,82),21,app.MUTED)
	app.button(m,"定向型号："+State.PARTS.BLUEPRINTS[focus].name+"  ›",Rect2(30,250,588,62),func(): show_exchange(region,data.pool[(data.pool.find(focus)+1)%data.pool.size()]))
	var rare: Button = app.button(m,"兑换稀有部件 · 样本 12",Rect2(30,342,588,66),func():
		if State.expedition.exchange(region,focus,false): show_exchange(region,focus),true)
	rare.disabled = not State.expedition.unlocked(region) or State.expedition.samples[region]<12
	var named: Button = app.button(m,"兑换 "+State.PARTS.BLUEPRINTS[data.blueprint].name+" · 样本 20",Rect2(30,436,588,66),func():
		if State.expedition.exchange(region,data.blueprint,true): show_exchange(region,focus))
	named.disabled = not State.expedition.blueprint_unlocked(data.blueprint) or State.expedition.samples[region]<20
	app.label(m,"命名史诗已解锁" if State.expedition.blueprint_unlocked(data.blueprint) else "击败这张地图的首领后解锁命名兑换",Rect2(30,526,588,40),19,app.GOLD)
	app.button(m,"返回物资兑换",Rect2(30,600,588,60),func(): show_exchange())
