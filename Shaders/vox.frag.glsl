#version 450

#include "../compiled.inc"
#include "../std/gbuffer.glsl"

uniform sampler2D tileset;

in vec2 tc;
in vec3 normal;
#ifdef _Deferred
in float occ;
#endif

#ifdef _Deferred
out vec4 fragColor[2];
#else
out vec4 fragColor;
#endif

void main() {

	vec3 n = normalize(normal);

	n /= (abs(n.x) + abs(n.y) + abs(n.z));
    n.xy = n.z >= 0.0 ? n.xy : octahedronWrap(n.xy);

	vec3 col = texture(tileset, tc).rgb;

#ifdef _Deferred
	fragColor[0] = vec4(n.xy, 1.0, packFloatInt16(0.0, 0, 4));
	fragColor[1] = vec4(col, packFloat2(occ, 0.0));
#else
	fragColor = vec4(col, 1.0);
#endif
}
