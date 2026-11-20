extends Control
## Original mecha sprite artwork with CC0 Kenney scenery and HUD textures.
const CROSSHAIR = preload("res://assets/free/ui/crosshair.png")
const CONTENT = preload("res://scripts/production_art.gd")
const ART = preload("res://scripts/asset_visuals.gd")
var elapsed: float = 0.0
var flash: float = 0.0
var enemy_flash: float = 0.0
var burst: float = 0.0
var floats: Array = []
var preview: bool = false
var tint := Color("ff5467")
var obscured := Callable()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	State.shot.connect(on_shot)

func on_shot(friendly: bool, damage: int) -> void:
	if friendly:
		flash = 0.22
		if damage > State.total_attack() * 2: burst = 0.65
	else:
		enemy_flash = 0.13
	floats.append({"p": Vector2(490, 110) if friendly else Vector2(130, 170), "t": 1.0, "v": str(damage), "friendly": friendly})

func _process(delta: float) -> void:
	if obscured.is_valid() and obscured.call(): return
	elapsed += delta
	flash = maxf(0, flash - delta)
	enemy_flash = maxf(0, enemy_flash - delta)
	burst = maxf(0, burst - delta)
	for f in floats:
		f.t -= delta
		f.p.y -= delta * 32
	floats = floats.filter(func(f): return f.t > 0)
	queue_redraw()

func mech(pos: Vector2, scale_value: float, col: Color, enemy: bool = false) -> void:
	preload("res://scripts/mech_art.gd").render(self,pos,scale_value,col,enemy,elapsed)

func _draw() -> void:
	var w := size.x
	var h := size.y
	ART.hangar(self,size)
	if preview:
		mech(Vector2(w/2-10,h/2-2),minf(1.55,h/270.0),tint)
	else:
		draw_texture_rect(CROSSHAIR,Rect2(467,113,124,124),false,Color(1,0.7,0.6,0.35+sin(elapsed*2)*0.1))
		mech(Vector2(235,235),0.52,Color("b49aff"))
		if State.unlocked[2]: mech(Vector2(72,235),0.48,Color("7ddfff"))
		mech(Vector2(157,217),0.95,State.MECHS.MODELS[State.mechs.units[State.selected_mech].model].color)
		CONTENT.enemy(self,Vector2(528,210),"cannon" if State.stage%5==0 else "guard",State.stage%5==0,1.1,true)
		if flash>0:
			CONTENT.quad(self,"fx-energy",4,(Vector2(278,217)+Vector2(505,169))*0.5,Vector2(232,22),(Vector2(505,169)-Vector2(278,217)).angle(),Color.WHITE,true)
			CONTENT.fx(self,"fx-kinetic",1,Vector2(505,169),Vector2.ONE*60,1-flash/0.22)
		if enemy_flash>0: CONTENT.fx(self,"fx-kinetic",1,Vector2(160,190),Vector2.ONE*55,1-enemy_flash/0.13)
		if burst>0: CONTENT.fx(self,"fx-kinetic",2,Vector2(510,170),Vector2.ONE*180,1-burst/0.65)
		var font = ThemeDB.fallback_font
		for f in floats:
			draw_string(font,f.p,"−"+f.v,HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color(1,0.83,0.6,f.t) if f.friendly else Color(1,0.35,0.4,f.t))
