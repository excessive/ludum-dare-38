varying vec3 f_normal;
varying vec3 f_position;
varying vec4 f_shadow_coords;

uniform vec3 u_light_direction;
uniform vec3 u_light_color;
uniform vec3 u_fog_color;

uniform vec2 u_clips;

#define PACKED_DEPTH
#ifdef PACKED_DEPTH
uniform sampler2D u_shadow_texture;
#else
uniform sampler2DShadow u_shadow_texture;
#endif
uniform vec3 u_camera_position;

uniform float u_roughness = 0.25;

float unpackRgbaToFloat(vec4 _rgba)
{
	const vec4 shift = vec4(1.0 / (256.0 * 256.0 * 256.0), 1.0 / (256.0 * 256.0), 1.0 / 256.0, 1.0);
	return dot(_rgba, shift);
}

// http://prideout.net/blog/?p=22
float stepmix(float edge0, float edge1, float E, float x) {
	float T = clamp(0.5 * (x - edge0 + E) / E, 0.0, 1.0);
	return mix(edge0, edge1, T);
}

float ggx_specular(vec3 L, vec3 V, vec3 N, float roughness, float fresnel) {
	vec3 H = normalize(L-V);

	float dotNL = max(dot(N,L), 0.0);
	float dotLH = max(dot(L,H), 0.0);
	float dotNH = max(dot(N,H), 0.0);

	float alpha = roughness * roughness;
	float alphaSqr = alpha * alpha;
	float denom = dotNH * dotNH *(alphaSqr-1.0) + 1.0;
	float D = alphaSqr/(3.141592653589793 * denom * denom);

	float dotLH5 = pow(1.0-dotLH,5.0);
	float F = fresnel + (1.0-fresnel) * (dotLH5);

	float k = alpha * 0.5;
	float g1v = 1.0/(dotLH*(1.0-k)+k);
	float Vs = g1v * g1v;

	return dotNL * D * F * Vs;
}

vec2 poissonDisk[16] = vec2[]( 
	vec2( -0.94201624, -0.39906216 ), 
	vec2( 0.94558609, -0.76890725 ), 
	vec2( -0.094184101, -0.92938870 ), 
	vec2( 0.34495938, 0.29387760 ), 
	vec2( -0.91588581, 0.45771432 ), 
	vec2( -0.81544232, -0.87912464 ), 
	vec2( -0.38277543, 0.27676845 ), 
	vec2( 0.97484398, 0.75648379 ), 
	vec2( 0.44323325, -0.97511554 ), 
	vec2( 0.53742981, -0.47373420 ), 
	vec2( -0.26496911, -0.41893023 ), 
	vec2( 0.79197514, 0.19090188 ), 
	vec2( -0.24188840, 0.99706507 ), 
	vec2( -0.81409955, 0.91437590 ), 
	vec2( 0.19984126, 0.78641367 ), 
	vec2( 0.14383161, -0.14100790 ) 
);

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
	vec3 light = normalize(u_light_direction);
	vec3 normal = normalize(f_normal);

	// diffuse lighting
	float shade = max(dot(normal, light), 0.0);

	// fresnel
	float F0 = u_roughness;
	float base = 1.0 - dot(normalize(f_normal), normalize(light + f_position));
	float exponential = pow(base, 5.0);
	float fresnel = max(0.0, exponential + F0 * (1.0 - exponential));

	// specular
	float spec = ggx_specular(light, normalize(u_camera_position), normal, F0, fresnel);
	shade += spec;

	// shadows
	// float bias = 0.001;
	float ndl = clamp(dot(light, normal), 0.0, 1.0);
	float bias = clamp(0.001 * tan(acos(ndl)), 0.0, 0.01);
#ifdef PACKED_DEPTH
	// Sample the shadow map 4 times
	float illuminated = 1.0;
	int steps = 16;
	for (int i = 0; i < steps; i++) {
		int index = i;

		float depth = texture2D(u_shadow_texture, f_shadow_coords.xy + poissonDisk[index]/2048.0).r;
		float visibility = 1.0 - step(f_shadow_coords.z - bias, depth);
		illuminated -= visibility * (1.0/float(steps));
	}
	illuminated = clamp(illuminated, 0.0, 1.0);
#else
	float illuminated = shadow2DProj(u_shadow_texture, f_shadow_coords).z;
#endif
	spec  *= illuminated;
	shade *= illuminated;

	// ambient
	vec3 top = vec3(0.1, 0.4, 1.0);
	vec3 bottom = vec3(0.0, 0.0, 0.0);
	vec3 ambient = mix(top, bottom, dot(f_normal, vec3(0.0, 0.0, -1.0)) * 0.5 + 0.5);
	ambient *= color.rgb;

	// combine diffuse with light info
	vec3 diffuse = Texel(tex, uv).rgb * color.rgb * vec3(shade);
	diffuse *= u_light_color;
	diffuse += ambient;

	// mix ambient beyond the terminator
	vec3 out_color = mix(ambient.rgb, diffuse.rgb, clamp(dot(light, normal) + 0.2, 0.0, 1.0));

	// fog
	float depth = 1.0 / gl_FragCoord.w;
	float scaled = (depth - u_clips.x) / (u_clips.y - u_clips.x);
	scaled = pow(scaled, 1.6);

	out_color.rgb = mix(out_color.rgb, u_fog_color.rgb, min(scaled, 1.0));
	return vec4(out_color.rgb, 1.0);
}
