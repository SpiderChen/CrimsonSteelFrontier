extends RefCounted
const PROJECTION = preload("res://scripts/rig/mech_projection.gd")
## Presentation follows actual movement, so blocked input cannot make the feet run.
var phase: float = 0
var blend: float = 0
var facing: float = 1
var lean: float = 0
var clock: float = 0
var drive: String = "walk"
var boost: bool = false
var velocity := Vector2.ZERO
var display_facing: float = 1
var turn_time: float = 0
var turn_from: float = 1
var contacts: Array = []
var yaw: float = -2.2
var yaw_initialized: bool = false

func advance(delta: float, actual: Vector2, model: int, mode: String, boosting: bool = false, look: Vector2 = Vector2.ZERO) -> void:
	var dt := clampf(delta,0,0.1)
	clock += dt; drive = mode; boost = boosting
	var speed := actual.length()
	velocity = velocity.lerp(actual,1-exp(-dt*10))
	blend = lerpf(blend,minf(1.0,speed/30.0),1-exp(-dt*11))
	if blend<0.005: blend = 0
	elif blend>0.995: blend = 1
	if speed>1:
		# Match the projected 3D foot sweep to world travel during the planted phase.
		var running := smoothstep(55.0,210.0,speed)
		var amplitude := lerpf(0.34,0.72,running)
		var support := lerpf(0.62,0.44,running)
		var cycle_distance := amplitude*2*(PROJECTION.DRAW_SIZE.x/PROJECTION.CAMERA_SIZE)*0.43/support*clampf(speed/30.0,0.15,1)*PROJECTION.stride_projection(actual)
		var next_phase: float = phase+speed*dt/cycle_distance*TAU
		if floori(next_phase/PI)!=floori(phase/PI) and mode in ["walk","dash"] and not boost:
			contacts.append(1 if int(floor(next_phase/PI))%2 else -1)
			if contacts.size()>4: contacts.pop_front()
		phase = fmod(next_phase,TAU)
	var heading := look if look.length_squared()>0.01 else actual
	if heading.length_squared()>0.01:
		var desired_yaw := PROJECTION.heading(heading)
		yaw = lerp_angle(yaw,desired_yaw,1-exp(-dt*10)) if yaw_initialized else desired_yaw
		yaw_initialized = true
	if absf(heading.x)>(0.15 if look.length_squared()>0.01 else 24.0):
		var wanted: float = -1 if heading.x<0 else 1
		if wanted!=facing: turn_from = display_facing; facing = wanted; turn_time = 0.24
	turn_time = maxf(0,turn_time-dt)
	if turn_time<=0.12: display_facing = facing
	lean = lerpf(lean,clampf(velocity.x/280.0,-1,1)*(0.08 if mode=="hover" or boosting else 0.035),1-exp(-dt*9))

static func foot(cycle: float) -> Vector2:
	var t := fposmod(cycle/TAU,1)
	if t<0.6: return Vector2(lerpf(11,-11,t/0.6),0)
	var swing := (t-0.6)/0.4
	return Vector2(lerpf(-11,11,smoothstep(0,1,swing)),-sin(swing*PI)*14)

func take_contacts() -> Array:
	var result := contacts.duplicate(); contacts.clear(); return result

func pose() -> Dictionary:
	var stepping := blend if drive in ["walk","dash"] and not boost else 0.0
	var bob := -pow(sin(phase),2)*2.2*stepping+sin(clock*2.1)*0.35 if drive!="hover" else -6+sin(clock*3.5)*1.2
	var turn_scale := maxf(0.12,absf(cos(clampf(turn_time/0.24,0,1)*PI)))
	var left := foot(phase); var right := foot(phase+PI)
	if velocity.x*display_facing<-24: left.x *= -1; right.x *= -1
	return {"yaw":yaw,"velocity":velocity,"phase":phase,"stride":stepping,"blend":blend,"facing":display_facing*turn_scale,"lean":lean+sin(phase)*0.008*stepping,"drive":drive,"boost":boost,"clock":clock,"bob":bob,
		"left":Vector2(-3,-6)*blend if drive=="hover" else (left-Vector2(0,bob))*stepping,
		"right":Vector2(2,-4)*blend if drive=="hover" else (right-Vector2(0,bob))*stepping}
