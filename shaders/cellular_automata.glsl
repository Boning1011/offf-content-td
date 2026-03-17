// Cellular Automata (Conway's Game of Life) with input override
// Input 0: previous CA state (from feedback)
// Input 1: live input (bright pixels override CA)
out vec4 fragColor;

void main()
{
    vec2 uv = vUV.st;
    vec2 px = 1.0 / uTDOutputInfo.res.zw;

    // Read previous CA state
    float c  = dot(texture(sTD2DInputs[0], uv).rgb, vec3(0.333));

    // Count 8 neighbors
    float n = 0.0;
    n += dot(texture(sTD2DInputs[0], uv + vec2(-px.x, -px.y)).rgb, vec3(0.333));
    n += dot(texture(sTD2DInputs[0], uv + vec2(   0.0, -px.y)).rgb, vec3(0.333));
    n += dot(texture(sTD2DInputs[0], uv + vec2( px.x, -px.y)).rgb, vec3(0.333));
    n += dot(texture(sTD2DInputs[0], uv + vec2(-px.x,    0.0)).rgb, vec3(0.333));
    n += dot(texture(sTD2DInputs[0], uv + vec2( px.x,    0.0)).rgb, vec3(0.333));
    n += dot(texture(sTD2DInputs[0], uv + vec2(-px.x,  px.y)).rgb, vec3(0.333));
    n += dot(texture(sTD2DInputs[0], uv + vec2(   0.0,  px.y)).rgb, vec3(0.333));
    n += dot(texture(sTD2DInputs[0], uv + vec2( px.x,  px.y)).rgb, vec3(0.333));

    // Round neighbors to integer count
    int neighbors = int(n + 0.5);

    // Conway rules
    float ca;
    if (c > 0.5) {
        // alive: survive with 2 or 3 neighbors
        ca = (neighbors == 2 || neighbors == 3) ? 1.0 : 0.0;
    } else {
        // dead: birth with exactly 3 neighbors
        ca = (neighbors == 3) ? 1.0 : 0.0;
    }

    // Input override: bright pixels from input force cell alive
    float input_lum = dot(texture(sTD2DInputs[1], uv).rgb, vec3(0.299, 0.587, 0.114));
    if (input_lum > 0.5) {
        ca = 1.0;
    }

    fragColor = TDOutputSwizzle(vec4(vec3(ca), 1.0));
}
