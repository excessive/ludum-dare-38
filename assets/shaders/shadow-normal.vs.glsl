#ifdef VERTEX // DO NOT REMOVE
varying vec4 VaryingColor;
varying vec4 VaryingTexCoord;
varying vec4 f_position;

attribute vec4 VertexPosition;
attribute vec4 VertexWeight;
attribute vec4 VertexBone;

uniform mat4 u_light_view, u_model, u_light_projection;

void main() {
	VaryingColor    = vec4(1.0);
	VaryingTexCoord = vec4(0.0);
	gl_Position = u_light_projection * u_light_view * u_model * VertexPosition;
	f_position = gl_Position;
}
#endif
