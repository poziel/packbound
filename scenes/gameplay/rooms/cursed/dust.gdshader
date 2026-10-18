shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, cull_disabled;
uniform vec4 dust_color : source_color = vec4(0.47, 0.36, 0.64, 0.19);
void vertex() {
    float phase = MODEL_MATRIX[3].x * 2.13 + MODEL_MATRIX[3].z * 0.51;
    VERTEX.x += sin(TIME * 0.19 + phase) * 0.18;
    VERTEX.y += sin(TIME * 0.13 + phase * 1.7) * 0.24;
}
void fragment() {
    ALBEDO = dust_color.rgb;
    ALPHA = dust_color.a;
}
