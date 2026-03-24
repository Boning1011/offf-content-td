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
uniform float uDragCurve;     // velocity-dependent drag exponent (higher = drag fades faster at low speed)
uniform float uHueDragOffset; // drag difference: positive = cool hues travel further
uniform float uLumInfluence;  // how much signal brightness affects speed & drag (0=none, 1=full)

// PCG-style integer hash for uncorrelated random values
uint pcg(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float rand(uint seed) {
    return float(pcg(seed)) / 4294967295.0;
}

// RGB to hue (0–1). Returns 0 for grays.
float rgbToHue(vec3 c) {
    float cmax = max(c.r, max(c.g, c.b));
    float cmin = min(c.r, min(c.g, c.b));
    float delta = cmax - cmin;
    if (delta < 0.001) return 0.0;
    float h;
    if (cmax == c.r)      h = mod((c.g - c.b) / delta, 6.0);
    else if (cmax == c.g) h = (c.b - c.r) / delta + 2.0;
    else                  h = (c.r - c.g) / delta + 4.0;
    return h / 6.0;
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

        // Signal luminance from raw spawn color (before boost)
        float signalLum = dot(sc, vec3(0.299, 0.587, 0.114));

        // Speed: brighter signal → faster launch
        float lumSpeedMul = mix(1.0 - uLumInfluence, 1.0, signalLum);
        float speedMul = 0.4 + pow(r0, 0.3) * 1.6;
        v = vec3(dir * uInitSpeed * speedMul * lumSpeedMul, 0.0, 0.0);

        // Brightness: mostly bright, some dim
        br = 0.3 + 0.7 * pow(r1, 0.3);

        // Boost color for LED visibility
        sc = clamp(sc * 3.0, 0.0, 1.0);

        // Base per-particle drag with small random spread
        pd = uDrag - r2 * uDragSpread;

        // Luminance-based drag: brighter signal → higher pd (travels further)
        pd += signalLum * uLumInfluence * 0.01;

        // Hue-based drag offset: warm hues (red) vs cool hues (blue)
        float hue = rgbToHue(sc);
        float hueFactor = smoothstep(0.1, 0.5, hue) - smoothstep(0.75, 0.95, hue);
        pd += hueFactor * uHueDragOffset;

        pd = clamp(pd, 0.9, 0.9999);
    } else if (br > 0.005) {
        // Alive: physics update with velocity-dependent drag
        // At high speed: full drag effect (pd). At low speed: drag → 1.0 (less deceleration)
        float speedNorm = clamp(abs(v.x) / uInitSpeed, 0.0, 1.0);
        float effectiveDrag = mix(1.0, pd, pow(speedNorm, uDragCurve));
        v.x *= effectiveDrag;
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
