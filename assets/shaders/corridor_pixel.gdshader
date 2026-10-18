shader_type canvas_item;
render_mode unshaded;

uniform float color_steps : hint_range(8.0, 64.0, 1.0) = 48.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.15;
uniform bool enabled = true;
varying vec4 scene_tint;

void vertex() {
    scene_tint = COLOR;
}

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec3 color = source.rgb;
    if (enabled) {
        vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
        float bayer = mod(pixel.x, 2.0) * 2.0 + mod(pixel.y, 2.0);
        float threshold = (bayer + 0.5) / 4.0 - 0.5;
        color = floor(clamp(color + threshold * dither_strength / color_steps, vec3(0.0), vec3(1.0)) * color_steps + 0.5) / color_steps;
    }
    COLOR = vec4(color, source.a) * scene_tint;
}
