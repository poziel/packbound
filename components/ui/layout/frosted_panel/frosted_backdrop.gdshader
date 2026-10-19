shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 tint : source_color = vec4(0.063, 0.082, 0.122, 1.0);
uniform vec4 border_color : source_color = vec4(0.333, 0.365, 0.424, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.82;
uniform float blur_radius : hint_range(0.0, 12.0) = 4.0;
uniform float corner_radius = 8.0;
uniform float pixel_step = 2.0;
uniform float border_width = 2.0;
uniform vec2 panel_size = vec2(1.0);

float rounded_mask(vec2 p, vec2 dimensions, float radius) {
	if (any(lessThan(p, vec2(0.0))) || any(greaterThanEqual(p, dimensions))) {
		return 0.0;
	}
	vec2 delta = max(abs(p - dimensions * 0.5) - (dimensions * 0.5 - vec2(radius)), vec2(0.0));
	return step(dot(delta, delta), radius * radius);
}

void fragment() {
	vec2 p = floor(UV * panel_size / pixel_step) * pixel_step + vec2(pixel_step * 0.5);
	float outer = rounded_mask(p, panel_size, corner_radius);
	float inner = rounded_mask(p - vec2(border_width), panel_size - vec2(border_width * 2.0), max(0.0, corner_radius - border_width));
	vec2 d = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 blurred = texture(screen_texture, SCREEN_UV).rgb * 4.0;
	blurred += texture(screen_texture, SCREEN_UV + vec2(d.x, 0.0)).rgb * 2.0;
	blurred += texture(screen_texture, SCREEN_UV - vec2(d.x, 0.0)).rgb * 2.0;
	blurred += texture(screen_texture, SCREEN_UV + vec2(0.0, d.y)).rgb * 2.0;
	blurred += texture(screen_texture, SCREEN_UV - vec2(0.0, d.y)).rgb * 2.0;
	blurred += texture(screen_texture, SCREEN_UV + d).rgb;
	blurred += texture(screen_texture, SCREEN_UV - d).rgb;
	blurred += texture(screen_texture, SCREEN_UV + vec2(d.x, -d.y)).rgb;
	blurred += texture(screen_texture, SCREEN_UV + vec2(-d.x, d.y)).rgb;
	vec3 surface = mix(blurred / 16.0, tint.rgb, opacity);
	COLOR = vec4(mix(border_color.rgb, surface, inner), outer);
}
