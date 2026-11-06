shader_type spatial;
// One cell of a blast: a beam joined to the burning neighbours (bit 0 left, 1 right, 2 up, 3 down),
// rounded where it ends, with a scrolling noise edge. HDR colours so the glow picks it up.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex : repeat_enable;
instance uniform int sides = 0;
instance uniform float power = 1.0;
instance uniform float seed = 0.0;

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p);
	if ((sides & 1) != 0 && p.x <= 0.0) d = min(d, abs(p.y));
	if ((sides & 2) != 0 && p.x >= 0.0) d = min(d, abs(p.y));
	if ((sides & 4) != 0 && p.y <= 0.0) d = min(d, abs(p.x));
	if ((sides & 8) != 0 && p.y >= 0.0) d = min(d, abs(p.x));
	float n = texture(noise_tex, UV * 0.9 + vec2(TIME * 0.9 + seed, -TIME * 1.3)).r;
	float n2 = texture(noise_tex, UV * 2.1 + vec2(-TIME * 1.7, TIME * 0.6 + seed)).r;
	d += (n - 0.5) * 0.16 + (n2 - 0.5) * 0.06;
	float r = (sides != 0 ? 0.46 : 0.42) * power;
	float f = d / r;
	vec3 c = mix(vec3(2.0, 1.8, 1.1), vec3(1.9, 0.95, 0.12), smoothstep(0.06, 0.32, f));
	c = mix(c, vec3(1.5, 0.3, 0.03), smoothstep(0.3, 0.62, f));
	c = mix(c, vec3(0.55, 0.05, 0.01), smoothstep(0.62, 0.95, f));
	float a = 1.0 - smoothstep(0.82, 1.0, f);
	ALBEDO = c;
	ALPHA = a;
}
