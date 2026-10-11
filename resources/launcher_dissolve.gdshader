shader_type canvas_item;
// 启动器进游戏时的"水滴擦除"转场（见 scripts/boot.gd 的 _start_transition()）。
//
// 做法：以若干随机点为圆心向外扩散，圆内 alpha 归零——被擦掉的地方直接露出**下面
// 已经加载好的登录页**（启动器的 CanvasLayer 是 layer=100，main.tscn 的界面在
// layer=1，所以它在下面等着）。整组画面一起过这道材质，靠的是 CanvasGroup。
//
// ⚠️ 圆必须在"等比空间"里算：直接拿 UV 算，在 16:10 / 21:9 屏幕上会变成椭圆。
// 这里把 x 乘上宽高比，于是 y 方向 0..1 就是屏幕高度，半径也以屏幕高度为 1。
// `centers` 传的是归一化 UV（0..1），进 shader 再换算。
//
// 数组长度固定 5（GLSL 要求常量上界），`count` 说明真正有几滴在演算。

uniform int count = 0;
uniform vec2 centers[5];
uniform float radii[5];
// 边缘柔和度：0 就是硬边圆形（会看出锯齿感），稍微给一点像水面。
uniform float softness = 0.05;
// 水滴边界的微光（0 = 纯渐隐，不带任何描边）。
uniform float rim = 0.14;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 size = 1.0 / max(TEXTURE_PIXEL_SIZE, vec2(0.000001));
	float aspect = size.x / max(size.y, 1.0);
	vec2 p = vec2(UV.x * aspect, UV.y);
	float keep = 1.0;
	float edge = 0.0;
	for (int i = 0; i < 5; i++) {
		if (i >= count) {
			break;
		}
		vec2 c = vec2(centers[i].x * aspect, centers[i].y);
		float r = radii[i];
		float d = distance(p, c);
		keep = min(keep, smoothstep(r, r + softness, d));
		// 距离正好等于半径处最亮，用来画那一圈"水滴边缘"
		edge = max(edge, 1.0 - abs(d - r) / softness);
	}
	float alpha = tex.a * keep;
	// 只在"正在被擦掉"的那一圈附近提亮，别把整屏都提亮
	vec3 rgb = tex.rgb + vec3(0.78, 0.74, 0.68) * clamp(edge, 0.0, 1.0) * rim;
	COLOR = vec4(rgb, alpha);
}
