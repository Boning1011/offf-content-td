// Brian's Brain CA with tunable kill rate
// Input 0: previous state (feedback)
// Input 1: live input (bright pixels force alive)
// Input 2: kill rate control (red channel = kill probability 0-1)
out vec4 fragColor;

float hash(vec2 p, float seed) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031 + seed * 0.1);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main()
{
    vec2 uv = vUV.st;
    vec2 px = 1.0 / uTDOutputInfo.res.zw;

    float c = texture(sTD2DInputs[0], uv).r;
    float killRate = texture(sTD2DInputs[2], vec2(0.5)).r;

    float s0 = texture(sTD2DInputs[0], uv + vec2(-px.x, -px.y)).r;
    float s1 = texture(sTD2DInputs[0], uv + vec2(   0.0, -px.y)).r;
    float s2 = texture(sTD2DInputs[0], uv + vec2( px.x, -px.y)).r;
    float s3 = texture(sTD2DInputs[0], uv + vec2(-px.x,    0.0)).r;
    float s4 = texture(sTD2DInputs[0], uv + vec2( px.x,    0.0)).r;
    float s5 = texture(sTD2DInputs[0], uv + vec2(-px.x,  px.y)).r;
    float s6 = texture(sTD2DInputs[0], uv + vec2(   0.0,  px.y)).r;
    float s7 = texture(sTD2DInputs[0], uv + vec2( px.x,  px.y)).r;

    float n = step(0.9, s0) + step(0.9, s1) + step(0.9, s2) + step(0.9, s3)
            + step(0.9, s4) + step(0.9, s5) + step(0.9, s6) + step(0.9, s7);
    int neighbors = int(n + 0.5);

    float entropy = s0 + s1 + s2 + s3 + s4 + s5 + s6 + s7;
    float rand = hash(gl_FragCoord.xy, entropy);

    float result;
    if (c > 0.9) {
        // alive -> dying, random kill skips straight to dead
        result = (rand < killRate) ? 0.0 : 0.5;
    } else if (c > 0.3) {
        // dying -> dead
        result = 0.0;
    } else {
        // dead -> alive if exactly 2 alive neighbors
        result = (neighbors == 2) ? 1.0 : 0.0;
    }

    // Input override
    float input_lum = dot(texture(sTD2DInputs[1], uv).rgb, vec3(0.299, 0.587, 0.114));
    if (input_lum > 0.5) {
        result = 1.0;
    }

    fragColor = TDOutputSwizzle(vec4(vec3(result), 1.0));
}
