// ca_chain — 1D Cellular Automata (Wolfram rule), shifted leftward via feedback.
// Global step rhythm keeps the CA pattern coherent near edgeX. Per-row skip
// jitter on step frames lets rare misses accumulate over distance → shear far
// from the generation edge.
// Input 0: feedback (prev frame)
// Input 1: signal (noise), sampled at center column

uniform float uHigh;
uniform float uLow;
uniform float uRandomRate;
uniform float uRule;
uniform float uFrame;
uniform float uStepInterval;   // frames between global CA steps
uniform float uRowSkipProb;    // per-row probability of skipping a step

out vec4 fragColor;

uint pcg(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float rand(uint a, uint b, uint c) {
    uint h = pcg(a ^ pcg(b ^ pcg(c)));
    return float(h) * (1.0 / 4294967295.0);
}

int applyRule(int rule, int l, int c, int r) {
    int pattern = (l << 2) | (c << 1) | r;
    return (rule >> pattern) & 1;
}

void main() {
    vec2 uv = vUV.st;
    vec2 res = uTDOutputInfo.res.zw;
    ivec2 coord = ivec2(gl_FragCoord.xy);
    int edgeX = int(res.x) - 1;
    int ymax = int(res.y) - 1;

    int stepN = max(int(uStepInterval), 1);
    uint frame = uint(uFrame);
    int stepIdx = int(uFrame) / stepN;

    // Hold on non-step frames: output current pixel unchanged.
    if ((int(uFrame) % stepN) != 0) {
        fragColor = TDOutputSwizzle(texelFetch(sTD2DInputs[0], coord, 0));
        return;
    }

    // On step frames: per-row skip. Hash by row + stepIdx so the same row
    // decision lasts across the whole step frame (not re-rolled per frame).
    if (rand(uint(coord.y), uint(stepIdx), 11u) < uRowSkipProb) {
        fragColor = TDOutputSwizzle(texelFetch(sTD2DInputs[0], coord, 0));
        return;
    }

    if (coord.x < edgeX) {
        fragColor = TDOutputSwizzle(texelFetch(sTD2DInputs[0], coord + ivec2(1, 0), 0));
        return;
    }

    int y = coord.y;
    int ym = max(y - 1, 0);
    int yp = min(y + 1, ymax);

    int l = (texelFetch(sTD2DInputs[0], ivec2(edgeX, ym), 0).r > 0.5) ? 1 : 0;
    int c = (texelFetch(sTD2DInputs[0], ivec2(edgeX, y ), 0).r > 0.5) ? 1 : 0;
    int r = (texelFetch(sTD2DInputs[0], ivec2(edgeX, yp), 0).r > 0.5) ? 1 : 0;

    int bit = applyRule(int(uRule), l, c, r);

    float noise = texture(sTD2DInputs[1], vec2(0.1, uv.y)).r;
    if (noise > uHigh)      bit = 1;
    else if (noise < uLow)  bit = 0;

    if (rand(uint(y), frame, 17u) < uRandomRate) {
        bit = 1 - bit;
    }

    float v = float(bit);
    fragColor = TDOutputSwizzle(vec4(v, v, v, v));
}
