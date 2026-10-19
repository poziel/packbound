shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform mat4 world_to_stairs;
uniform bool entrance = false;
uniform float run_length = 11.9;
varying vec3 world_position;
uniform vec4 depth_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float depth_strength = 1.0;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec3 p = (world_to_stairs * vec4(world_position, 1.0)).xyz;
    float depth = entrance ? p.z : -p.z;
    ALBEDO = depth_color.rgb;
    ALPHA = clamp(smoothstep(0.0, run_length * 0.95, depth) * depth_strength, 0.0, 1.0);
}
