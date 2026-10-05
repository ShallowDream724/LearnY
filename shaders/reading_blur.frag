#include <flutter/runtime_effect.glsl>

uniform vec2 u_field_origin;
uniform vec2 u_core_size;
uniform vec2 u_source_extent;
uniform vec2 u_texture_origin;
uniform float u_scale;
uniform float u_strength;
uniform vec3 u_base;
uniform vec3 u_gains;
uniform sampler2D u_image;
out vec4 frag_color;

float kernel(int i) {
  float distance = abs(float(i));
  return distance == 0.0 ? 2.0 : 1.0;
}

void main() {
  vec2 p = FlutterFragCoord().xy - vec2(32.0);
  float radius = min(14.0, min(u_core_size.x, u_core_size.y) * 0.5);
  vec2 q = abs(p - u_core_size * 0.5) - (u_core_size * 0.5 - vec2(radius));
  float distance = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
  float weight = 1.0 - smoothstep(0.0, 32.0, distance);
  if (weight <= 0.0) {
    frag_color = vec4(0.0);
    return;
  }
  // Blur radius, not a white tint, dissolves towards the original wallpaper.
  float step_size = 6.0 * weight;
  vec4 sample_color = vec4(0.0);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 position = u_field_origin + p + vec2(float(x), float(y)) * step_size;
      vec2 uv = (position - u_texture_origin) / (u_scale * u_source_extent);
      sample_color += texture(u_image, clamp(uv, vec2(0.0), vec2(1.0))) * kernel(x) * kernel(y);
    }
  }
  sample_color /= 16.0;
  vec3 scene_color = sample_color.rgb * u_gains + (1.0 - sample_color.a) * u_base;
  scene_color = mix(u_base, scene_color, u_strength);
  frag_color = vec4(scene_color * weight, weight);
}
