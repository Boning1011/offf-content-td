// 4x4 block dither: outer ring black, inner 2x2 can be 0 or 1
out vec4 fragColor;

uint pcg(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word  = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float rand(vec2 co) {
    uint x = uint(co.x);
    uint y = uint(co.y);
    return float(pcg(x + pcg(y))) / 4294967295.0;
}

void main()
{
    ivec2 cell = ivec2(gl_FragCoord.xy) % 4;

    // Inner 2x2 = cells (1,1)(2,1)(1,2)(2,2)
    bool isInner = (cell.x >= 1) && (cell.x <= 2) && (cell.y >= 1) && (cell.y <= 2);
    if (!isInner) {
        fragColor = TDOutputSwizzle(vec4(0.0, 0.0, 0.0, 1.0));
        return;
    }

    // Sample at 4x4 block center
    vec2 block = floor(gl_FragCoord.xy / 4.0);
    vec2 res = uTDOutputInfo.res.zw;
    vec2 blockUV = (block * 4.0 + 2.0) / res;
    vec4 color = texture(sTD2DInputs[0], blockUV);
    float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));

    // Same threshold for all 4 inner pixels
    float r = rand(block);
    float dithered = step(r, lum);

    fragColor = TDOutputSwizzle(vec4(vec3(dithered), 1.0));
}
