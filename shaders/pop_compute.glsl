// POP compute shader: horizontal particles with drag
// Particles are born at origin by Particle POP, this shader assigns position/velocity.
//
// Sampler 0: sSignalL — left edge input signal (1x1152)
// Sampler 1: sSignalR — right edge input signal (1x1152)

uniform float uInitSpeed;
uniform float uDrag;
uniform float uDragSpread;
uniform float uFadeRate;
uniform float uSpawnScale;
uniform float uWidth;       // 384
uniform float uNumRows;     // 1152
uniform float uFrame;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

void main() {
    const uint id = TDIndex();
    if (id >= TDNumElements()) return;

    vec3 pos = TDIn_P().xyz;
    vec3 v   = TDIn_vel().xyz;
    float br = TDIn_bright().x;
    vec3 sc  = TDIn_scolor().xyz;
    float pd = TDIn_pdrag().x;

    // Detect new particle: v.x == 0 means just born or reset
    bool isNew = (abs(v.x) < 0.001 && br < 0.001);

    if (isNew) {
        float fid = float(id);
        float r0 = hash(fid * 12.9898 + uFrame * 78.233);
        float r1 = hash(fid * 37.719 + uFrame * 13.337);
        float r2 = hash(fid * 91.127 + uFrame * 47.713);
        float r3 = hash(fid * 53.431 + uFrame * 29.591);
        float r4 = hash(fid * 71.317 + uFrame * 61.157);

        int row = int(r0 * uNumRows);
        bool fromRight = (r1 > 0.5);
        float uvY = (float(row) + 0.5) / uNumRows;

        vec4 signal = fromRight
            ? textureLod(sSignalR, vec2(0.5, uvY), 0.0)
            : textureLod(sSignalL, vec2(0.5, uvY), 0.0);
        float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));

        if (lum * uSpawnScale > r2) {
            pos = vec3(fromRight ? (uWidth - 1.0) : 0.0, float(row), 0.0);
            float dir = fromRight ? -1.0 : 1.0;
            float speedMul = 0.4 + pow(r3, 0.3) * 1.6;
            v = vec3(dir * uInitSpeed * speedMul, 0.0, 0.0);
            br = 0.3 + 0.7 * pow(r4, 0.3);
            pd = uDrag - pow(r3, 2.0) * uDragSpread;
            pd = clamp(pd, 0.9, 0.9999);
            sc = signal.rgb;
        } else {
            pos = vec3(-10.0, -10.0, 0.0);
            v = vec3(0.0);
            br = 0.0;
        }
    } else if (br > 0.005) {
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
}
