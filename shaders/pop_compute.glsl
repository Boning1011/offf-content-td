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

float hash(float n) {
    float x = fract(sin(n) * 43758.5453);
    return fract(sin(x * 91.3458 + n * 47.123) * 27183.6142);
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
        // Newly born particle — pos already set by Particle POP at source point
        // Determine direction from x position
        bool fromRight = (pos.x > 190.0);
        float dir = fromRight ? -1.0 : 1.0;

        float fid = float(id);
        float r0 = hash(fid * 7.0 + uFrame * 0.317);
        float r1 = hash(fid * 19.0 + uFrame * 0.937);
        float r2 = hash(fid * 29.0 + uFrame * 1.153);

        // Long-tail speed distribution
        float speedMul = 0.4 + pow(r0, 0.3) * 1.6;
        v = vec3(dir * uInitSpeed * speedMul, 0.0, 0.0);

        // Brightness: mostly bright, some dim
        br = 0.3 + 0.7 * pow(r1, 0.3);

        // Per-particle drag
        pd = uDrag - pow(r2, 2.0) * uDragSpread;
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
