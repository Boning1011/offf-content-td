// Temporal Dither - white areas become alternating 0/1 stripe pattern
// Input 0: source image (any TOP)
out vec4 fragColor;

void main()
{
    ivec2 coord = ivec2(gl_FragCoord.xy);
    float src = texelFetch(sTD2DInputs[0], coord, 0).r;
    float current = step(0.5, src);

    // ON: alternating 0/1 per pixel, OFF: black
    float display = current * float(coord.x % 2);

    fragColor = TDOutputSwizzle(vec4(vec3(display), 1.0));
}
