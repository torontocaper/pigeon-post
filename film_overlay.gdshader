shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float time;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.25;
uniform float contrast       : hint_range(0.5, 2.0) = 1.1;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_radius   : hint_range(0.0, 1.0) = 0.75;
uniform vec2 viewport_size = vec2(1920.0, 1080.0);

//
// --- helpers -----------------------------------------------------------
//
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

//
// --- main --------------------------------------------------------------
//
void fragment() {
    // Normalized coordinates across the full viewport
    vec2 uv = FRAGCOORD.xy / viewport_size;

    // Sample the screen explicitly in viewport space (prevents “spotlight” bug)
    vec4 col = texture(SCREEN_TEXTURE, uv);

    // Convert to grayscale
    float gray = dot(col.rgb, vec3(0.3, 0.59, 0.11));

    // Organic, drifting grain
    vec2 grain_uv = uv * 300.0 + vec2(time * 20.0, time * 10.0);
    float grain = smooth_noise(grain_uv);
    grain += 0.5 * smooth_noise(grain_uv * 0.5 + 10.0);
    gray += (grain - 0.5) * grain_strength;

    // Properly centered vignette (aspect-correct)
    vec2 centered_uv = (FRAGCOORD.xy - 0.5 * viewport_size) / viewport_size;
    centered_uv.x *= viewport_size.x / viewport_size.y; // preserve circular shape
    float dist = length(centered_uv);
    float vignette = smoothstep(vignette_radius, vignette_radius + 0.25, dist);
    gray *= mix(1.0, 1.0 - vignette_strength, vignette);

    // Gentle flicker
    float flicker = 1.0 + sin(time * 6.2831 * 1.3) * 0.03;
    gray *= flicker;

    // Contrast adjustment
    gray = pow(gray, 1.0 / contrast);

    COLOR = vec4(vec3(gray), 1.0);
}
