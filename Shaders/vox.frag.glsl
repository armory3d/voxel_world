#version 450

#include "../compiled.glsl"
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
	fragColor[0] = vec4(n.xy, packFloat(0.0, 1.0), 1.0 - gl_FragCoord.z);
	fragColor[1] = vec4(col, occ);
#else
	fragColor = vec4(col, 1.0);
#endif
}
