// 2x2 Bayer Dither - output is strictly 0 or 1
out vec4 fragColor;

void main()
{
    // Sample input texture
    vec2 uv = vUV.st;
    vec4 color = texture(sTD2DInputs[0], uv);

    // Convert to luminance
    float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));

    // 2x2 Bayer matrix (values: 0, 2, 3, 1) / 4.0
    // [0.00, 0.50]
    // [0.75, 0.25]
    ivec2 pos = ivec2(gl_FragCoord.xy) % 2;
    float threshold;
    if (pos.x == 0 && pos.y == 0) threshold = 0.0 / 4.0;
    else if (pos.x == 1 && pos.y == 0) threshold = 2.0 / 4.0;
    else if (pos.x == 0 && pos.y == 1) threshold = 3.0 / 4.0;
    else                                threshold = 1.0 / 4.0;

    // Dither: output 0 or 1 only
    float dithered = step(threshold, lum);

    fragColor = TDOutputSwizzle(vec4(vec3(dithered), 1.0));
}
