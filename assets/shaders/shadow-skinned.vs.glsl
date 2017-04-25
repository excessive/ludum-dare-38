#ifdef VERTEX // DO NOT REMOVE
varying vec4 VaryingColor;
varying vec4 VaryingTexCoord;
varying vec4 f_position;

attribute vec4 VertexPosition;
attribute vec4 VertexWeight;
attribute vec4 VertexBone;

uniform mat4 u_light_projection, u_light_view, u_model;
uniform mat4 u_pose[120];

void main() {
	mat4 transform =
		u_pose[int(VertexBone.x*255.0)] * VertexWeight.x +
		u_pose[int(VertexBone.y*255.0)] * VertexWeight.y +
		u_pose[int(VertexBone.z*255.0)] * VertexWeight.z +
		u_pose[int(VertexBone.w*255.0)] * VertexWeight.w;

	transform = u_model * transform;

	VaryingColor    = vec4(1.0);
	VaryingTexCoord = vec4(0.0);

	gl_Position = u_light_projection * u_light_view * transform * VertexPosition;
	f_position = gl_Position;
}
#endif
