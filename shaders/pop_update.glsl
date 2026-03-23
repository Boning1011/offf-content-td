// Particle state update — 16x1152 texture, 8 particles per side per row
// Column 0-7: left entry (moving right), Column 8-15: right entry (moving left)
// Each texel: R=pos.x, G=vel.x, B=brightness, A=per-particle drag
//
// Input 0: previous state (feedback)
// Input 1: left signal (1x1152)
// Input 2: right signal (1x1152)

uniform float uInitSpeed;    // base init speed (~1.5 px/frame)
uniform float uDrag;         // base drag (~0.995)
uniform float uDragSpread;   // drag variation range (~0.015)
uniform float uSpawnScale;   // multiplier on signal lum for spawn chance
uniform float uFadeRate;     // brightness decay per frame (~0.002)
uniform float uWidth;        // 384
uniform float uFrame;

out vec4 fragColor;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

// Long-tail distribution: many values near 1, few near 0
float longTail(float x, float power) {
    return pow(x, power);
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    int col = coord.x;   // 0-15: particle slot
    int row = coord.y;   // 0-1151: display row
    int perSide = 8;

    bool fromRight = (col >= perSide);
    int slot = fromRight ? (col - perSide) : col;

    // Read previous state
    vec4 state = texelFetch(sTD2DInputs[0], coord, 0);
    float px         = state.r;
    float vx         = state.g;
    float brightness = state.b;
    float pDrag      = state.a;

    float uvY = (float(row) + 0.5) / float(textureSize(sTD2DInputs[0], 0).y);
    bool isAlive = (brightness > 0.005 && abs(vx) > 0.01);

    if (!isAlive) {
        // Dead: check spawn
        vec4 signal = fromRight
            ? texture(sTD2DInputs[2], vec2(0.5, uvY))
            : texture(sTD2DInputs[1], vec2(0.5, uvY));
        float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));

        // Multiple independent random values per particle
        float id = float(row * 16 + col);
        float r0 = hash(id * 12.9898 + uFrame * 78.233);
        float r1 = hash(id * 37.719 + uFrame * 13.337);
        float r2 = hash(id * 91.127 + uFrame * 47.713);
        float r3 = hash(id * 53.431 + uFrame * 29.591);

        // Spawn threshold: signal brightness × scale, stagger by slot
        float threshold = lum * uSpawnScale - float(slot) * 0.08;

        if (lum > 0.05 && r0 < threshold) {
            px = fromRight ? (uWidth - 1.0) : 0.0;
            float dir = fromRight ? -1.0 : 1.0;

            // Long-tail speed: most particles at base speed, some much faster
            float speedMul = 0.5 + longTail(r1, 0.3) * 1.5;
            vx = dir * uInitSpeed * speedMul;

            // Long-tail brightness: most bright, some very dim
            brightness = longTail(r2, 0.4);

            // Per-particle drag: clustered near uDrag, some with more drag
            pDrag = uDrag - longTail(r3, 2.0) * uDragSpread;
            pDrag = clamp(pDrag, 0.9, 0.9999);
        }
    } else {
        // Physics
        vx *= pDrag;
        px += vx;
        brightness -= uFadeRate;

        if (px < -1.0 || px >= uWidth || brightness < 0.005 || abs(vx) < 0.01) {
            vx = 0.0;
            px = -10.0;
            brightness = 0.0;
            pDrag = 0.0;
        }
    }

    fragColor = TDOutputSwizzle(vec4(px, vx, brightness, pDrag));
}
