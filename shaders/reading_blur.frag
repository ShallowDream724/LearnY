#include <flutter/runtime_effect.glsl>

uniform vec2 u_field_origin;
uniform vec2 u_core_size;
uniform vec2 u_source_extent;
uniform vec2 u_texture_origin;
uniform float u_scale;
uniform float u_strength;
uniform vec3 u_base;
uniform vec3 u_gains;
uniform float u_visibility;
uniform sampler2D u_image;
out vec4 frag_color;

void main() {
  vec2 p = FlutterFragCoord().xy - vec2(32.0);
  float radius = min(14.0, min(u_core_size.x, u_core_size.y) * 0.5);
  vec2 q = abs(p - u_core_size * 0.5) - (u_core_size * 0.5 - vec2(radius));
  float distance = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
  float weight = (1.0 - smoothstep(0.0, 32.0, distance)) * u_visibility;
  if (weight <= 0.0) {
    frag_color = vec4(0.0);
    return;
  }
  // All fields sample the same native Gaussian texture. No sparse grid can
  // alias detailed wallpaper into repeated blocks as the field moves.
  vec2 position = u_field_origin + p;
  vec2 uv = (position - u_texture_origin) / (u_scale * u_source_extent);
  vec4 sample_color = texture(u_image, clamp(uv, vec2(0.0), vec2(1.0)));
  vec3 scene_color = sample_color.rgb * u_gains + (1.0 - sample_color.a) * u_base;
  scene_color = mix(u_base, scene_color, u_strength);
  frag_color = vec4(scene_color * weight, weight);
}
