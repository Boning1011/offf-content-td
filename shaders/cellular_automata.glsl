// Brian's Brain - 3-state Cellular Automata with input override
// States: 1.0 = alive, 0.5 = dying, 0.0 = dead
// Rules: alive->dying, dying->dead, dead->alive if exactly 2 alive neighbors
// Input 0: previous state (feedback)
// Input 1: live input (bright pixels force alive)
out vec4 fragColor;

void main()
{
    vec2 uv = vUV.st;
    vec2 px = 1.0 / uTDOutputInfo.res.zw;

    float c = texture(sTD2DInputs[0], uv).r;

    // Count alive neighbors (only fully alive cells count, not dying)
    float n = 0.0;
    n += step(0.9, texture(sTD2DInputs[0], uv + vec2(-px.x, -px.y)).r);
    n += step(0.9, texture(sTD2DInputs[0], uv + vec2(   0.0, -px.y)).r);
    n += step(0.9, texture(sTD2DInputs[0], uv + vec2( px.x, -px.y)).r);
    n += step(0.9, texture(sTD2DInputs[0], uv + vec2(-px.x,    0.0)).r);
    n += step(0.9, texture(sTD2DInputs[0], uv + vec2( px.x,    0.0)).r);
    n += step(0.9, texture(sTD2DInputs[0], uv + vec2(-px.x,  px.y)).r);
    n += step(0.9, texture(sTD2DInputs[0], uv + vec2(   0.0,  px.y)).r);
    n += step(0.9, texture(sTD2DInputs[0], uv + vec2( px.x,  px.y)).r);

    int neighbors = int(n + 0.5);

    float result;
    if (c > 0.9) {
        // alive -> dying
        result = 0.5;
    } else if (c > 0.3) {
        // dying -> dead
        result = 0.0;
    } else {
        // dead -> alive if exactly 2 alive neighbors
        result = (neighbors == 2) ? 1.0 : 0.0;
    }

    // Input override: bright input pixels force alive
    float input_lum = dot(texture(sTD2DInputs[1], uv).rgb, vec3(0.299, 0.587, 0.114));
    if (input_lum > 0.5) {
        result = 1.0;
    }

    fragColor = TDOutputSwizzle(vec4(vec3(result), 1.0));
}
