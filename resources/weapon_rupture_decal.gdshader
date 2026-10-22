shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform sampler2D earth_texture : source_color, filter_linear_mipmap;
uniform float reveal = 1.0;
varying vec4 pigment;
void vertex(){pigment=COLOR;}
void fragment(){
 vec4 rock=texture(earth_texture,UV);
 float head=1.0-smoothstep(reveal-.06,reveal,UV.x);
 ALBEDO=rock.rgb*pigment.rgb;
 EMISSION=rock.rgb*vec3(.08,.035,.01);
 ALPHA=rock.a*pigment.a*head;
}
