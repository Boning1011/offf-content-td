// Temporal Dither - white areas become alternating 0/1 stripe pattern
// Input 0: source image (any TOP)
out vec4 fragColor;

void main()
{
    ivec2 coord = ivec2(gl_FragCoord.xy);
    vec4 src = texelFetch(sTD2DInputs[0], coord, 0);
    float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
    float current = step(0.5, lum);

    // ON: alternating 0/1 per pixel, OFF: black
    float mask = current * float(coord.x % 2);

    fragColor = TDOutputSwizzle(vec4(src.rgb * mask, 1.0));
}
