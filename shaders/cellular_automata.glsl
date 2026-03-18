// Brian's Brain CA with color propagation
// Input 0: previous state (feedback) — RGB=color, A=state (1.0 alive, 0.5 dying, 0.0 dead)
// Input 1: live input (bright pixels force alive, color inherited)
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
    float state = prev.a;
    vec3 color = prev.rgb;

    // Read control values
    vec3 ctrl = texture(sTD2DInputs[2], vec2(0.5)).rgb;
    float killRate = ctrl.r;
    float interval = max(ctrl.g, 1.0);
    float frame = ctrl.b;

    // Speed control: only compute CA on step frames
    bool isStepFrame = mod(frame, interval) < 1.0;

    if (!isStepFrame) {
        fragColor = TDOutputSwizzle(prev);
        return;
    }

    // --- Sample 8 neighbors (state from .a, color from .rgb) ---
    vec2 offsets[8] = vec2[](
        vec2(-px.x, -px.y), vec2(0.0, -px.y), vec2(px.x, -px.y),
        vec2(-px.x,  0.0),                     vec2(px.x,  0.0),
        vec2(-px.x,  px.y), vec2(0.0,  px.y),  vec2(px.x,  px.y)
    );

    int neighbors = 0;
    vec3 neighborColorSum = vec3(0.0);

    for (int i = 0; i < 8; i++) {
        vec4 s = texture(sTD2DInputs[0], uv + offsets[i]);
        if (s.a > 0.9) {
            neighbors++;
            neighborColorSum += s.rgb;
        }
    }

    float entropy = 0.0;
    for (int i = 0; i < 8; i++) {
        entropy += texture(sTD2DInputs[0], uv + offsets[i]).a;
    }
    float rand = hash(gl_FragCoord.xy, entropy);

    float resultState;
    vec3 resultColor;

    if (state > 0.9) {
        // alive -> dying: keep color
        resultState = 0.5;
        resultColor = color;
    } else if (state > 0.3) {
        // dying -> dead: keep color (fades visually since state dims)
        resultState = 0.0;
        resultColor = color;
    } else {
        // dead -> alive if 2 neighbors
        if (neighbors == 2 && rand > killRate) {
            resultState = 1.0;
            // inherit average color from alive neighbors
            resultColor = neighborColorSum / 2.0;
        } else {
            resultState = 0.0;
            resultColor = vec3(0.0);
        }
    }

    // Input override: force alive with input color
    vec4 inputSample = texture(sTD2DInputs[1], uv);
    float input_lum = dot(inputSample.rgb, vec3(0.299, 0.587, 0.114));
    if (input_lum > 0.5) {
        resultState = 1.0;
        resultColor = inputSample.rgb;
    }

    fragColor = TDOutputSwizzle(vec4(resultColor, resultState));
}