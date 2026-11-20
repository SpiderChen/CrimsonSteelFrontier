extends RefCounted
## Small cached glow texture and deterministic geometry; never consumes gameplay RNG.
static var glow_texture: GradientTexture2D
const HOT = Color("fff6df")

static func tint(mode: String) -> Color:
	match mode:
		"rail", "pulse": return Color("69dfff")
		"plasma": return Color("bd7aff")
		"laser": return Color("ff486d")
		"blade": return Color("ff77bf")
		"gauntlet": return Color("79ffd2")
		_: return Color("ffb64d")

static func glow(canvas: CanvasItem, p: Vector2, radius: float, color: Color, alpha: float = 1.0, aspect: Vector2 = Vector2.ONE) -> void:
	if radius<=0.01 or alpha<=0.001: return
	if glow_texture==null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0,0.12,0.35,0.68,1])
		gradient.colors = PackedColorArray([Color(1,1,1,0.9),Color(1,1,1,0.65),Color(1,1,1,0.24),Color(1,1,1,0.04),Color(1,1,1,0)])
		glow_texture = GradientTexture2D.new()
		glow_texture.width = 64; glow_texture.height = 64
		glow_texture.gradient = gradient
		glow_texture.fill = GradientTexture2D.FILL_RADIAL
		glow_texture.fill_from = Vector2(0.5,0.5); glow_texture.fill_to = Vector2(1,0.5)
	var bounds := Vector2.ONE*radius*2*aspect
	canvas.draw_texture_rect(glow_texture,Rect2(p-bounds*0.5,bounds),false,Color(color,alpha))

static func streak(canvas: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color, alpha: float = 1.0) -> void:
	if a.distance_squared_to(b)<0.01: return
	var normal := a.direction_to(b).orthogonal()*width*0.5
	canvas.draw_polygon(PackedVector2Array([a,b+normal,b-normal]),PackedColorArray([Color(color,0),Color(color,alpha),Color(color,alpha)]))
	canvas.draw_line(a.lerp(b,0.45),b,Color(HOT,alpha),maxf(0.65,width*0.22),true)

static func sparks(canvas: CanvasItem, p: Vector2, t: float, color: Color, scale_value: float, count: int = 8, reach: float = 45, angle: float = 0.0, spread: float = TAU) -> void:
	var fade := pow(1-clampf(t,0,1),1.4)
	for i in range(count):
		var seed_value := fposmod(sin(i*127.1+p.x*0.013+p.y*0.017)*43758.5453,1)
		var direction := Vector2.from_angle(angle+(seed_value-0.5)*spread)
		var speed := reach*(0.4+seed_value*0.6)
		var at := p+(direction*speed*(1-pow(1-t,2))+Vector2(0,reach*0.35*t*t))*scale_value
		streak(canvas,at-direction*(3+speed*0.14)*scale_value*fade,at,(1.2+seed_value)*scale_value,color,fade)

static func muzzle(canvas: CanvasItem, p: Vector2, angle: float, mode: String, t: float, scale_value: float) -> void:
	var color := tint(mode)
	var fade := pow(1-t,2)
	var direction := Vector2.from_angle(angle)
	var side := direction.orthogonal()
	var length_value := (46 if mode=="rail" else 31 if mode in ["plasma","pulse"] else 25)*scale_value*(0.5+fade*0.5)
	glow(canvas,p,32*scale_value,color,fade*0.7)
	if mode in ["laser","pulse","plasma"]:
		canvas.draw_arc(p,(4+t*13)*scale_value,0,TAU,24,Color(color,fade),1.5*scale_value,true)
	else:
		var points := PackedVector2Array([p-side*4*scale_value,p+direction*length_value*0.4-side*8*scale_value,p+direction*length_value,p+direction*length_value*0.4+side*8*scale_value,p+side*4*scale_value])
		canvas.draw_colored_polygon(points,Color(color,fade*0.8))
		streak(canvas,p+direction*length_value,p,6*scale_value,HOT,fade)
	glow(canvas,p,9*scale_value,HOT,fade)

static func impact(canvas: CanvasItem, p: Vector2, mode: String, t: float, scale_value: float, angle: float = 0.0) -> void:
	var color := tint(mode)
	var fade := 1-t
	var heavy: bool = mode in ["hammer","plasma","missile"]
	glow(canvas,p,(40 if heavy else 25)*scale_value,color,fade*0.7)
	glow(canvas,p,(12 if heavy else 7)*scale_value,HOT,pow(fade,3))
	if mode=="blade":
		var d := Vector2.from_angle(angle-0.6)
		streak(canvas,p-d*30*scale_value*fade,p+d*30*scale_value*fade,5*scale_value,color,fade)
		streak(canvas,p+d*30*scale_value*fade,p-d*30*scale_value*fade,5*scale_value,color,fade)
	elif mode in ["rail","pulse","gauntlet","hammer"]:
		canvas.draw_arc(p,(4+t*(38 if heavy else 20))*scale_value,0,TAU,32,Color(color,fade*0.65),(2.8 if heavy else 1.5)*scale_value,true)
	sparks(canvas,p,t,color,scale_value,12 if heavy else 7,65 if heavy else 34,angle,TAU if heavy else 4.3)

static func explosion(canvas: CanvasItem, p: Vector2, radius: float, mode: String, t: float, scale_value: float, ion: bool = false) -> void:
	var color := Color("69dfff") if ion else tint(mode)
	var fade := 1-t
	var extent := radius*scale_value
	# The initial hot flash collapses while the shock front and fragments expand.
	glow(canvas,p,extent*(0.35+t*0.7),color,fade*0.8)
	glow(canvas,p,extent*0.3*pow(fade,2),HOT,pow(fade,2))
	for i in range(7):
		var direction := Vector2.from_angle(i*2.399+p.x*0.01)
		var at := p+direction*extent*t*(0.3+float(i%3)*0.13)-Vector2(0,t*t*extent*0.2)
		glow(canvas,at,extent*(0.12+0.12*t),color,fade*0.38)
	canvas.draw_arc(p,extent*(0.15+0.85*sqrt(t)),0,TAU,48,Color(color,fade*fade*0.65),maxf(0.8,2.5*scale_value*fade),true)
	sparks(canvas,p,t,color,scale_value,14,radius*1.1)

static func beam(canvas: CanvasItem, a: Vector2, b: Vector2, age: float, duration: float, mode: String, scale_value: float) -> void:
	var pulse: bool = mode=="pulse"
	var color := tint(mode)
	var envelope := 1-smoothstep(duration-0.09,duration,age)
	var width := (7.0 if pulse else 3.0)*scale_value*envelope*(0.93+sin(age*83)*0.07)
	if width<0.01: return
	var side := a.direction_to(b).orthogonal()
	canvas.draw_line(a,b,Color(color,0.07*envelope),width*6,true)
	canvas.draw_line(a,b,Color(color,0.22*envelope),width*2.8,true)
	canvas.draw_line(a,b,Color(color,0.9*envelope),width*1.3,true)
	canvas.draw_line(a,b,Color(HOT,envelope),width*0.48,true)
	# Short travelling filaments give the beam a direction without changing its ray.
	for i in range(3):
		var u := fposmod(age*(3 if pulse else 1.8)+i/3.0,1)
		var at := a.lerp(b,u)
		var offset := side*sin(u*PI)*sin(u*24+age*25)*3*scale_value
		canvas.draw_line(a.lerp(b,maxf(0,u-0.06))+offset,at+offset,Color(color,0.65*envelope),scale_value,true)
	glow(canvas,a,24*scale_value,color,0.7*envelope)
	glow(canvas,b,(36 if pulse else 23)*scale_value,color,0.75*envelope)
	glow(canvas,b,7*scale_value,HOT,envelope)
	canvas.draw_arc(b,(8+sin(age*65)*2)*scale_value,age*9,age*9+PI*1.3,20,Color(color,0.7*envelope),1.5*scale_value,true)
	sparks(canvas,b,fposmod(age*5,1),color,scale_value,6,28, b.direction_to(a).angle(),PI)

static func wake(canvas: CanvasItem, points: Array, project: Callable, lift: Vector2, scale_value: float, mode: String, alpha: float = 1.0) -> void:
	var color := tint(mode)
	var count := points.size()
	for i in range(1,count):
		var u := float(i)/count
		var a: Vector2 = project.call(points[i-1])+lift
		var b: Vector2 = project.call(points[i])+lift
		if a.distance_squared_to(b)<0.01: continue
		var width := (5 if mode=="rail" else 8 if mode=="plasma" else 3)*scale_value*u
		canvas.draw_line(a,b,Color(color,u*alpha*0.13),width*3,true)
		canvas.draw_line(a,b,Color(color,u*alpha*0.65),maxf(0.6,width),true)
		if mode=="rail":
			canvas.draw_line(a,b,Color(HOT,u*alpha),maxf(0.6,scale_value),true)
			var side := a.direction_to(b).orthogonal()*sin(i*4.7)*5*scale_value
			canvas.draw_polyline(PackedVector2Array([a,a.lerp(b,0.45)+side,b]),Color(color,u*alpha*0.6),scale_value,true)
