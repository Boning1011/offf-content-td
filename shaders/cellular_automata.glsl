// Brian's Brain CA with kill rate + speed control
// Input 0: previous state (feedback)
// Input 1: live input (bright pixels force alive)
// Input 2: control (R=kill rate, G=frame interval, B=frame counter)
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

    vec4 prev = texture(sTD2DInputs[0], uv);
    float c = prev.r;

    // Read control values
    vec3 ctrl = texture(sTD2DInputs[2], vec2(0.5)).rgb;
    float killRate = ctrl.r;
    float interval = max(ctrl.g, 1.0);  // frame interval (1 = every frame)
    float frame = ctrl.b;

    // Speed control: only compute CA on step frames, otherwise pass through
    bool isStepFrame = mod(frame, interval) < 1.0;

    if (!isStepFrame) {
        // Pass through previous state unchanged
        fragColor = TDOutputSwizzle(prev);
        return;
    }

    // --- CA computation (only on step frames) ---
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
        result = 0.5;  // alive -> dying
    } else if (c > 0.3) {
        result = 0.0;  // dying -> dead
    } else {
        // dead -> alive if 2 neighbors AND passes kill check
        result = (neighbors == 2 && rand > killRate) ? 1.0 : 0.0;
    }

    // Input override
    float input_lum = dot(texture(sTD2DInputs[1], uv).rgb, vec3(0.299, 0.587, 0.114));
    if (input_lum > 0.5) {
        result = 1.0;
    }

    fragColor = TDOutputSwizzle(vec4(vec3(result), 1.0));
}
