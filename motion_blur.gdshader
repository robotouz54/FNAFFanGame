shader_type canvas_item;

uniform vec2 motion_vector = vec2(0.0);
const int SAMPLE_COUNT = 9;

void fragment() {
	vec4 blurred_color = vec4(0.0);

	for (int i = 0; i < SAMPLE_COUNT; i++) {
		float sample_position = float(i) / float(SAMPLE_COUNT - 1);
		blurred_color += texture(TEXTURE, UV - motion_vector * sample_position);
	}

	COLOR = blurred_color / float(SAMPLE_COUNT);
}
