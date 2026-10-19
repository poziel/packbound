shader_type canvas_item;
render_mode unshaded;
uniform vec4 accent : source_color;
varying vec4 item_modulate;

void vertex() {
	item_modulate = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE;
	float adjacent = max(max(texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a,
		texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a));
	COLOR = item_modulate * (pixel.a > 0.01 ? pixel : vec4(accent.rgb, adjacent * accent.a));
}
