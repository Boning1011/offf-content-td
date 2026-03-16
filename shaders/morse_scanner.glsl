// Morse Code Scanner - scrolling signal history per scanline
// Input 0: constant (resolution reference)
// Input 1: noise2 (1px wide vertical strip - signal source)
// Input 2: feedback (previous frame)
out vec4 fragColor;

void main()
{
    vec2 uv = vUV.st;
    vec2 res = uTDOutputInfo.res.zw;
    float pixelW = 1.0 / res.x;

    // Rightmost column: write fresh value from noise2
    if (uv.x > 1.0 - pixelW * 1.5) {
        vec4 signal = texture(sTD2DInputs[1], vec2(0.5, uv.y));
        float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));
        float morse = step(0.5, lum);
        fragColor = TDOutputSwizzle(vec4(vec3(morse), 1.0));
    } else {
        // Shift previous frame 1 pixel to the left
        vec4 prev = texture(sTD2DInputs[2], uv + vec2(pixelW, 0.0));
        fragColor = TDOutputSwizzle(prev);
    }
}
