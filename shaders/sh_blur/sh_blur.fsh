//
// 9-tap Gaussian blur in one direction (run twice: horizontal then vertical).
// Uses linear filtering so 5 samples cover 9 taps.
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform vec2 u_texel; // (1/width, 0) or (0, 1/height), times spread

void main()
{
    vec3 s = texture2D(gm_BaseTexture, v_vTexcoord).rgb * 0.2270270270;
    s += texture2D(gm_BaseTexture, v_vTexcoord + u_texel * 1.3846153846).rgb * 0.3162162162;
    s += texture2D(gm_BaseTexture, v_vTexcoord - u_texel * 1.3846153846).rgb * 0.3162162162;
    s += texture2D(gm_BaseTexture, v_vTexcoord + u_texel * 3.2307692308).rgb * 0.0702702703;
    s += texture2D(gm_BaseTexture, v_vTexcoord - u_texel * 3.2307692308).rgb * 0.0702702703;
    gl_FragColor = vec4(s, 1.0);
}
