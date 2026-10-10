shader_type spatial;
render_mode depth_draw_opaque;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float uv_scale=1.0;
uniform vec2 uv_axes=vec2(1.0);
uniform vec2 uv_offset=vec2(0.0);
uniform float normal_strength=.65;
uniform bool alpha_cut=false;
instance uniform float reveal=1.0;
void fragment(){
 vec2 cell=floor(FRAGCOORD.xy);
 float pattern=fract(52.9829189*fract(dot(cell,vec2(.06711056,.00583715))));
 if(pattern>reveal) discard;
 vec2 uv=UV*uv_scale*uv_axes+uv_offset;
 vec4 surface=texture(albedo_map,uv);
 if(alpha_cut && surface.a<.45) discard;
 ALBEDO=surface.rgb*tint.rgb;
 NORMAL_MAP=texture(normal_map,uv).rgb; NORMAL_MAP_DEPTH=normal_strength;
 vec3 orm=texture(orm_map,uv).rgb; AO=orm.r; ROUGHNESS=clamp(orm.g,.26,.98); METALLIC=orm.b;
}
