shader_type canvas_item;

const vec4 outline_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 base_tex = texture(TEXTURE, UV);
	if (base_tex.a > 0.0) {
		COLOR = base_tex;
	} else {
		vec2 image_size_px = TEXTURE_PIXEL_SIZE;
		bool valid_side = 
			texture(TEXTURE, UV + vec2(-image_size_px.x, 0)).a > 0.0 ||
			texture(TEXTURE, UV + vec2(image_size_px.x, 0)).a > 0.0 ||
			texture(TEXTURE, UV + vec2(0, -image_size_px.y)).a > 0.0 ||
			texture(TEXTURE, UV + vec2(0, image_size_px.y)).a > 0.0;
		bool valid_corner = 
			texture(TEXTURE, UV + vec2(-image_size_px.x, -image_size_px.y)).a > 0.0 ||
			texture(TEXTURE, UV + vec2(image_size_px.x, -image_size_px.y)).a > 0.0 ||
			texture(TEXTURE, UV + vec2(-image_size_px.x, image_size_px.y)).a > 0.0 ||
			texture(TEXTURE, UV + vec2(image_size_px.x, image_size_px.y)).a > 0.0;
		if (valid_side || valid_corner) {
			COLOR = outline_color;
		}
	}
}