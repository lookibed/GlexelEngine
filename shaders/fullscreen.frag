#version 430 core

in vec2 v_uv;

out vec4 out_color;

uniform float u_time;
uniform vec2 u_resolution;

void main() {
  vec2 uv = v_uv;

  vec3 a = vec3(0.04, 0.05, 0.09);
  vec3 b = vec3(0.25, 0.10, 0.40);
  vec3 c = vec3(0.10, 0.45, 0.85);

  float wave = sin((uv.x + uv.y) * 16.0 + u_time * 3.0) * 0.5 + 0.5;
  float pulse = sin(u_time * 2.0) * 0.5 + 0.5;

  vec3 color = mix(a, b, uv.y);
  color = mix(color, c, wave * 0.35);
  color += pulse * vec3(0.04, 0.02, 0.08);

  out_color = vec4(color, 1.0);
}
