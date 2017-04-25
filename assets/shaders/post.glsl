uniform float u_exposure   = 1.0;
uniform vec3 u_white_point = vec3(1.0, 1.0, 1.0);
uniform float u_distortion;

vec3 Tonemap_ACES(vec3 x) {
	float a = 2.51;
	float b = 0.03;
	float c = 2.43;
	float d = 0.59;
	float e = 0.14;
	return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

vec4 effect(vec4 vcol, Image texture, vec2 texture_coords, vec2 screen_coords) {
	vec2  center = vec2(love_ScreenSize.x / 2.0, love_ScreenSize.y / 2.0);
	float aspect = love_ScreenSize.x / love_ScreenSize.y;
	float distance_from_center = distance(screen_coords, center);
	float power = 2.25;
	float offset = 2.0 - u_distortion;
	float fade = 1.0 - pow(distance_from_center / (center.x * offset), power);
	vec4 fg = vec4(vec3(fade), 1.0);

	vec3 texColor = Texel(texture, texture_coords).rgb;
	texColor *= max(u_exposure, 0.01);
	texColor = vec3(1.0) - exp(-texColor / u_white_point);

	vec3 color = Tonemap_ACES(texColor);
	return vec4(linearToGamma(color), 1.0) * fg;
}
