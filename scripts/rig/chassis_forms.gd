extends RefCounted
## Each new frame is authored from its own head, torso and limb profiles.
## Held weapons still belong to the real wrist equipment sockets in MechRig3D.

static func build_hull(r) -> void:
	if r.model==3: wolf_hull(r)
	elif r.model==4: artillery_hull(r)
	else: fortress_hull(r)

static func wolf_hull(r) -> void:
	var p: Node3D = r.attachments.pelvis; var c: Node3D = r.attachments.chest; var h: Node3D = r.attachments.head
	# Long exposed waist, narrow diamond breastplate and almost no hanging skirt.
	r.part(p,Vector3(0.30,0.28,0.28),Vector3.ZERO,"dark")
	for i in range(3): r.part(p,Vector3(0.28-i*0.025,0.10,0.24),Vector3(0,0.16+i*0.105,-0.015),"metal")
	r.panel(c,[[-0.5,0.28],[-0.30,0.5],[0.30,0.5],[0.5,0.28],[0.28,-0.22],[0,-0.5],[-0.28,-0.22]],Vector2(0.79,0.62),0.40,Vector3(0,0.015,0),"dark")
	r.panel(c,[[-0.5,0.5],[0.5,0.5],[0.32,0.03],[0.05,-0.5],[-0.05,-0.5],[-0.32,0.03]],Vector2(0.77,0.58),0.16,Vector3(0,0.04,-0.24),"armor")
	r.lancet(c,Vector3(0.12,0.50,0.055),Vector3(0,0.055,-0.35),"white")
	r.part(c,Vector3(0.055,0.10,0.025),Vector3(0,0.15,-0.39),"light",Vector3.ZERO,false)
	for side in [-1,1]:
		r.lancet(c,Vector3(0.13,0.34,0.13),Vector3(side*0.32,-0.05,-0.18),"white",Vector3(0,side*-0.35,side*-0.40))
		r.vent(c,Vector2(0.105,0.24),Vector3(side*0.25,0.12,-0.33),Vector3(0,side*-0.3,side*-0.40))
		r.lancet(p,Vector3(0.13,0.53,0.12),Vector3(side*0.26,-0.10,0),"armor",Vector3(0.20,0,side*-0.35))
		r.lancet(p,Vector3(0.11,0.34,0.07),Vector3(side*0.15,-0.10,-0.20),"white",Vector3(0,0,side*-0.2))
	r.cylinder(c,0.065,0.20,Vector3(0,0.37,0),"metal")
	# An elongated prow helmet with vertical swept ears; there is no shared V-fin.
	r.panel(h,[[-0.5,-0.1],[-0.3,0.5],[0.3,0.5],[0.5,-0.1],[0,-0.5]],Vector2(0.27,0.44),0.34,Vector3(0,0.03,-0.015),"white")
	r.panel(h,[[-0.5,0.5],[0.5,0.5],[0.34,-0.15],[0,-0.5],[-0.34,-0.15]],Vector2(0.19,0.26),0.12,Vector3(0,-0.08,-0.22),"armor")
	r.part(h,Vector3(0.23,0.045,0.025),Vector3(0,0.025,-0.205),"dark",Vector3.ZERO,false)
	for side in [-1,1]:
		r.panel(h,[[side*-0.5,0.2],[side*0.5,0.5],[side*0.3,-0.4],[side*-0.5,-0.3]],Vector2(0.085,0.035),0.02,Vector3(side*0.058,0.023,-0.227),"light",Vector3.ZERO,0)
		r.panel(h,[[side*-0.5,-0.5],[side*0.05,0.5],[side*0.5,0.20],[side*0.32,-0.5]],Vector2(0.13,0.48),0.065,Vector3(side*0.145,0.25,0.065),"armor",Vector3(0.42,0,side*-0.13))
	r.panel(h,[[-0.5,-0.5],[0.5,-0.5],[0.30,0.5],[-0.3,0.35]],Vector2(0.30,0.22),0.035,Vector3(0,0.20,0.02),"white",Vector3(0,PI/2,0))
	# Blade-shaped vector booms sweep behind the shoulders, with open space at the waist.
	for side in [-1,1]:
		var mount := Node3D.new(); c.add_child(mount); mount.position = Vector3(side*0.34,0.03,0.34); mount.rotation = Vector3(0.50,0,side*-0.40)
		r.lancet(mount,Vector3(0.19,1.13,0.27),Vector3(0,0.04,0.10),"armor")
		r.lancet(mount,Vector3(0.075,0.82,0.035),Vector3(0,0.13,-0.055),"white")
		r.cylinder(mount,0.09,0.22,Vector3(0,-0.48,0.10),"metal")
		jet(r,mount,Vector3(0,-0.65,0.10),0.055)

static func artillery_hull(r) -> void:
	var p: Node3D = r.attachments.pelvis; var c: Node3D = r.attachments.chest; var h: Node3D = r.attachments.head
	r.part(p,Vector3(0.52,0.27,0.40),Vector3.ZERO,"dark")
	r.part(p,Vector3(0.47,0.26,0.34),Vector3(0,0.25,0),"metal")
	r.part(p,Vector3(0.60,0.15,0.12),Vector3(0,0.03,-0.25),"armor")
	r.part(c,Vector3(0.95,0.62,0.53),Vector3(0,0.025,0),"dark")
	# A horizontal fire-control bridge replaces the old split pectoral plates.
	r.panel(c,[[-0.5,-0.2],[-0.38,0.5],[0.38,0.5],[0.5,-0.2],[0.24,-0.5],[-0.24,-0.5]],Vector2(1.06,0.30),0.32,Vector3(0,0.21,-0.18),"white")
	r.part(c,Vector3(0.64,0.09,0.04),Vector3(0,0.23,-0.365),"dark",Vector3.ZERO,false)
	for i in range(4): r.part(c,Vector3(0.10,0.035,0.015),Vector3((i-1.5)*0.145,0.23,-0.397),"light",Vector3.ZERO,false)
	r.part(c,Vector3(0.28,0.44,0.17),Vector3(0,-0.04,-0.30),"armor")
	r.vent(c,Vector2(0.15,0.24),Vector3(0,-0.04,-0.405))
	for side in [-1,1]:
		r.panel(c,[[-0.5,0.5],[0.5,0.4],[0.40,-0.5],[-0.28,-0.35]],Vector2(0.31,0.45),0.25,Vector3(side*0.34,-0.07,-0.19),"armor",Vector3(0,side*-0.12,0))
		r.part(p,Vector3(0.28,0.32,0.17),Vector3(side*0.22,-0.17,-0.24),"white",Vector3(-0.12,0,side*-0.08))
		r.part(p,Vector3(0.22,0.31,0.29),Vector3(side*0.41,-0.10,0.04),"armor")
	r.cylinder(c,0.09,0.19,Vector3(0,0.39,0),"metal")
	# Low rectangular optic head, a circular main lens and a single side aerial.
	r.panel(h,[[-0.5,-0.25],[-0.40,0.5],[0.40,0.5],[0.5,-0.25],[0.22,-0.5],[-0.22,-0.5]],Vector2(0.41,0.29),0.34,Vector3(0,0.01,0),"armor")
	r.part(h,Vector3(0.36,0.07,0.39),Vector3(0,0.15,0),"white")
	r.part(h,Vector3(0.32,0.12,0.03),Vector3(0,-0.005,-0.19),"dark",Vector3.ZERO,false)
	r.cylinder(h,0.085,0.08,Vector3(0.065,0.01,-0.23),"metal",Vector3(PI/2,0,0))
	r.cylinder(h,0.060,0.025,Vector3(0.065,0.01,-0.285),"light",Vector3(PI/2,0,0))
	r.part(h,Vector3(0.06,0.03,0.025),Vector3(-0.10,0.005,-0.22),"light",Vector3.ZERO,false)
	r.cylinder(h,0.017,0.45,Vector3(-0.19,0.28,0.06),"metal")
	# Open rail frames and radiator screens are structural supports, never fake guns.
	for side in [-1,1]:
		for rail in [-1,1]: r.part(c,Vector3(0.075,1.22,0.13),Vector3(side*0.47+rail*0.13,0.32,0.47),"armor",Vector3(0.12,0,side*-0.10))
		for y in [-0.18,0.33,0.85]: r.part(c,Vector3(0.32,0.09,0.14),Vector3(side*0.47,y,0.47),"white")
		r.part(c,Vector3(0.43,0.66,0.12),Vector3(side*0.74,0.14,0.65),"dark",Vector3(0,side*0.20,side*-0.14))
		for i in range(6): r.part(c,Vector3(0.36,0.035,0.035),Vector3(side*0.74,-0.10+i*0.09,0.56),"gold",Vector3(0,0,side*-0.14),false)
		r.cylinder(c,0.12,0.26,Vector3(side*0.28,-0.21,0.42),"metal")
		jet(r,c,Vector3(side*0.28,-0.43,0.42),0.07)
	r.part(c,Vector3(0.25,0.13,0.20),Vector3(-0.47,0.96,0.47),"dark")
	r.part(c,Vector3(0.16,0.04,0.025),Vector3(-0.47,0.96,0.355),"light",Vector3.ZERO,false)

static func fortress_hull(r) -> void:
	var p: Node3D = r.attachments.pelvis; var c: Node3D = r.attachments.chest; var h: Node3D = r.attachments.head
	r.part(p,Vector3(0.79,0.30,0.53),Vector3.ZERO,"dark")
	r.part(p,Vector3(0.65,0.27,0.49),Vector3(0,0.21,0),"metal")
	r.part(p,Vector3(0.66,0.22,0.18),Vector3(0,-0.01,-0.34),"armor")
	# One broad armored glacis, deep side walls and a raised protective collar.
	r.part(c,Vector3(1.29,0.70,0.66),Vector3(0,0.015,0),"dark")
	var face: Array = [[-0.5,-0.24],[-0.5,0.24],[-0.32,0.5],[0.32,0.5],[0.5,0.24],[0.5,-0.24],[0.30,-0.5],[-0.30,-0.5]]
	r.panel(c,face,Vector2(1.34,0.66),0.30,Vector3(0,0.035,-0.32),"armor")
	r.panel(c,face,Vector2(1.01,0.28),0.12,Vector3(0,-0.23,-0.48),"white")
	r.cylinder(c,0.14,0.07,Vector3(0,0.025,-0.51),"dark",Vector3(PI/2,0,0))
	r.part(c,Vector3(0.17,0.045,0.025),Vector3(0,0.025,-0.56),"light",Vector3.ZERO,false)
	for side in [-1,1]:
		r.part(c,Vector3(0.36,0.22,0.15),Vector3(side*0.39,0.09,-0.50),"white")
		r.vent(c,Vector2(0.23,0.10),Vector3(side*0.39,0.07,-0.60))
		r.part(c,Vector3(0.27,0.30,0.48),Vector3(side*0.35,0.38,-0.04),"white")
		r.part(p,Vector3(0.40,0.40,0.21),Vector3(side*0.27,-0.18,-0.31),"white",Vector3(-0.12,0,0))
		r.part(p,Vector3(0.32,0.43,0.46),Vector3(side*0.57,-0.13,0.03),"armor",Vector3(0,0,side*-0.10))
	# Small sunken visor head has a thick brow and no crest or horns.
	r.panel(h,[[-0.5,-0.30],[-0.46,0.25],[-0.25,0.5],[0.25,0.5],[0.46,0.25],[0.5,-0.30],[0,-0.5]],Vector2(0.43,0.29),0.40,Vector3(0,-0.015,-0.025),"white")
	r.part(h,Vector3(0.46,0.105,0.24),Vector3(0,0.07,-0.17),"armor")
	r.part(h,Vector3(0.35,0.065,0.035),Vector3(0,-0.02,-0.25),"dark",Vector3.ZERO,false)
	r.part(h,Vector3(0.29,0.023,0.018),Vector3(0,-0.018,-0.277),"light",Vector3.ZERO,false)
	r.part(h,Vector3(0.25,0.08,0.12),Vector3(0,-0.13,-0.20),"armor")
	r.panel(c,face,Vector2(1.18,0.82),0.31,Vector3(0,0.04,0.49),"white")
	for side in [-1,1]:
		r.part(c,Vector3(0.24,0.53,0.13),Vector3(side*0.32,0.08,0.71),"armor")
		r.cylinder(c,0.15,0.25,Vector3(side*0.38,-0.32,0.45),"metal")
		jet(r,c,Vector3(side*0.38,-0.56,0.45),0.085)

static func build_limbs(r, side: int) -> void:
	var prefix := "left" if side<0 else "right"
	var hip: Node3D = r.attachments[prefix+"_hip"]; var knee: Node3D = r.attachments[prefix+"_knee"]; var ankle: Node3D = r.attachments[prefix+"_ankle"]
	var shoulder: Node3D = r.attachments[prefix+"_shoulder"]; var elbow: Node3D = r.attachments[prefix+"_elbow"]; var wrist: Node3D = r.attachments[prefix+"_wrist"]
	r.leg_attachments.append_array([hip,knee,ankle])
	if r.model==3: wolf_limbs(r,side,hip,knee,ankle,shoulder,elbow)
	elif r.model==4: artillery_limbs(r,side,hip,knee,ankle,shoulder,elbow)
	else: fortress_limbs(r,side,hip,knee,ankle,shoulder,elbow)
	# Identical functional hands preserve every existing weapon and effect socket.
	r.part(wrist,Vector3(0.20,0.18,0.19),Vector3.ZERO,"dark")
	r.lancet(wrist,Vector3(0.18,0.15,0.04),Vector3(0,0,-0.12),"metal")
	for finger in range(4):
		r.part(wrist,Vector3(0.036,0.06,0.07),Vector3((finger-1.5)*0.045,-0.065,-0.095),"metal",Vector3.ZERO,false)
		r.part(wrist,Vector3(0.032,0.055,0.04),Vector3((finger-1.5)*0.045,-0.10,-0.07),"dark",Vector3.ZERO,false)

static func wolf_limbs(r, side: int, hip: Node3D, knee: Node3D, ankle: Node3D, shoulder: Node3D, elbow: Node3D) -> void:
	r.joint(hip,0.11,0.19,Vector3.ZERO)
	r.part(hip,Vector3(0.135,0.71,0.16),Vector3(0,-0.45,0),"dark")
	r.lancet(hip,Vector3(0.235,0.75,0.17),Vector3(0,-0.44,-0.10),"white",Vector3(-0.10,0,side*-0.05))
	r.lancet(hip,Vector3(0.07,0.55,0.035),Vector3(side*0.06,-0.44,-0.21),"armor")
	r.joint(knee,0.105,0.21,Vector3.ZERO)
	r.lancet(knee,Vector3(0.22,0.32,0.17),Vector3(0,0,-0.17),"armor")
	r.part(knee,Vector3(0.14,0.76,0.17),Vector3(0,-0.46,0.03),"dark")
	r.panel(knee,[[-0.5,0.5],[0.5,0.5],[0.32,-0.15],[0,-0.5],[-0.32,-0.15]],Vector2(0.28,0.84),0.19,Vector3(0,-0.48,-0.09),"white",Vector3(0.06,0,0))
	r.lancet(knee,Vector3(0.07,0.62,0.04),Vector3(0,-0.43,-0.23),"armor")
	r.lancet(knee,Vector3(0.14,0.58,0.26),Vector3(side*0.16,-0.37,0.12),"armor",Vector3(0.40,0,side*-0.20))
	r.cylinder(knee,0.026,0.53,Vector3(-side*0.105,-0.52,0.13),"metal")
	r.part(ankle,Vector3(0.24,0.12,0.66),Vector3(0,-0.035,-0.20),"dark")
	r.panel(ankle,[[-0.5,0.5],[0.5,0.5],[0.34,-0.25],[0,-0.5],[-0.34,-0.25]],Vector2(0.26,0.68),0.13,Vector3(0,0.055,-0.22),"armor",Vector3(PI/2-0.12,0,0))
	r.joint(shoulder,0.125,0.20,Vector3.ZERO)
	r.panel(shoulder,[[side*-0.5,-0.3],[side*-0.40,0.15],[side*0.5,0.5],[side*0.30,-0.15],[side*0.02,-0.5]],Vector2(0.53,0.60),0.25,Vector3(side*0.10,0.10,0.02),"armor",Vector3(0.17,0,side*-0.12))
	r.lancet(shoulder,Vector3(0.10,0.40,0.035),Vector3(side*0.14,0.10,-0.13),"white",Vector3(0.17,0,side*-0.26))
	r.part(shoulder,Vector3(0.13,0.34,0.16),Vector3(0,-0.31,0),"dark")
	r.lancet(shoulder,Vector3(0.17,0.28,0.10),Vector3(0,-0.30,-0.10),"white")
	r.joint(elbow,0.085,0.19,Vector3.ZERO)
	r.part(elbow,Vector3(0.14,0.35,0.16),Vector3(0,-0.24,0),"dark")
	r.lancet(elbow,Vector3(0.22,0.48,0.19),Vector3(0,-0.22,-0.075),"white")
	r.panel(elbow,[[side*-0.5,-0.5],[side*-0.4,0.35],[side*0.5,0.5],[side*0.15,-0.30]],Vector2(0.16,0.56),0.10,Vector3(side*0.14,-0.19,0.04),"armor",Vector3(0.22,0,side*-0.13))

static func artillery_limbs(r, side: int, hip: Node3D, knee: Node3D, ankle: Node3D, shoulder: Node3D, elbow: Node3D) -> void:
	r.joint(hip,0.13,0.30,Vector3.ZERO)
	r.part(hip,Vector3(0.22,0.61,0.25),Vector3(0,-0.38,0),"dark")
	r.part(hip,Vector3(0.34,0.60,0.20),Vector3(0,-0.38,-0.10),"white",Vector3(-0.08,0,0))
	r.part(hip,Vector3(0.16,0.32,0.035),Vector3(0,-0.38,-0.225),"armor")
	r.joint(knee,0.14,0.35,Vector3.ZERO)
	r.panel(knee,[[-0.5,-0.2],[-0.35,0.5],[0.35,0.5],[0.5,-0.2],[0.25,-0.5],[-0.25,-0.5]],Vector2(0.40,0.27),0.19,Vector3(0,0,-0.21),"armor")
	r.part(knee,Vector3(0.28,0.65,0.29),Vector3(0,-0.42,0),"dark")
	r.panel(knee,[[-0.5,0.5],[0.5,0.5],[0.40,-0.5],[-0.40,-0.5]],Vector2(0.39,0.70),0.21,Vector3(0,-0.43,-0.12),"white")
	r.part(knee,Vector3(0.17,0.30,0.045),Vector3(0,-0.35,-0.25),"armor")
	# Folded stabilizer links and wide heel pads move with the existing leg bones.
	r.part(knee,Vector3(0.12,0.62,0.17),Vector3(side*0.23,-0.42,0.19),"armor",Vector3(-0.16,0,0))
	r.cylinder(knee,0.035,0.43,Vector3(side*0.14,-0.45,0.27),"metal",Vector3(-0.16,0,0))
	r.part(ankle,Vector3(0.41,0.15,0.69),Vector3(0,-0.025,-0.16),"dark")
	r.part(ankle,Vector3(0.42,0.18,0.44),Vector3(0,0.055,-0.23),"armor",Vector3(0.12,0,0))
	r.part(ankle,Vector3(0.14,0.15,0.49),Vector3(side*0.24,0.015,0.13),"white")
	r.joint(shoulder,0.15,0.28,Vector3.ZERO)
	r.panel(shoulder,[[-0.5,-0.5],[-0.5,0.30],[-0.23,0.5],[0.5,0.5],[0.5,-0.22],[0.12,-0.5]],Vector2(0.62,0.37),0.50,Vector3(side*0.11,0.10,0.04),"white")
	r.part(shoulder,Vector3(0.42,0.13,0.27),Vector3(side*0.12,0.29,0.04),"armor")
	r.part(shoulder,Vector3(0.34,0.11,0.045),Vector3(side*0.12,0.08,-0.24),"dark",Vector3.ZERO,false)
	for i in range(3): r.part(shoulder,Vector3(0.045,0.07,0.02),Vector3(side*0.12+(i-1)*0.08,0.08,-0.27),"metal",Vector3.ZERO,false)
	r.part(shoulder,Vector3(0.20,0.32,0.23),Vector3(0,-0.30,0),"dark")
	r.part(shoulder,Vector3(0.26,0.25,0.16),Vector3(0,-0.29,-0.09),"armor")
	r.joint(elbow,0.11,0.29,Vector3.ZERO)
	r.part(elbow,Vector3(0.23,0.34,0.25),Vector3(0,-0.23,0),"dark")
	r.part(elbow,Vector3(0.34,0.43,0.24),Vector3(0,-0.21,-0.06),"white")
	r.part(elbow,Vector3(0.18,0.24,0.045),Vector3(0,-0.21,-0.21),"armor")
	for z in [-0.06,0.10]: r.cylinder(elbow,0.026,0.34,Vector3(side*0.19,-0.21,z),"metal")

static func fortress_limbs(r, side: int, hip: Node3D, knee: Node3D, ankle: Node3D, shoulder: Node3D, elbow: Node3D) -> void:
	r.joint(hip,0.17,0.43,Vector3.ZERO)
	r.part(hip,Vector3(0.32,0.52,0.35),Vector3(0,-0.34,0),"dark")
	r.part(hip,Vector3(0.48,0.55,0.34),Vector3(0,-0.34,-0.08),"white")
	r.part(hip,Vector3(0.28,0.25,0.07),Vector3(0,-0.30,-0.28),"armor")
	r.joint(knee,0.16,0.48,Vector3.ZERO)
	r.part(knee,Vector3(0.51,0.27,0.24),Vector3(0,-0.015,-0.23),"armor")
	r.part(knee,Vector3(0.36,0.56,0.36),Vector3(0,-0.35,0),"dark")
	r.panel(knee,[[-0.5,-0.30],[-0.5,0.27],[-0.32,0.5],[0.32,0.5],[0.5,0.27],[0.5,-0.30],[0.32,-0.5],[-0.32,-0.5]],Vector2(0.55,0.63),0.43,Vector3(0,-0.36,-0.08),"white")
	r.part(knee,Vector3(0.38,0.29,0.07),Vector3(0,-0.32,-0.33),"armor")
	r.vent(knee,Vector2(0.25,0.13),Vector3(0,-0.40,-0.39))
	r.part(knee,Vector3(0.14,0.43,0.31),Vector3(side*0.28,-0.35,0.04),"armor")
	r.part(ankle,Vector3(0.56,0.15,0.71),Vector3(0,-0.025,-0.13),"dark")
	for toe in [-1,1]: r.part(ankle,Vector3(0.25,0.21,0.45),Vector3(toe*0.145,0.05,-0.23),"armor")
	r.part(ankle,Vector3(0.51,0.18,0.25),Vector3(0,0.04,0.24),"white")
	r.joint(shoulder,0.19,0.38,Vector3.ZERO)
	var profile: Array = [[-0.5,-0.24],[-0.5,0.23],[-0.30,0.5],[0.30,0.5],[0.5,0.23],[0.5,-0.24],[0.28,-0.5],[-0.28,-0.5]]
	r.panel(shoulder,profile,Vector2(0.84,0.57),0.66,Vector3(side*0.10,0.10,0.01),"white")
	r.panel(shoulder,profile,Vector2(0.75,0.45),0.12,Vector3(side*0.10,0.10,-0.37),"armor")
	r.part(shoulder,Vector3(0.40,0.035,0.025),Vector3(side*0.10,0.11,-0.45),"light",Vector3.ZERO,false)
	r.part(shoulder,Vector3(0.31,0.30,0.32),Vector3(0,-0.30,0),"dark")
	r.part(shoulder,Vector3(0.37,0.25,0.22),Vector3(0,-0.29,-0.11),"armor")
	r.joint(elbow,0.14,0.37,Vector3.ZERO)
	r.part(elbow,Vector3(0.28,0.31,0.30),Vector3(0,-0.23,0),"dark")
	r.panel(elbow,profile,Vector2(0.47,0.54),0.34,Vector3(side*0.03,-0.18,-0.07),"white")
	r.part(elbow,Vector3(0.30,0.28,0.07),Vector3(side*0.03,-0.17,-0.29),"armor")

static func jet(r, parent: Node3D, at: Vector3, radius: float) -> void:
	var plume: MeshInstance3D = r.cylinder(parent,radius,0.32,at,"fire")
	plume.set_meta("dynamic_mesh",true); r.jets.append(plume)
