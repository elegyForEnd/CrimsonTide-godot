shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform sampler2D painting : source_color, filter_linear, repeat_disable;
uniform vec2 ink_origin=vec2(0.0);
uniform vec2 ink_size=vec2(1.0);
uniform float reveal=1.0;
uniform float fade=1.0;
uniform float phase=0.0;
void fragment(){
 vec2 uv=vec2(UV.x,1.0-UV.y);
 // Retain the original silhouette and pigment. Only a small broad flow moves it.
 uv.y+=sin(uv.x*5.0-phase*2.0)*.008;
 vec4 tex=texture(painting,ink_origin+clamp(uv,vec2(0.0),vec2(1.0))*ink_size);
 float coverage=smoothstep(1.0-reveal-.12,1.0-reveal+.10,UV.x);
 vec3 pigment=mix(tex.rgb,tex.rgb*COLOR.rgb,.22);
 ALBEDO=pigment;
 EMISSION=pigment*.45;
 ALPHA=tex.a*COLOR.a*fade*coverage;
}
