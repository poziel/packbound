shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform vec4 curse_color : source_color = vec4(0.36, 0.11, 0.58, 1.0);
uniform float pulse_strength = 0.18;
varying float phase;
void vertex() {
    phase = (MODEL_MATRIX * vec4(VERTEX, 1.0)).x * 0.6 + (MODEL_MATRIX * vec4(VERTEX, 1.0)).z * 0.31;
}
void fragment() {
    float breath = 1.0 - pulse_strength + pulse_strength * (0.5 + 0.5 * sin(TIME * 0.85 + phase));
    ALBEDO = curse_color.rgb * breath;
    EMISSION = curse_color.rgb * breath * 0.25;
}
