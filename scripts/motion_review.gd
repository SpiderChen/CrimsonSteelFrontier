extends Control
## An isolated in-game viewing stage for slow-motion inspection, not combat simulation.
const MECH = preload("res://scripts/mech_art.gd")
var motion = preload("res://scripts/mech_motion.gd").new()
var defense = preload("res://scripts/defense_runtime.gd").new()
var engine = preload("res://scripts/attack_system.gd").new()
var effects = preload("res://scripts/field_feedback.gd").new()
var model: int = 0
var mode: String = "walk"
var weapon: String = "laser"
var paused: bool = false
var rate: float = 1
var clock: float = 0
var shot_clock: float = 0.35
var attack_demo: bool = false
var facing := Vector2.RIGHT
var orbit_view: bool = false

func target_position() -> Vector2:
	return facing*(60.0 if preload("res://scripts/melee.gd").is_mode(weapon) else 195.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	defense.configure({"shield":25},true)

func impact() -> void:
	defense.configure({"shield":25},true)
	defense.hit(8,{"shield":25,"armor":0},false,{"incoming":Vector2.LEFT})
	effects.push("hit",Vector2(-30,-20))
	queue_redraw()

func set_attack_demo(enabled: bool) -> void:
	attack_demo = enabled; engine.reset(); shot_clock = 0.35
	queue_redraw()

func select_weapon(value: String) -> void:
	weapon = value; engine.reset(); shot_clock = 0.35
	queue_redraw()

func _process(delta: float) -> void:
	if paused: return
	var dt := minf(delta,0.1)*rate
	clock += dt
	if attack_demo: shot_clock -= dt
	var direction := -1.0 if fmod(clock,8)>4 else 1.0
	var speed := 0.0 if mode=="idle" else 55.0 if mode=="walk" else 220.0
	facing = Vector2.from_angle(clock*0.55) if orbit_view else Vector2(direction,0.45).normalized()
	motion.advance(dt,facing*speed,model,"walk" if mode in ["idle","run"] else mode,mode=="dash" and fmod(clock,3)>2.4,facing)
	for foot in motion.take_contacts(): effects.push("step",Vector2(foot*20,120),facing)
	defense.advance(dt,{"shield":25},false); effects.advance(dt)
	if attack_demo and shot_clock<=0:
		shot_clock = 3.0
		engine.launch(Vector2.ZERO,target_position(),40,weapon,"",1,{"slot":0,"range":240,"target_id":"preview"})
	engine.advance(self,dt)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("101c29"))
	for y in range(40,int(size.y),40): draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.5,0.65,0.7,0.055),1)
	var center := Vector2(size.x*0.5,size.y*0.45)
	var target := center+target_position()*1.15
	draw_arc(target,12,0,TAU,24,Color("46616d"),1.5,true)
	draw_line(target-Vector2(18,0),target+Vector2(18,0),Color("46616d"),1,true)
	draw_line(target-Vector2(0,18),target+Vector2(0,18),Color("46616d"),1,true)
	var loadout := {"drive":"walk" if mode in ["idle","run"] else mode,"weapons":[{"slot":0,"mode":weapon,"blueprint":MECH.CONTENT.WEAPONS[weapon]}]}
	var pose: Dictionary = motion.pose(); pose.aim_point = target_position()
	pose.ready_slots = {0:float(attack_demo and shot_clock<=0.35),4:0.0}
	MECH.render(self,center,1.15,MECH.COLORS[model],false,clock,pose,loadout,engine,facing,defense)
	var muzzle := func(slot): return center+MECH.muzzle_offset(model,pose,loadout,engine,facing,slot,1.15,self)
	preload("res://scripts/attack_visuals.gd").render(self,engine,func(p): return center+p*1.15,1.15,Vector2.ZERO,muzzle,true)
	effects.render(self,func(p): return center+p*1.15,1.15)
	var font = preload("res://assets/fonts/NotoSansSC.otf")
	var role: String = ["火力王牌","高速近战","重装骑士","矢量游击","长程炮击","堡垒防线"][model]
	draw_string(font,Vector2(16,size.y-18),role+" · "+("攻击演示" if attack_demo else "自然持械")+" · 不消耗资源",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("8c9eb0"))

func attack_targets() -> Array: return [{"id":"preview","p":target_position(),"hp":100000}]
func player_position() -> Vector2: return Vector2.ZERO
func player_alive() -> bool: return true
func line_clear(_a: Vector2,_b: Vector2) -> bool: return true
func cell_at(point: Vector2) -> Vector2i: return Vector2i(point/128)
func is_obstacle(_cell: Vector2i) -> bool: return false
func apply_attack_event(event: Dictionary) -> float: return float(event.damage)
