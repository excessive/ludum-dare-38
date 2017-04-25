attribute vec3 VertexNormal;

varying vec3 f_normal;
varying vec3 f_position;
varying vec4 f_shadow_coords;

uniform mat4 u_model, u_view, u_projection;
uniform mat4 u_shadow_vp;
uniform vec3 u_camera_position;

uniform float u_distortion;
uniform float u_time;

vec4 position(mat4 _, vec4 vertex) {
	f_normal = mat3(u_model) * VertexNormal;
	f_shadow_coords = u_shadow_vp * u_model * vertex;

	vec4 pos = u_view * u_model * vertex;

	pos.x += sin(u_time) * u_distortion + cos(u_time / 2.0 + pos.y) * u_distortion;
	pos.z += cos(u_time) * u_distortion + sin(u_time / 2.0 + pos.y) * u_distortion;
	pos.x += cos(u_time + pos.z * 0.5) * u_distortion * 0.25;

	f_position = -pos.xyz;

	return u_projection * pos;
}
