shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // The same continuous depth field as the dungeon's stone surfaces.
    ALBEDO = vec3(0.0);
    ALPHA = smoothstep(7.0, 19.0, -world_position.z);
}
