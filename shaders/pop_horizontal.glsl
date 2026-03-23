// POP Prototype: horizontal particles with entry speed + drag
// Sampler 0: sSignalL — left edge input signal (1x1152)
// Sampler 1: sSignalR — right edge input signal (1x1152)

uniform float uInitSpeed;   // initial speed (px/frame), ~4.0
uniform float uDrag;        // drag per frame (0.99 = gentle), ~0.99
uniform float uSpawnProb;   // spawn probability per frame, ~0.3
uniform float uWidth;       // display width (384)
uniform float uNumRows;     // number of rows (1152)
uniform float uFrame;       // frame counter

void main() {
    const uint id = TDIndex();
    if (id >= TDNumElements()) return;

    // Read previous state from feedback
    vec3 rp = TDIn_rpos().xyz;
    vec3 v  = TDIn_vel().xyz;
    vec4 col = TDIn_Color();

    // Particle assignment: first half = left entry, second half = right entry
    uint halfCount = TDNumElements() / 2u;
    bool fromRight = (id >= halfCount);
    uint localId = fromRight ? (id - halfCount) : id;

    uint pPerRow = max(1u, halfCount / uint(uNumRows));
    uint row  = localId / pPerRow;
    uint slot = localId % pPerRow;

    float uvY = (float(row) + 0.5) / uNumRows;
    bool isAlive = (abs(v.x) > 0.05);

    if (!isAlive) {
        // Sample input signal
        vec4 signal = fromRight
            ? textureLod(sSignalR, vec2(0.5, uvY), 0.0)
            : textureLod(sSignalL, vec2(0.5, uvY), 0.0);
        float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));

        // Stochastic spawn
        float seed = float(id) * 12.9898 + uFrame * 78.233;
        float roll = fract(sin(seed) * 43758.5453);
        float threshold = uSpawnProb - float(slot) * 0.1;

        if (lum > 0.3 && roll < threshold) {
            rp = vec3(fromRight ? (uWidth - 1.0) : 0.0, float(row), 0.0);
            float dir = fromRight ? -1.0 : 1.0;
            float vary = 0.7 + roll * 0.6;
            v = vec3(dir * uInitSpeed * vary, 0.0, 0.0);
            col = vec4(signal.rgb, 1.0);
        }
    } else {
        // Physics: exponential drag
        v.x *= uDrag;
        rp += v;

        // Kill if off-screen or too slow
        if (rp.x < -1.0 || rp.x >= uWidth || abs(v.x) < 0.05) {
            v = vec3(0.0);
            rp = vec3(-10.0, -10.0, 0.0);
            col = vec4(0.0);
        }
    }

    // Snap P for pixel-perfect rendering, keep rpos for physics
    P[id] = vec3(round(rp.x), round(rp.y), 0.0);
    vel[id] = v;
    rpos[id] = rp;
    Color[id] = col;
}
