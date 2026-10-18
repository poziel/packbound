shader_type canvas_item;
render_mode unshaded;

uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ink : source_color = vec4(0.039, 0.059, 0.090, 1.0);
uniform float pixel_size : hint_range(1.0, 8.0) = 3.0;
uniform vec2 canvas_size = vec2(1280.0, 720.0);

// Ordered 8x8 Bayer ranks: stable integer pixels, with 64 coverage levels.
float bayer_rank(ivec2 cell) {
	float rank = 0.0;
	for (int bit = 0; bit < 3; bit++) {
		int x = (cell.x >> bit) & 1;
		int y = (cell.y >> bit) & 1;
		int quadrant = ((x ^ y) * 2) + y;
		rank = rank * 4.0 + float(quadrant);
	}
	return (rank + 0.5) / 64.0;
}

void fragment() {
	ivec2 cell = ivec2(floor(UV * canvas_size / pixel_size));
	float mask = step(bayer_rank(cell), coverage);
	COLOR = vec4(ink.rgb, mask);
}
