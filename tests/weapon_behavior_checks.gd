extends RefCounted
const RIG = preload("res://scripts/rig_runtime.gd")
var fired: Array = []
func record(profile: Dictionary) -> void: fired.append(profile.mode)
func weapon(mode: String, slot: int = 0) -> Dictionary:
	return {"mode":mode,"slot":slot,"range":400.0,"interval":0.2,"heat":3.0,"attack":10.0,"mechanism":""}
func run(check: Callable, main: Node) -> void:
	var config := {"valid":true,"cooling":20.0,"moving":true}
	var rig = RIG.new()
	for _step in range(10): rig.advance(0.05,[weapon("rail"),{}],100,"a",config,record)
	check.call(fired.is_empty(),"moving rail weapons charge slowly instead of firing immediately")
	config.moving = false
	for _step in range(8): rig.advance(0.05,[weapon("rail"),{}],100,"a",config,record)
	check.call(fired.is_empty(),"a stationary rail shot waits for its actual charge time")
	for _step in range(2): rig.advance(0.05,[weapon("rail"),{}],100,"a",config,record)
	check.call(fired==["rail"] and rig.heat==3,"completing charge fires automatically and consumes normal weapon heat")
	rig = RIG.new(); fired.clear()
	rig.advance(0.4,[weapon("rail"),{}],100,"a",config,record)
	config.moving = true; rig.advance(0.1,[weapon("rail"),{}],100,"a",config,record)
	config.moving = false; rig.advance(0.1,[weapon("rail"),{}],100,"a",config,record)
	check.call(fired.is_empty() and rig.weapons[0].aim>0.4,"movement slows an unfinished charge without discarding its progress")
	rig = RIG.new(); fired.clear(); config.moving = true
	for _step in range(9): rig.advance(0.05,[weapon("missile"),{}],100,"a",config,record)
	check.call(fired==["missile"],"missiles finish locking and launch automatically while moving")
	rig = RIG.new(); fired.clear()
	rig.advance(0.3,[weapon("missile"),{}],100,"a",config,record)
	rig.advance(0.15,[weapon("missile"),{}],100,"b",config,record)
	check.call(fired.is_empty(),"changing a missile target restarts its lock instead of inheriting another target's progress")
	rig = RIG.new(); fired.clear()
	for _step in range(10): rig.advance(0.05,[weapon("rail"),weapon("burst",4)],100,"a",config,record)
	check.call(not fired.is_empty() and "rail" not in fired and "burst" in fired,"mixed weapons keep independent behavior: the burst hand fires while the rail hand waits for a stop")
	rig = RIG.new(); fired.clear(); config.moving = false
	rig.advance(0.5,[weapon("rail"),{}],100,"a",config,record)
	rig.advance(0.1,[weapon("rail"),{}],500,"a",config,record)
	rig.advance(0.3,[weapon("rail"),{}],100,"a",config,record)
	check.call(fired.is_empty(),"leaving weapon range clears charge progress")
	main.show_page(0)
	check.call(not main.refs.has("combat_action"),"combat HUD adds no weapon-action button")
