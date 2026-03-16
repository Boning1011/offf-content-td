// Morse Code Scanner - scrolling signal history per scanline
//
// Input 0 (wired):  feedback (previous frame)
// Input 1 (tops):   signal  - 1px wide vertical strip
// Input 2 (tops):   speed   - 1px wide vertical strip, per-row scroll speed
//
// "tops" parameter on the GLSL Multi TOP binds these by node name,
// so they won't break if you add/remove wired connections.
out vec4 fragColor;

void main()
{
    vec2 uv = vUV.st;
    vec2 res = uTDOutputInfo.res.zw;
    ivec2 coord = ivec2(gl_FragCoord.xy);

    // Per-row speed: round to integer pixels to prevent interpolation stretch
    float speedNoise = texture(sTD2DInputs[2], vec2(0.5, uv.y)).r;
    int shiftPx = int(round(1.0 + speedNoise * 3.0));  // 1 to 4 pixels/frame

    // Rightmost columns (cover shift width): write fresh signal
    if (coord.x >= int(res.x) - shiftPx) {
        vec4 signal = texture(sTD2DInputs[1], vec2(0.5, uv.y));
        float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));
        float morse = step(0.5, lum);
        fragColor = TDOutputSwizzle(vec4(vec3(morse), 1.0));
    } else {
        // texelFetch: no interpolation, exact pixel copy
        vec4 prev = texelFetch(sTD2DInputs[0], coord + ivec2(shiftPx, 0), 0);
        fragColor = TDOutputSwizzle(prev);
    }
}
