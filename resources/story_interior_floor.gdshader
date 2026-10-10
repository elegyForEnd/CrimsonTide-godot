shader_type spatial;
uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 floor_tint : source_color = vec4(1.0);
uniform vec4 trim_tint : source_color = vec4(.87,.82,.72,1.0);
uniform float base_scale = .55;
uniform float trim_scale = .5;
uniform float dampness = 0.0;
uniform int zoning = 0; // 0 common floor, 1 nave, 2 castle hall/dais
uniform vec2 region_origin = vec2(0.0);
uniform float centre_x = 24.0;
varying vec3 world_pos;
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 TANGENT=vec3(1.0,0.0,0.0); BINORMAL=vec3(0.0,0.0,1.0);
}
void fragment(){
 vec2 local=world_pos.xz-region_origin;
 float x=abs(local.x-centre_x);
 float accent=0.0;
 if(zoning==1){ accent=1.0-smoothstep(1.6,1.64,x); }
 if(zoning==2){
  accent=(1.0-smoothstep(1.75,1.79,x))*step(27.5,local.y);
  accent=max(accent,step(52.0,local.y));
 }
 vec2 uv=local*base_scale;
 vec2 trim_uv=local*trim_scale;
 vec3 albedo=mix(texture(base_albedo,uv).rgb*floor_tint.rgb,texture(trim_albedo,trim_uv).rgb*trim_tint.rgb,accent);
 vec3 orm=mix(texture(base_orm,uv).rgb,texture(trim_orm,trim_uv).rgb,accent);
 NORMAL_MAP=mix(texture(base_normal,uv).rgb,texture(trim_normal,trim_uv).rgb,accent);
 NORMAL_MAP_DEPTH=.42;
 ALBEDO=albedo*(1.0-dampness*.10);
 ROUGHNESS=clamp(orm.g*(1.0-dampness*.22),.46,.98);
 AO=orm.r; METALLIC=orm.b;
}
