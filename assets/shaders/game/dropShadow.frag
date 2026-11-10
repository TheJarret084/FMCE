#pragma header
// Sombra (drop shadow) para sprites de Flixel. Se usa desde los scripts de noteskin, por ejemplo:
//
//     var sombra = shader("game/dropShadow");
//     sombra.hset("_alpha", 0.5);
//     sombra.hset("_disx", 4.0);
//     sombra.hset("_disy", 4.0);
//     nota.shader = sombra;
//
// Ojo: en GLSL ES los uniforms NO pueden llevar valor inicial (`uniform float x = 1.0;` no compila en todos
// los drivers). Los valores se asignan desde el script con `hset`.

uniform float _alpha;   // transparencia de la sombra
uniform float _disx;    // desplazamiento x en pixeles del atlas
uniform float _disy;    // desplazamiento y en pixeles del atlas
uniform bool inner;     // sombra interior
uniform bool inverted;  // sombra interior invertida (para luz)
uniform bool knockout;  // deja solo la sombra

void main(void)
{
	vec2 uv = openfl_TextureCoordv.xy;
	vec2 size = max(openfl_TextureSize.xy, vec2(1.0));
	vec2 offset = vec2(_disx, _disy) / size;

	// flixel_texture2D respeta el tinte (`sprite.color`) y el alpha del sprite.
	vec4 color = flixel_texture2D(bitmap, uv);

	if (inner)
	{
		vec4 shadow = flixel_texture2D(bitmap, uv - offset);
		shadow.rgb = vec3(0.0);
		shadow.a = (1.0 - shadow.a) * color.a;

		vec3 result;
		if (inverted)
			result = color.rgb * (shadow.a + color.a * (1.0 - _alpha));
		else
			result = color.rgb * ((1.0 - shadow.a) + shadow.a * (1.0 - _alpha));

		gl_FragColor = vec4(result, color.a);
		if (knockout) gl_FragColor = shadow * _alpha;
	}
	else
	{
		vec4 shadow = flixel_texture2D(bitmap, uv - offset);
		shadow.rgb = vec3(0.0);
		shadow.a *= _alpha;

		// La sombra solo se ve donde la nota es transparente (no oscurece el relleno).
		float finalAlpha = color.a + shadow.a * (1.0 - color.a);
		gl_FragColor = vec4(color.rgb, finalAlpha);
		if (knockout && color.a > 0.0) gl_FragColor = vec4(0.0);
	}
}
