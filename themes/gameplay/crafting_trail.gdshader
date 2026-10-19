shader_type canvas_item;
render_mode unshaded;

uniform float trail_length = 56.0;
uniform float clock = 0.0;
uniform vec4 tint : source_color;
uniform float strength = 0.0;
uniform float opacity = 1.0;
varying vec2 local_point;

float bend(float t) {
	return sin(t * PI) * sin(clock * 1.55) * 4.5 + sin(t * TAU) * sin(clock * 1.1 + 0.8) * 1.5;
}

void over(inout vec4 result, vec3 shade, float alpha) {
	result.rgb = shade * alpha + result.rgb * (1.0 - alpha);
	result.a = alpha + result.a * (1.0 - alpha);
}

float disc(float distance, float radius) {
	return 1.0 - smoothstep(radius - 0.5, radius + 0.5, distance);
}

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	float t = clamp(local_point.x / trail_length, 0.0, 1.0);
	float taper = smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.78, 1.0, t)) * opacity;
	float distance = abs(local_point.y - bend(t));
	vec4 result = vec4(0.0);
	vec3 white = vec3(0.9451, 1.0, 0.9765);
	for (int layer = 0; layer < 9; layer++) {
		float fraction = float(layer) / 8.0;
		float width = mix(24.0, 3.9, fraction);
		float alpha = mix(0.018, 0.18 + strength * 0.05, fraction * fraction);
		over(result, mix(tint.rgb, white, fraction * fraction * 0.82), taper * alpha * disc(distance, width * 0.5));
	}
	over(result, mix(tint.rgb, white, 0.45), taper * (0.48 + strength * 0.24) * disc(distance, 1.95));
	for (int bead = 0; bead < 2; bead++) {
		float travel = fract(clock * 0.55 + float(bead) * 0.5);
		vec2 spark = vec2(travel * trail_length, bend(travel));
		float alpha = opacity * smoothstep(0.0, 0.18, travel) * (1.0 - smoothstep(0.68, 1.0, travel));
		float radius = length(local_point - spark);
		over(result, white, alpha * 0.7 * disc(radius, 1.15));
		for (int layer = 0; layer < 5; layer++) {
			float fraction = float(layer) / 4.0;
			over(result, mix(tint.rgb, white, fraction), alpha * (0.035 + float(layer) * 0.025) * disc(radius, 4.5 - float(layer) * 0.65));
		}
	}
	COLOR = vec4(result.rgb / max(result.a, 0.00001), result.a);
}
