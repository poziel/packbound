shader_type spatial;
render_mode diffuse_burley;

uniform vec4 stone_color : source_color = vec4(0.29, 0.32, 0.34, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.075, 0.085, 0.095, 1.0);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec2 point = abs(world_normal.x) > abs(world_normal.z) ? world_position.zy : world_position.xy;
	vec2 block_size = vec2(0.95, 0.48);
	if (abs(world_normal.y) > 0.6) {
		point = world_position.xz;
		block_size = vec2(1.15, 0.85);
	}
	float row = floor(point.y / block_size.y);
	vec2 grid = vec2(point.x / block_size.x + mod(row, 2.0) * 0.5, point.y / block_size.y);
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	vec2 edge = min(local, 1.0 - local) * block_size;
	float joint = step(0.018, min(edge.x, edge.y));
	float bevel = mix(0.70, 1.0, step(0.042, min(edge.x, edge.y)));
	float variation = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = mix(mortar_color.rgb, stone_color.rgb * (0.83 + variation * 0.22) * bevel, joint);
	ROUGHNESS = 0.98;
	SPECULAR = 0.12;
}
