// POP physics compute shader: velocity, drag, fade, death
// Runs AFTER Particle POP — particles already have positions from source points
// New particles have vel=(0,0,0), bright=0 → detect and initialize
//
// Sampler 0: sSignalL — for spawn color sampling
// Sampler 1: sSignalR — for spawn color sampling

uniform float uInitSpeed;
uniform float uDrag;
uniform float uDragSpread;
uniform float uFadeRate;
uniform float uWidth;       // 384
uniform float uNumRows;     // 1152
uniform float uFrame;

// PCG-style integer hash for uncorrelated random values
uint pcg(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float rand(uint seed) {
    return float(pcg(seed)) / 4294967295.0;
}

void main() {
    const uint id = TDIndex();
    if (id >= TDNumElements()) return;

    vec3 pos = TDIn_P().xyz;
    vec3 v   = TDIn_vel().xyz;
    float br = TDIn_bright().x;
    vec3 sc  = TDIn_scolor().xyz;
    float pd = TDIn_pdrag().x;

    bool isNew = (abs(v.x) < 0.001 && br < 0.001);

    if (isNew) {
        bool fromRight = (pos.x > 190.0);
        float dir = fromRight ? -1.0 : 1.0;

        // Each random value uses a different seed offset for full decorrelation
        uint frame = uint(uFrame);
        float r0 = rand(id * 3u + 0u + frame * 7919u);
        float r1 = rand(id * 3u + 1u + frame * 7919u);
        float r2 = rand(id * 3u + 2u + frame * 7919u);

        // Long-tail speed distribution
        float speedMul = 0.4 + pow(r0, 0.3) * 1.6;
        v = vec3(dir * uInitSpeed * speedMul, 0.0, 0.0);

        // Brightness: mostly bright, some dim
        br = 0.3 + 0.7 * pow(r1, 0.3);

        // Per-particle drag: wide spread for varied stopping distances
        pd = uDrag - r2 * uDragSpread;
        pd = clamp(pd, 0.9, 0.9999);

        // Get color from the inherited scolor attribute (set by birth sampler)
        // Boost it for LED visibility
        sc = clamp(sc * 3.0, 0.0, 1.0);
    } else if (br > 0.005) {
        // Alive: physics update
        v.x *= pd;
        pos += v;
        br -= uFadeRate;

        if (pos.x < -1.0 || pos.x >= uWidth || abs(v.x) < 0.01 || br < 0.005) {
            pos = vec3(-10.0, -10.0, 0.0);
            v = vec3(0.0);
            br = 0.0;
        }
    }

    P[id] = vec3(round(pos.x), round(pos.y), 0.0);
    vel[id] = v;
    bright[id] = br;
    scolor[id] = sc;
    pdrag[id] = pd;
    Color[id] = vec4(sc, br);
}
