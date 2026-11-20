extends RefCounted
## Short, local presentation events; no damage, rewards or gameplay RNG here.
const LIMIT = 56
const LIFETIMES = {"step":0.42,"brake":0.5,"boost":0.3,"hit":0.22,"destroy":0.65,"discover":0.9,"loot":0.85,"repair":1.0,"vent":0.7}
var events: Array = []

func push(kind: String, point: Vector2, target: Vector2 = Vector2.ZERO) -> void:
	if not LIFETIMES.has(kind): return
	for item in events:
		if item.kind==kind and item.age<0.08 and item.p.distance_to(point)<18: return
	if events.size()>=LIMIT: events.pop_front()
	events.append({"kind":kind,"p":point,"target":target,"age":0.0,"life":LIFETIMES[kind]})

func advance(delta: float) -> void:
	for item in events: item.age += delta
	events = events.filter(func(item): return item.age<item.life)

func render(canvas: CanvasItem, project: Callable, scale_value: float) -> void:
	for item in events:
		var t: float = item.age/item.life
		var p: Vector2 = project.call(item.p)
		var alpha := (1-t)*(1-t)
		match item.kind:
			"step","brake","boost":
				var direction: Vector2 = item.target.normalized()
				for i in range(5):
					var drift := Vector2.from_angle(i*2.399)*Vector2(13,5)*(0.3+t)
					drift -= direction*t*(22 if item.kind!="step" else 5)
					canvas.draw_circle(p+drift*scale_value,(1.2+t*3)*scale_value,Color(0.62,0.65,0.66,alpha*0.2))
			"hit","destroy":
				var count: int = 9 if item.kind=="destroy" else 5
				for i in range(count):
					var direction := Vector2.from_angle(i*2.399+item.p.x*0.01)
					var distance: float = (30 if item.kind=="destroy" else 15)*t
					var end: Vector2 = p+(direction*distance+Vector2(0,12*t*t))*scale_value
					canvas.draw_line(end-direction*4*scale_value,end,Color(1,0.77,0.4,alpha),1.4*scale_value,true)
			"discover":
				var span: float = (13+12*(1-t))*scale_value
				for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
					var at: Vector2 = p+corner*span
					canvas.draw_polyline(PackedVector2Array([at-Vector2(corner.x*7,0)*scale_value,at,at-Vector2(0,corner.y*7)*scale_value]),Color(0.8,0.88,0.68,alpha*0.75),1.3*scale_value,true)
			"loot":
				var target: Vector2 = project.call(item.target)
				for i in range(6):
					var u := clampf(t*1.5-i*0.075,0,1)
					var at: Vector2 = p.lerp(target,smoothstep(0,1,u))-Vector2(0,sin(u*PI)*30)*scale_value
					canvas.draw_rect(Rect2(at-Vector2.ONE*2*scale_value,Vector2.ONE*4*scale_value),Color(0.95,0.81,0.48,sin(u*PI)*0.8))
			"repair","vent":
				for i in range(6):
					var u := fposmod(t+i/6.0,1)
					var at: Vector2 = p+Vector2(sin(i*2.4)*19,-u*38)*scale_value
					var color := Color(0.5,0.95,0.7,alpha*sin(u*PI)*0.7) if item.kind=="repair" else Color(0.75,0.87,0.94,alpha*sin(u*PI)*0.35)
					if item.kind=="repair":
						canvas.draw_line(at-Vector2(3,0)*scale_value,at+Vector2(3,0)*scale_value,color,1.4*scale_value,true)
						canvas.draw_line(at-Vector2(0,3)*scale_value,at+Vector2(0,3)*scale_value,color,1.4*scale_value,true)
					else: canvas.draw_line(at,at-Vector2(sin(u*PI)*4,8)*scale_value,color,2*scale_value,true)
