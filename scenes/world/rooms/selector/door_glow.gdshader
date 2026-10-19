shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float strength : hint_range(0.0, 1.0) = 0.015;
uniform vec4 glow_color : source_color = vec4(0.48, 0.68, 0.88, 1.0);

void fragment() {
	vec2 edge = min(UV, 1.0 - UV);
	float mask = smoothstep(0.0, 0.23, edge.x) * smoothstep(0.0, 0.18, edge.y);
	ALBEDO = glow_color.rgb;
	ALPHA = mask * strength;
}
