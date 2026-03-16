// Morse Code Scanner - scrolling signal history per scanline
// Input 0: constant (resolution reference)
// Input 1: noise signal (1px wide vertical strip - signal source)
// Input 2: feedback (previous frame)
// Input 3: noise speed (1px wide vertical strip - per-row scroll speed)
out vec4 fragColor;

void main()
{
    vec2 uv = vUV.st;
    vec2 res = uTDOutputInfo.res.zw;
    float pixelW = 1.0 / res.x;

    // Per-row speed from noise3 (0..1 mapped to pixel shift range)
    float speedNoise = texture(sTD2DInputs[3], vec2(0.5, uv.y)).r;
    float shift = pixelW * (0.5 + speedNoise * 3.0);  // 0.5 to 3.5 pixels/frame

    // Rightmost columns (cover max shift width): write fresh signal
    if (uv.x > 1.0 - shift - pixelW * 0.5) {
        vec4 signal = texture(sTD2DInputs[1], vec2(0.5, uv.y));
        float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));
        float morse = step(0.5, lum);
        fragColor = TDOutputSwizzle(vec4(vec3(morse), 1.0));
    } else {
        // Shift previous frame to the left by per-row speed
        vec4 prev = texture(sTD2DInputs[2], uv + vec2(shift, 0.0));

        // Dither interpolated gray values back to 0/1
        // 2x2 Bayer threshold so gray areas become sparse/dense dot patterns
        ivec2 pos = ivec2(gl_FragCoord.xy) % 2;
        float thr;
        if (pos.x == 0 && pos.y == 0) thr = 0.125;
        else if (pos.x == 1 && pos.y == 0) thr = 0.625;
        else if (pos.x == 0 && pos.y == 1) thr = 0.875;
        else                                thr = 0.375;
        float clean = step(thr, prev.r);
        fragColor = TDOutputSwizzle(vec4(vec3(clean), 1.0));
    }
}
