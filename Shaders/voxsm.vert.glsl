#version 450

in vec4 pos;
in vec3 ipos;

uniform mat4 LWVP;
uniform int s;
uniform int s2;

void main() {

	if (ipos.x == 0.0) {
		gl_Position.x = -1000;
		gl_Position.y = -1000;
		return;
	}

	vec3 p = pos.xyz;
	int i = gl_InstanceID % s2;
	p.x += i % s;
	p.y += int(i / s);
	p.z += int(gl_InstanceID / s2);

	gl_Position = LWVP * vec4(p, 1.0);
}
