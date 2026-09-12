#include <flutter/runtime_effect.glsl>

// ImageFilter supplies u_size and u_backdrop; the pane supplies its geometry.
// This never samples a separate wallpaper or requires CPU screenshots.
uniform vec2 u_size;
uniform vec2 u_origin;
uniform vec2 u_lens_size;
uniform float u_radius;
uniform float u_refraction;
uniform sampler2D u_backdrop;
out vec4 frag_color;

void main() {
  vec2 point = FlutterFragCoord().xy;
  vec2 centered = point - u_origin - u_lens_size * 0.5;
  float radius = min(u_radius, min(u_lens_size.x, u_lens_size.y) * 0.5);
  vec2 spine = max(vec2(0.0), u_lens_size * 0.5 - vec2(radius));
  vec2 radial = centered - clamp(centered, -spine, spine);
  float distance = length(radial);
  float slope = clamp(distance / max(radius, 1.0), 0.0, 1.0);
  vec2 normal = radial / max(distance, 0.001);
  // Increasing magnification at the curved wall bends a transmitted line. The
  // center stays calm so content cannot distract from the navigation icons.
  vec2 sample_point = point - normal * min(u_refraction, radius * 0.55) * slope * slope * slope;
  vec2 uv = clamp(sample_point / u_size, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  frag_color = texture(u_backdrop, uv);
}
