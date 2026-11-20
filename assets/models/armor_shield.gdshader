shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
uniform float impact = 0.0;
uniform vec3 incoming = vec3(-1.0, 0.0, 0.0);
varying vec3 world_normal;
void vertex() {
    VERTEX += NORMAL * 0.022;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    float hit_side = smoothstep(0.2, 0.65, dot(normalize(world_normal), incoming));
    ALBEDO = vec3(0.32, 0.83, 1.0);
    ALPHA = strength * 0.12 + impact * hit_side * 0.8;
}
