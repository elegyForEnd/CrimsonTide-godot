// Fixed UV noise makes recovery reproducible when replayed or captured frame by frame.
uniform bool clip_footprint = false;
uniform vec2 footprint_center = vec2(0.5);
uniform vec2 footprint_radius_uv = vec2(0.5);
float release_footprint(vec2 uv) {
	if (!clip_footprint) { return 1.0; }
	float radius=length((uv-footprint_center)/max(footprint_radius_uv,vec2(0.0001)));
	return 1.0-smoothstep(0.985,1.0,radius);
}
float release_hash(vec2 point) {
	return fract(sin(dot(point,vec2(127.1,311.7))) * 43758.5453);
}
float release_noise(vec2 point) {
	vec2 cell=floor(point);
	vec2 local=fract(point);
	local=local*local*(3.0-2.0*local);
	return mix(mix(release_hash(cell),release_hash(cell+vec2(1.0,0.0)),local.x),
		mix(release_hash(cell+vec2(0.0,1.0)),release_hash(cell+vec2(1.0,1.0)),local.x),local.y);
}
float release_mask(vec4 art, vec2 uv, float phase) {
	if (phase <= 0.25) { return release_footprint(uv); }
	if (phase >= 1.0) { return 0.0; }
	float progress=clamp((phase-0.25)/0.75,0.0,1.0);
	float energy=max(art.r,max(art.g,art.b));
	float noise=release_noise(uv*29.0)*0.7+release_noise(uv*71.0)*0.3;
	// Thin alpha and dim ink disappear first; the painted luminous core survives later.
	float persistence=art.a*0.28+energy*0.42+noise*0.30;
	float threshold=mix(-0.12,1.12,progress);
	return smoothstep(threshold-0.09,threshold+0.09,persistence)*release_footprint(uv);
}
