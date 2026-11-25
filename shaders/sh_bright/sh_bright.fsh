//
// Bloom bright-pass: keeps only the bright / saturated parts of the image.
// Uses the brightest channel (not luminance) so saturated neon reds and blues glow too.
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform float u_threshold; // 0-1, below this nothing glows

void main()
{
    vec4 c = texture2D(gm_BaseTexture, v_vTexcoord);
    float peak = max(c.r, max(c.g, c.b));
    float k = smoothstep(u_threshold, 1.0, peak);
    gl_FragColor = vec4(c.rgb * k, 1.0);
}
