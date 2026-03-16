// 2x2 Bayer Dither with Temporal Accumulation
// Input 0: source image
// Input 1: feedback (previous accumulated frame)
uniform float uFrame;
out vec4 fragColor;

void main()
{
    vec2 uv = vUV.st;
    vec4 color = texture(sTD2DInputs[0], uv);   // source
    vec4 prev  = texture(sTD2DInputs[1], uv);   // feedback

    // Convert to luminance
    float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));

    // 2x2 Bayer matrix with centered thresholds: (M + 0.5) / 4
    ivec2 pos = ivec2(gl_FragCoord.xy) % 2;
    float threshold;
    if (pos.x == 0 && pos.y == 0) threshold = 0.5 / 4.0;
    else if (pos.x == 1 && pos.y == 0) threshold = 2.5 / 4.0;
    else if (pos.x == 0 && pos.y == 1) threshold = 3.5 / 4.0;
    else                                threshold = 1.5 / 4.0;

    // Temporal offset: golden ratio sequence for even coverage
    float frameOffset = fract(uFrame * 0.618033989);
    threshold = fract(threshold + frameOffset);

    // Dither: this frame is still 0 or 1
    float dithered = step(threshold, lum);

    // Blend with previous accumulated frame (exponential moving average)
    float blend = 0.15;
    vec3 result = mix(prev.rgb, vec3(dithered), blend);

    fragColor = TDOutputSwizzle(vec4(result, 1.0));
}
