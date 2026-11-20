extends RefCounted
## Story progression never changes combat multipliers or gates a core skill.
const TASKS = [
	[{"key":"nodes","goal":3,"name":"试飞记录","story":"绯夜把三次出击的热量曲线投上机库屏幕。她不再独自修改参数，而是把你的建议写进了下一次试飞清单。"},{"key":"vented","goal":120,"name":"越过红线","story":"曾经的事故让她习惯把极限留给自己。现在她会在逼近红线前报出温度，并等你确认返航路线。"},{"key":"bosses","goal":2,"name":"归航承诺","story":"第二次首领战结束后，绯夜在座舱里留下一张检查卡：每次起飞前检查武器，每次胜利后全员归航。"}],
	[{"key":"nodes","goal":3,"name":"观察日志","story":"鸦羽交给你一本手写日志。除了目标坐标，里面还记着每名维修员的轮班时间——她一直在照看整支队伍。"},{"key":"marked_damage","goal":1500,"name":"交叉视线","story":"她开始把标记交给你判断，而不再独自确认每个射击窗口。安静的无线电里多了一句：我相信你的视线。"},{"key":"bosses","goal":2,"name":"无需独行","story":"鸦羽摘下耳机，第一次主动加入维修区的晚餐。她说，撤离路线不必只有一个人的脚印。"}],
	[{"key":"nodes","goal":3,"name":"维修清单","story":"凛整理了三次行动的破损记录，悄悄为每位机师准备了备用接头。她终于答应给自己的机体也留一套。"},{"key":"support","goal":100,"name":"守护余量","story":"护盾挡下最后一轮炮火时，凛没有留下硬撑。她按约定撤回安全线，把后续交给了队友。"},{"key":"bosses","goal":2,"name":"一起回家","story":"凛把母舰灯光调成了极地基地的暖色。她说新的防线有一道门，留给所有归来的人。"}],
	[{"key":"nodes","goal":3,"name":"步法课","story":"雷娜把三次探索中的切入路线画在地板上。最后一条线绕回了队友身边：王牌的步法，也要留出接人的位置。"},{"key":"melee_damage","goal":4000,"name":"刀锋的距离","story":"训练场记录下最后一次挥斩。雷娜没有再追问最快的击破时间，而是请你指出哪一步让她离队太远。"},{"key":"bosses","goal":2,"name":"并肩破阵","story":"第二场首领战后，雷娜把教官徽章放进机库展示柜。今天不需要有人站在队伍前面授课，她想与所有人站在同一排。"}],
	[{"key":"nodes","goal":3,"name":"航迹笔记","story":"星澜将三次探索的航迹叠成一幅星图。她用另一种颜色标出返航路线，说这才是火控解算里最重要的线。"},{"key":"missile_damage","goal":5000,"name":"最后一枚导弹","story":"星澜为每一轮齐射重新校对落点。她曾习惯把弹仓打空才撤离，现在愿意留下一枚，掩护最后归队的人。"},{"key":"bosses","goal":2,"name":"共同坐标","story":"舰桥投影亮起新的航路。星澜把属于自己的坐标改成整支小队的呼号：再精密的制导，也需要有人回应归航。"}],
	[{"key":"nodes","goal":3,"name":"夜班记录","story":"伊芙检查了三处设施的反应炉接口。她把维修日志交给轮班工程师，第一次按时走进了甲板上的晨光。"},{"key":"vented","goal":180,"name":"回路余量","story":"热量曲线终于平稳下来。伊芙承认，她一直把休息当成浪费的能量。你替她在值班表上画出了一整段空白。"},{"key":"bosses","goal":2,"name":"曙光之后","story":"两次首领战的记录并排放在桌上，伊芙却先关掉了投影。她想看看真正的日出，和那些不必继续值班的人一起。"}]
]
const TALKS = [
	["我二十六岁那年离开试飞基地。这里的零件没那么整齐，但每次起飞，我都知道有人等着我回来。","别把红色警报当成勋章。测试过极限之后，才知道什么时候该相信队友。","等这片边境安静下来，我想带你试飞一台没有武器的机体。"],
	["二十八岁，前侦察队狙击手。习惯先看撤离通道。你不用放低声音，我只是喜欢听清每个人的话。","那本观察日志？也写了你。你总在最后一个人归队后才离开甲板。","下次停靠港口，我想挑个靠窗的位置。没有任务简报，只有一顿慢慢吃完的晚饭。"],
	["我二十五岁，在极地防线做过战场工程师。修好装甲需要工具，让人安心有时候只需要一句欢迎回来。","我在学着把维修工作分给别人。今天轮到我去休息区，你愿意一起喝杯热饮吗？","母舰也可以叫家，对吗？我想给这里留一盏夜灯。" ],
	["我二十七岁，从突击教官转来这里。格斗第一课不是挥刀，是看清自己能从哪里回来。","他们说我的动作没有多余一步。其实我也会犹豫，只是以前没人问我为什么停下。","等航路安静下来，我们去海边走走吧。不带秒表，也不用争谁先到。"],
	["二十九岁，舰载火控出身。星图上那些转弯不是装饰，每一条都关系到谁能安全通过。","我小时候分不清星座，就给它们编了自己的名字。现在想再加一个，叫大家一起回来的方向。","下次夜航，来舰桥陪我看星星吧。这回不计算航迹，只看看它们。"],
	["我三十岁，负责过远航船的反应炉。设备必须留有余量，人也一样——这句话我还在练习。","你给我留的那份早餐，我按时吃完了。今天的能量账本上，多了一件不用计算回报的事。","我想给休息区装一扇看得到日出的窗。你来选位置，第一杯咖啡我来准备。"]
]
var trust: Array = []
var metrics: Array = []
var claimed: Array = []
var heard: Array = []
func _init() -> void: reset()
func reset() -> void:
	trust = []; metrics = []; claimed = []; heard = []
	for _pilot in TASKS:
		trust.append(0); metrics.append({}); claimed.append([]); heard.append([])
func record(pilot: int, key: String, amount: float) -> void:
	if pilot<0 or pilot>=TASKS.size() or amount<=0 or not is_finite(amount): return
	metrics[pilot][key] = minf(1000000000,float(metrics[pilot].get(key,0))+amount)
	if key in ["nodes","bosses"]: trust[pilot] = mini(100,int(trust[pilot])+(4 if key=="bosses" else 1))
func ready(pilot: int, chapter: int) -> bool:
	return pilot>=0 and pilot<TASKS.size() and chapter>=0 and chapter<TASKS[pilot].size() and not chapter in claimed[pilot] and (chapter==0 or chapter-1 in claimed[pilot]) and float(metrics[pilot].get(TASKS[pilot][chapter].key,0))>=TASKS[pilot][chapter].goal
func claim(pilot: int, chapter: int) -> bool:
	if not ready(pilot,chapter): return false
	claimed[pilot].append(chapter); trust[pilot] = mini(100,int(trust[pilot])+5)
	return true
func talk(pilot: int, chapter: int) -> String:
	if pilot<0 or pilot>=TASKS.size() or chapter<0 or chapter>=TALKS[pilot].size() or int(trust[pilot])<[0,10,25][chapter]: return ""
	if not chapter in heard[pilot]: heard[pilot].append(chapter); trust[pilot] = mini(100,int(trust[pilot])+2)
	return TALKS[pilot][chapter]
func export_save() -> Dictionary: return {"trust":trust.duplicate(),"metrics":metrics.duplicate(true),"claimed":claimed.duplicate(true),"heard":heard.duplicate(true)}
func import_save(data: Variant) -> void:
	reset()
	if not data is Dictionary: return
	for pilot in range(TASKS.size()):
		if data.get("trust") is Array and pilot<data.trust.size():
			var value: Variant = data.trust[pilot]
			if (value is float or value is int) and is_finite(float(value)): trust[pilot] = clampi(int(value),0,100)
		if data.get("metrics") is Array and pilot<data.metrics.size() and data.metrics[pilot] is Dictionary:
			for key in ["nodes","bosses","vented","marked_damage","support","melee_damage","missile_damage"]:
				var value: Variant = data.metrics[pilot].get(key,0)
				if (value is float or value is int) and is_finite(float(value)) and float(value)>0: metrics[pilot][key] = clampf(float(value),0,1000000000)
		for key in ["claimed","heard"]:
			if not data.get(key) is Array or pilot>=data[key].size() or not data[key][pilot] is Array: continue
			for value in data[key][pilot]:
				if (value is int or value is float) and value==int(value) and value>=0 and value<=2 and not int(value) in get(key)[pilot]: get(key)[pilot].append(int(value))
