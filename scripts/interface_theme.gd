extends RefCounted
## Armored command surfaces. Vector skins keep their cuts at every button width.
const PANEL = preload("res://assets/free/ui/facility_panel.png")
const MINT := Color("8cdec3")
const CRIMSON := Color("ff5368")
const GOLD := Color("e9c78e")
static var skin_cache: Dictionary = {}

static func surface(texture: Texture2D, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	style.texture_margin_left = 16; style.texture_margin_right = 16
	style.texture_margin_top = 16; style.texture_margin_bottom = 16
	style.content_margin_left = 16; style.content_margin_right = 16
	style.content_margin_top = 0; style.content_margin_bottom = 0
	return style

static func _skin(kind: String, mode: String, accent: Color) -> StyleBoxTexture:
	var key := kind+"/"+mode+"/"+accent.to_html()
	if skin_cache.has(key): return skin_cache[key]
	var fill := Color("14222f")
	var edge := Color("455968")
	var light := accent
	if kind=="primary": fill = Color("17212e").lerp(accent,0.25); edge = accent.darkened(0.18)
	if kind=="launch": fill = Color("15212e").lerp(accent,0.63); edge = accent.lightened(0.12)
	if kind=="facility": fill = Color("172a36"); edge = accent.darkened(0.48)
	if mode=="hover": fill = fill.lightened(0.13); edge = accent.lightened(0.24)
	if mode=="pressed": fill = fill.darkened(0.24); edge = accent; light = accent.lightened(0.35)
	if mode=="disabled": fill = Color("151e27"); edge = Color("303d48"); light = Color("53616c")
	var focus := mode=="focus"
	if focus: edge = GOLD
	var width := 160
	var height := 64
	var cut := 12
	var shape := "M 14 1 H 159 V 50 L 146 63 H 1 V 14 Z"
	var bevel := "M 17 6 H 153 M 6 18 V 57 H 142 L 153 46"
	if kind=="facility":
		height = 96; cut = 22
		shape = "M 1 1 H 136 L 159 24 V 95 H 24 L 1 72 Z"
		bevel = "M 8 7 H 133 L 153 27 M 8 68 L 28 89 H 151"
	elif kind=="launch":
		width = 256; height = 96; cut = 24
		shape = "M 24 1 H 230 L 255 26 V 70 L 230 95 H 24 L 1 72 V 24 Z"
		bevel = "M 27 7 H 226 L 249 29 M 7 27 V 69 L 27 89 H 226"
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [width,height,width,height]
	if focus:
		svg += '<path d="%s" fill="none" stroke="#%s" stroke-width="2.5"/>' % [shape,edge.to_html(false)]
	else:
		svg += '<path d="%s" fill="#%s" stroke="#%s" stroke-width="1.5"/>' % [shape,fill.to_html(false),edge.to_html(false)]
		svg += '<path d="%s" fill="none" stroke="#%s" stroke-opacity="0.28" stroke-width="1"/>' % [bevel,light.to_html(false)]
		if kind=="launch":
			# The fixed right cap reads as a deployment direction, not a generic card.
			svg += '<path d="M 219 24 L 237 48 L 219 72 M 229 24 L 247 48 L 229 72" fill="none" stroke="#%s" stroke-opacity="0.65" stroke-width="3"/>' % ("53616c" if mode=="disabled" else "fff2e6")
			svg += '<path d="M 20 23 L 30 13 H 58 M 20 73 L 30 83 H 58" fill="none" stroke="#%s" stroke-opacity="0.55" stroke-width="2"/>' % light.to_html(false)
		elif kind=="facility":
			svg += '<path d="M 16 2 H 47 L 43 6 H 12 Z" fill="#%s"/>' % light.to_html(false)
			svg += '<path d="M 144 78 H 150 M 140 83 H 150" stroke="#%s" stroke-opacity="0.65" stroke-width="2"/>' % light.to_html(false)
		else:
			svg += '<path d="M 3 20 V 40" stroke="#%s" stroke-width="3"/>' % light.to_html(false)
			svg += '<path d="M 139 59 L 149 49" stroke="#%s" stroke-opacity="0.65" stroke-width="2"/>' % light.to_html(false)
		if mode=="pressed":
			svg += '<path d="M %d %d H %d" stroke="#%s" stroke-width="2"/>' % [cut,height-5,width-cut,light.to_html(false)]
	svg += "</svg>"
	var picture := Image.new()
	var error := picture.load_svg_from_string(svg)
	if error!=OK: push_error("Command skin could not be rendered: "+key)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(picture)
	# Fixed corners and end caps stay crisp while only the central plate stretches.
	style.texture_margin_left = 32 if kind=="launch" else 26 if kind=="facility" else 18
	style.texture_margin_right = 48 if kind=="launch" else 26 if kind=="facility" else 18
	style.texture_margin_top = 28 if kind in ["facility","launch"] else 18
	style.texture_margin_bottom = style.texture_margin_top
	style.content_margin_left = 22 if kind=="launch" else 16
	style.content_margin_right = 48 if kind=="launch" else 16
	style.content_margin_top = 0; style.content_margin_bottom = 0
	style.set_meta("armor_variant",kind)
	style.set_meta("interaction_state",mode)
	skin_cache[key] = style
	return style

static func _apply(control: Button, kind: String, accent: Color) -> void:
	control.set_meta("armor_variant",kind)
	for mode in ["normal","hover","pressed","disabled","focus","hover_pressed"]:
		control.add_theme_stylebox_override(mode,_skin(kind,"pressed" if mode=="hover_pressed" else mode,accent))
	control.add_theme_color_override("font_disabled_color",Color("687984"))
	control.add_theme_color_override("font_focus_color",Color("fff0d7"))
	control.add_theme_color_override("font_hover_pressed_color",Color.WHITE)
	control.add_theme_color_override("font_shadow_color",Color(0.02,0.03,0.06,0.6))
	control.add_theme_constant_override("shadow_offset_y",1)
	control.add_theme_constant_override("outline_size",0)

static func button(control: Button, primary: bool, accent: Color) -> void:
	_apply(control,"primary" if primary else "standard",accent if primary else Color("769fa8"))

static func facility(control: Button, accent: Color = MINT) -> void:
	_apply(control,"facility",accent)

static func launch(control: Button, accent: Color = CRIMSON) -> void:
	_apply(control,"launch",accent)

static func panel(control: Panel, tint: Color = Color("27364b")) -> void:
	control.add_theme_stylebox_override("panel",surface(PANEL,tint))

static func compact(control: Button, accent: Color = MINT, round_icon: bool = false) -> void:
	# Instrument keys have a quiet rounded face; their hit rectangle remains unchanged.
	control.set_meta("armor_variant","instrument" if round_icon else "compact")
	for mode in ["normal","hover","pressed","disabled","focus","hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.045,0.08,0.12,0.94)
		style.border_color = Color(accent,0.45)
		style.set_border_width_all(1)
		style.border_width_bottom = 3 if not round_icon else 1
		style.set_corner_radius_all(40 if round_icon else 6)
		style.corner_radius_top_right = 40 if round_icon else 16
		style.corner_radius_bottom_left = 40 if round_icon else 16
		style.expand_margin_top = -6; style.expand_margin_bottom = -6
		style.content_margin_left = 10; style.content_margin_right = 10
		style.content_margin_top = 0; style.content_margin_bottom = 0
		if mode=="hover": style.bg_color = Color("213947"); style.border_color = accent
		if mode in ["pressed","hover_pressed"]: style.bg_color = Color("0c1821"); style.border_color = accent; style.border_width_bottom = 1; style.border_width_top = 3
		if mode=="disabled": style.bg_color = Color(0.04,0.06,0.09,0.72); style.border_color = Color("33414d")
		if mode=="focus": style.bg_color = Color.TRANSPARENT; style.border_color = GOLD; style.set_border_width_all(2)
		style.set_meta("armor_variant","instrument" if round_icon else "compact")
		style.set_meta("interaction_state",mode)
		control.add_theme_stylebox_override(mode,style)
	control.add_theme_font_size_override("font_size",18)
	control.clip_text = true
