shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.72, 0.2, 1.0);
uniform float outline_width : hint_range(1.0, 8.0) = 4.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float alpha = tex_color.a;
    float outline_alpha = 0.0;

    // Pulsation lente du halo
    float pulse = 0.5 + 0.5 * sin(TIME * 3.5);

    // Le contour respire légèrement
    float width_pulse = 0.85 + pulse * 0.3;
    vec2 pixel_size = TEXTURE_PIXEL_SIZE * outline_width * width_pulse;

    for (int x = -4; x <= 4; x++) {
        for (int y = -4; y <= 4; y++) {
            if (x == 0 && y == 0) {
                continue;
            }

            vec2 offset = vec2(float(x), float(y)) * pixel_size;
            float neighbor_alpha = texture(TEXTURE, UV + offset).a;
            outline_alpha = max(outline_alpha, neighbor_alpha);
        }
    }

    float outline = max(0.0, outline_alpha - alpha);

    // La luminosité du contour varie avec la pulsation
    vec3 halo_color = outline_color.rgb * (0.85 + pulse * 0.35);

    COLOR = vec4(
        mix(tex_color.rgb, halo_color, outline),
        max(alpha, outline * outline_color.a)
    );
}