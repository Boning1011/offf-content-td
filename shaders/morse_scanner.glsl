// Morse Code Scanner - scrolling signal history per scanline
//
// Input 0 (wired):  feedback (previous frame)
// Input 1 (tops):   signal  - 1px wide vertical strip
// Input 2 (tops):   speed   - 1px wide vertical strip, per-row scroll speed
//
// "tops" parameter on the GLSL Multi TOP binds these by node name,
// so they won't break if you add/remove wired connections.
uniform float uFrame;
out vec4 fragColor;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

void main()
{
    vec2 uv = vUV.st;
    vec2 res = uTDOutputInfo.res.zw;
    ivec2 coord = ivec2(gl_FragCoord.xy);

    // Per-row speed (0..1)
    float speedNoise = texture(sTD2DInputs[2], vec2(0.5, uv.y)).r;

    // Decide if this row scrolls this frame:
    // speedNoise=1 -> always scrolls, speedNoise=0 -> almost never
    float row = float(coord.y);
    float roll = hash(row * 7.31 + uFrame * 0.17);
    bool scrollThisFrame = (roll < speedNoise);

    if (scrollThisFrame) {
        // Rightmost column: write fresh signal
        if (coord.x >= int(res.x) - 1) {
            vec4 signal = texture(sTD2DInputs[1], vec2(0.5, uv.y));
            float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));
            float morse = step(0.5, lum);
            fragColor = TDOutputSwizzle(vec4(vec3(morse), 1.0));
        } else {
            // Shift 1 pixel to the left
            vec4 prev = texelFetch(sTD2DInputs[0], coord + ivec2(1, 0), 0);
            fragColor = TDOutputSwizzle(prev);
        }
    } else {
        // Don't scroll: hold previous frame
        vec4 prev = texelFetch(sTD2DInputs[0], coord, 0);
        fragColor = TDOutputSwizzle(prev);
    }
}
