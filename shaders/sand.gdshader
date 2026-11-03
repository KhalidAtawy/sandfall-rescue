shader_type canvas_item;
// Each texel of TEXTURE is one cell of the debris grid (0 = empty, 1..3 = grain variant).
// Every pixel looks at its 3x3 neighbourhood and draws the grain sprites that overlap it,
// so grains are drawn larger than their cell and pile up like real pebbles.
// grain_tex is an atlas of 3 grain variants side by side.
uniform sampler2D grain_tex : filter_linear;
uniform vec2 grid = vec2(60.0, 110.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 glow_col : source_color = vec4(1.0);
uniform float gsize = 1.65;
uniform float glow = 0.0;
uniform float brightness = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 p = UV * grid;
	vec2 c0 = floor(p);
	vec4 acc = vec4(0.0);
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 c = c0 + vec2(float(dx), float(dy));
			if (c.x < 0.0 || c.y < 0.0 || c.x >= grid.x || c.y >= grid.y) continue;
			float v = texelFetch(TEXTURE, ivec2(c), 0).r * 255.0;
			if (v < 0.5) continue;
			float vi = clamp(floor(v + 0.5), 1.0, 3.0);
			vec2 j = vec2(hash(c), hash(c + 17.31)) - 0.5;
			vec2 l = (p - (c + 0.5 + j * 0.2)) / gsize + 0.5;
			if (l.x < 0.0 || l.y < 0.0 || l.x > 1.0 || l.y > 1.0) continue;
			vec4 t = texture(grain_tex, vec2((clamp(l.x, 0.02, 0.98) + vi - 1.0) / 3.0, l.y));
			float shade = 0.82 + 0.3 * hash(c + 3.7);
			vec3 rgb = t.rgb * tint.rgb * brightness * shade + glow_col.rgb * glow * t.a;
			vec4 s = vec4(rgb * t.a, t.a);
			acc = s + acc * (1.0 - s.a);
		}
	}
	COLOR = vec4(acc.rgb / max(acc.a, 0.0001), acc.a);
}
