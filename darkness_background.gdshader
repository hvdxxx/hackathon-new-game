shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5); // Цвет тени (черный с прозрачностью)

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    // Затемняем исходный цвет текстуры
    COLOR = vec4(tex_color.rgb * shadow_color.rgb, tex_color.a * shadow_color.a);
}