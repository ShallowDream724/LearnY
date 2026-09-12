#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_radius;
uniform float u_dark;
uniform float u_strength;
out vec4 frag_color;

float gaussian(float value, float center, float spread) {
  float x = (value - center) / spread;
  return exp(-0.5 * x * x);
}

void main() {
  vec2 point = FlutterFragCoord().xy;
  vec2 p = point - u_size * 0.5;
  float radius = min(u_radius, min(u_size.x, u_size.y) * 0.5);
  vec2 spine = max(vec2(0.0), u_size * 0.5 - vec2(radius));
  vec2 radial = p - clamp(p, -spine, spine);
  float length_r = length(radial);
  vec2 normal = radial / max(length_r, 0.001);
  vec2 q = abs(p) - spine;
  float depth = radius - length(max(q, vec2(0.0))) - min(max(q.x, q.y), 0.0);
  float sides = pow(abs(normal.x), 3.0);

  // Curvature and light direction modulate soft fields, not a uniform outline.
  float upper_light = pow(max(dot(normal, normalize(vec2(-0.35, -1.0))), 0.0), 5.0);
  float lower_light = pow(max(normal.y, 0.0), 7.0);
  float along = 0.68 + 0.32 * gaussian(point.x, u_size.x * 0.28, u_size.x * 0.32);
  float rim = gaussian(depth, 0.65 + sides * 0.18, 0.34 + sides * 0.16);
  float light = rim * (0.14 + 0.48 * upper_light * along + 0.32 * lower_light);
  light += gaussian(depth, 1.8, 1.2) * 0.04 * upper_light;
  light *= mix(1.0, 0.57, u_dark);

  // Keep the transmitted interior clear. Depth comes from the exterior shadow
  // and this narrow reflection, without adding a second dark ring inside.
  light = clamp(light * u_strength, 0.0, 1.0);
  frag_color = vec4(vec3(light), light);
}
