#version 450

#include "../compiled.inc"

in vec4 pos;
in vec2 nor;
in vec2 tex;
in vec3 ipos;

uniform mat4 WVP;
uniform int s;
uniform int s2;
uniform sampler3D volume;

out vec2 tc;
out vec3 normal;
#ifdef _Deferred
out float occ;
#endif

void main() {

	if (ipos.x == 0.0) {
		gl_Position.x = -1000;
		gl_Position.y = -1000;
		return;
	}

	tc = tex + ipos.xy;
	normal = vec3(nor.xy, pos.w);

	int i = gl_InstanceID % s2;
	ivec3 pi;
	pi.x = i % s;
	pi.y = int(i / s);
	pi.z = int(gl_InstanceID / s2);

#ifdef _Deferred
	ivec3 posn = ivec3(pos.xyz * 2.1);

	float a;
	float b;
	float c = texelFetch(volume, ivec3(pi.x + posn.x, pi.y + posn.y, pi.z + posn.z), 0).r;;

	// Unify this..
	if (abs(pos.w) > 0.1) { // nor.z
		a = texelFetch(volume, ivec3(pi.x + posn.x, pi.y,          pi.z + posn.z), 0).r;
		b = texelFetch(volume, ivec3(pi.x,          pi.y + posn.y, pi.z + posn.z), 0).r;
	}
	else if (abs(nor.x) > 0.1) {
		a = texelFetch(volume, ivec3(pi.x + posn.x, pi.y + posn.y, pi.z), 0).r;
		b = texelFetch(volume, ivec3(pi.x + posn.x, pi.y,          pi.z + posn.z), 0).r;
	}
	else {
		a = texelFetch(volume, ivec3(pi.x + posn.x, pi.y + posn.y, pi.z), 0).r;
		b = texelFetch(volume, ivec3(pi.x,          pi.y + posn.y, pi.z + posn.z), 0).r;
	}

	occ = (3.0 - (a + b + c)) / 3.0;
	occ = max(occ, 0.2);
#endif

	gl_Position = WVP * vec4(pos.xyz + pi, 1.0);
}
