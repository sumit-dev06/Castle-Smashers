shader_type canvas_item;
// Softens the realm painting so the sharp play area reads in front of it (reference look):
// The texture is pre-downscaled on the CPU (Background.soft_texture), which gives the blur; linear
// upscaling keeps it smooth. This adds lower saturation and haze that gets stronger toward the bottom.

uniform vec4 haze_color : source_color = vec4(0.85, 0.9, 1.0, 1.0);
uniform float haze = 0.16;
uniform float haze_bottom = 0.1;
uniform float saturation = 0.86;
uniform float brightness = 1.0;

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, saturation) * brightness;
	c = mix(c, haze_color.rgb, clamp(haze + haze_bottom * UV.y, 0.0, 1.0));
	COLOR = vec4(c, 1.0);
}
