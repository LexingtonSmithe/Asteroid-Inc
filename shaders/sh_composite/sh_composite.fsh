//
// Final composite: scene + blurred glow, with a soft vignette.
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform sampler2D u_bloom;
uniform float u_bloom_strength; // 0 = no glow
uniform float u_vignette;       // 0 = none

void main()
{
    vec3 base = texture2D(gm_BaseTexture, v_vTexcoord).rgb;
    vec3 glow = texture2D(u_bloom, v_vTexcoord).rgb;
    vec3 col = base + glow * u_bloom_strength;

    vec2 d = v_vTexcoord - 0.5;
    col *= 1.0 - u_vignette * dot(d, d) * 2.0;

    gl_FragColor = vec4(col, 1.0);
}
