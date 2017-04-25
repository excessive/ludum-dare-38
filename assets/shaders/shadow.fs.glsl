#ifdef PIXEL // DO NOT REMOVE
varying vec4 VaryingColor;
varying vec4 VaryingTexCoord;
varying vec4 f_position;

#ifdef PACKED_DEPTH
vec4 packFloatToRgba(float _value)
{
	const vec4 shift = vec4(256 * 256 * 256, 256 * 256, 256, 1.0);
	const vec4 mask = vec4(0, 1.0 / 256.0, 1.0 / 256.0, 1.0 / 256.0);
	vec4 comp = fract(_value * shift);
	comp -= comp.xxyz * mask;
	return comp;
}
#endif

// look, just trust me on this one
void main() {
	float depthScale = 0.5;
	float depthOffset = 0.5;
	float depth = f_position.z * depthScale + depthOffset;
#ifdef PACKED_DEPTH
	gl_FragColor = packFloatToRgba(depth);
#else
	gl_FragColor = vec4(depth, 0.0, 0.0, 1.0);
#endif
}
#endif
