
#pragma header

uniform float _alpha = 0.5;
uniform float _disx = 4.0;
uniform float _disy = 4.0;

uniform bool inner = false;
uniform bool inverted = false;
uniform bool knockout = false;

void main()
{
    vec2 uv = openfl_TextureCoordv.xy;
    vec2 offset = vec2(_disx, _disy) / openfl_TextureSize.xy;

    // Original texture
    vec4 color = flixel_texture2D(bitmap, uv);

    // Shadow texture
    vec4 shadow = flixel_texture2D(bitmap, uv - offset);

    // Shadow mask
    shadow.rgb = vec3(0.0);

    if (inner)
    {
        shadow.a = (1.0 - shadow.a) * color.a;

        float factor;

        if (inverted)
            factor = shadow.a + color.a * (1.0 - _alpha);
        else
            factor = 1.0 - shadow.a * _alpha;

        vec3 result = color.rgb * factor;

        if (knockout)
            gl_FragColor = shadow * _alpha;
        else
            gl_FragColor = vec4(result, color.a);
    }
    else
    {
        shadow.a *= _alpha;

        if (knockout && color.a > 0.0)
            gl_FragColor = vec4(0.0);
        else
            gl_FragColor = shadow + color;
    }
}
