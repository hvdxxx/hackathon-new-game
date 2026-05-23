shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.7); // Цвет тени (черный с прозрачностью)

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    // Затемняем исходный цвет текстуры
    COLOR = vec4(tex_color.rgb * shadow_color.rgb, tex_color.a * shadow_color.a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
