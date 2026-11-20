extends RefCounted
const GOLD := Color("e9c78e")
const MUTED := Color("8894a8")
var app: Node
func _init(owner: Node) -> void: app = owner

func open_active() -> void:
	app.portrait_index = State.selected
	app.show_page(2)

func greeting() -> String:
	if State.recovery>0:
		return ["别担心，我已经回来了。等机体修好，再陪你出发。","损伤记录已交给维修组。我没事，指挥官。","维修由我盯着。你也趁现在休息一下吧。","先复盘脚步，再重新出发。我还在这里。","弹道记录完整，下一轮会算得更仔细。","回路已经隔离。修好机体，也要照顾好自己。"][State.selected]
	if State.pilot_roster.trust[State.selected]>=25:
		return ["又在看我？那下一次出击，也要跟紧我哦。","给你留了旁边的位置。下一条航路，一起选吧。","欢迎回来。我想先听听你今天的打算。","今天的步法课结束了。一起去甲板透透气吧。","给你留了一张新星图。今晚一起看吗？","咖啡刚好。先陪我看一会儿日出吧。"][State.selected]
	return ["准备好了，指挥官。今天也让我打头阵吧。","火控已校准。选好航路，我就陪你出发。","补给和护盾都检查过了。放心把后背交给我。","刃口和步法都准备好了。把切入路线交给我。","导弹完成校准。下一个坐标，由你决定。","能量回路稳定。我们有足够的余量走下去。"][State.selected]
func text(parent: Node, value: String, y: float, height: float, color: Color = Color("f2f1f3"), font_size: int = 21) -> Label:
	var result: Label = app.label(parent,value,Rect2(30,y,588,height),font_size,color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func show_abilities(pilot: int) -> void:
	var m: Control = app.modal(State.PILOTS[pilot].name+" · 战术档案","主战机师技能生效 / 自动释放遵循所选战术",1020)
	var abilities: Dictionary = State.PILOT_RUNTIME.ABILITIES[pilot]
	text(m,"主动技能 · "+State.PILOTS[pilot].skill,146,46,GOLD,26)
	text(m,abilities.active,208,150)
	text(m,"战术被动",382,42,GOLD,26)
	text(m,abilities.passive+"\n"+["自动战斗：轻型机体游走压制，适配连射与近战。","自动战斗：到达射程后停步瞄准；危险区仍会躲避。","自动战斗：远程保持距离，技能提供护盾与持续修复。","自动战斗：搭配格斗武器贴近目标，120距离内自动挥斩。","自动战斗：保持导弹射程，齐射锁定重点目标。","自动战斗：保持安全射程，用能量循环维持持续输出。"][pilot],438,104)
	text(m,"探索特长",572,42,GOLD,26)
	text(m,abilities.perk,630,110)
	text(m,"所有机师均可自由搭配武器。信赖只解锁故事与纪念徽章。\n主动技能消耗100%同步能量；所有机师技能从加入时完整开放。",778,112,MUTED,19)
	app.button(m,"信赖与个人任务",Rect2(30,930,588,56),func(): show_relationship(pilot),true)

func show_relationship(pilot: int) -> void:
	var roster = State.pilot_roster
	var trust: int = roster.trust[pilot]
	var m: Control = app.modal(State.PILOTS[pilot].name+" · 机库交流","出击、个人任务与首次交流提升信赖 / 不影响战斗倍率",1060)
	text(m,"信赖 %d / 100  ·  %s" % [trust,"归航徽章已解锁" if trust>=25 else "信赖25解锁驾驶舱纪念徽章"],142,65,GOLD,23)
	for i in range(3):
		var task: Dictionary = roster.TASKS[pilot][i]
		var completed: bool = i in roster.claimed[pilot]
		var y := 235+i*151
		app.box(m,Rect2(22,y,604,136),Color("1d2c3b"))
		text(m,"%02d  %s" % [i+1,task.name],y+8,38,State.PILOTS[pilot].color,24)
		var names := {"nodes":"完成探索节点","vented":"主动排热","marked_damage":"标记额外伤害","support":"护盾吸收与装甲维修","bosses":"击败机制首领","melee_damage":"实际格斗伤害","missile_damage":"实际导弹伤害"}
		text(m,"%s  %.0f / %d" % [names[task.key],minf(task.goal,roster.metrics[pilot].get(task.key,0)),task.goal],y+53,34,MUTED,18)
		var ready: bool = roster.ready(pilot,i)
		var b: Button = app.button(m,"阅读" if completed else "领取" if ready else "进行中",Rect2(468,y+81,142,42),func():
			if completed: show_story(pilot,i)
			elif State.claim_pilot_task(pilot,i): show_story(pilot,i),ready)
		b.disabled = not State.unlocked[pilot] or (not completed and not ready)
	text(m,"任务奖励：信赖 +5、信用点 +200、研究资料 +1\n任务按顺序完成；训练场与认证演练不累计个人任务。",704,74,MUTED,18)
	for i in range(3):
		var need: int = [0,10,25][i]
		var b: Button = app.button(m,"交流 %d · %s" % [i+1,"可回看" if i in roster.heard[pilot] else "首次信赖 +2" if trust>=need else "需要信赖%d"%need],Rect2(30,805+i*64,588,54),func(): show_talk(pilot,i))
		b.disabled = not State.unlocked[pilot] or trust<need
	app.button(m,"返回战术档案",Rect2(30,1000,588,42),func(): show_abilities(pilot))

func show_story(pilot: int, chapter: int) -> void:
	if not chapter in State.pilot_roster.claimed[pilot]: return
	State.narrative.unlock("personal_%d_%d"%[pilot,chapter],false)
	app.story_ui.play("personal_%d_%d"%[pilot,chapter],func(): show_relationship(pilot))

func show_talk(pilot: int, chapter: int) -> void:
	var dialogue: String = State.talk_pilot(pilot,chapter)
	if dialogue=="": return
	app.story_ui.play("talk_%d_%d"%[pilot,chapter],func(): show_relationship(pilot))
