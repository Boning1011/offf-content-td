// Cellular Automata (Conway's Game of Life) with input override + decay
// Input 0: previous CA state (from feedback)
// Input 1: live input (bright pixels override CA)
out vec4 fragColor;

void main()
{
    vec2 uv = vUV.st;
    vec2 px = 1.0 / uTDOutputInfo.res.zw;

    // Read previous CA state (using brightness as life value)
    float c = dot(texture(sTD2DInputs[0], uv).rgb, vec3(0.333));

    // Count 8 neighbors (treat > 0.5 as alive)
    float n = 0.0;
    n += step(0.5, dot(texture(sTD2DInputs[0], uv + vec2(-px.x, -px.y)).rgb, vec3(0.333)));
    n += step(0.5, dot(texture(sTD2DInputs[0], uv + vec2(   0.0, -px.y)).rgb, vec3(0.333)));
    n += step(0.5, dot(texture(sTD2DInputs[0], uv + vec2( px.x, -px.y)).rgb, vec3(0.333)));
    n += step(0.5, dot(texture(sTD2DInputs[0], uv + vec2(-px.x,    0.0)).rgb, vec3(0.333)));
    n += step(0.5, dot(texture(sTD2DInputs[0], uv + vec2( px.x,    0.0)).rgb, vec3(0.333)));
    n += step(0.5, dot(texture(sTD2DInputs[0], uv + vec2(-px.x,  px.y)).rgb, vec3(0.333)));
    n += step(0.5, dot(texture(sTD2DInputs[0], uv + vec2(   0.0,  px.y)).rgb, vec3(0.333)));
    n += step(0.5, dot(texture(sTD2DInputs[0], uv + vec2( px.x,  px.y)).rgb, vec3(0.333)));

    int neighbors = int(n + 0.5);
    bool alive = c > 0.5;

    // Conway rules
    float ca;
    if (alive) {
        ca = (neighbors == 2 || neighbors == 3) ? 1.0 : 0.0;
    } else {
        ca = (neighbors == 3) ? 1.0 : 0.0;
    }

    // Fade: CA cells lose brightness over time so trails decay
    // Alive cells start at 0.8 (dimmer than input), dead cells fade out
    float prev = texture(sTD2DInputs[0], uv).r;
    float result;
    if (ca > 0.5) {
        result = max(prev, 0.7);  // CA cells stay visible but dimmer than input
    } else {
        result = prev * 0.92;     // fade out dead cells gradually
    }

    // Input override: bright input pixels always on top at full brightness
    float input_lum = dot(texture(sTD2DInputs[1], uv).rgb, vec3(0.299, 0.587, 0.114));
    if (input_lum > 0.5) {
        result = 1.0;
    }

    fragColor = TDOutputSwizzle(vec4(vec3(result), 1.0));
}
