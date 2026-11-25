//
// CRT scanlines drawn as a dark overlay. Works in real window pixels
// (gl_FragCoord), so line spacing is independent of GUI or game scaling.
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform float u_period;   // window pixels per scanline (dark + light)
uniform float u_strength; // 0-1, darkness of the dark rows
uniform float u_time;     // seconds, for a slow rolling flicker band

void main()
{
    float phase = mod(gl_FragCoord.y, u_period) / u_period;
    float line = smoothstep(0.35, 0.65, phase) * (1.0 - smoothstep(0.85, 1.0, phase));
    float roll = 0.03 * sin(gl_FragCoord.y * 0.01 - u_time * 2.0);
    gl_FragColor = vec4(0.0, 0.0, 0.0, clamp(line * u_strength + roll, 0.0, 1.0));
}
