// Particle state update — 4x1152 texture, 4 particles per row
// Column 0-1: left entry (moving right), Column 2-3: right entry (moving left)
// Each texel: R=pos.x, G=vel.x, B=alive, A=spare
// pos.y = row index (implicit from texel y coordinate)
//
// Input 0: previous state (feedback)
// Input 1: left signal (1x1152)
// Input 2: right signal (1x1152)

uniform float uInitSpeed;   // ~4.0 px/frame
uniform float uDrag;        // ~0.99
uniform float uSpawnProb;   // ~0.3
uniform float uWidth;       // 384
uniform float uFrame;

out vec4 fragColor;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    int col = coord.x;   // 0-3: particle slot
    int row = coord.y;   // 0-1151: display row

    bool fromRight = (col >= 2);
    int slot = fromRight ? (col - 2) : col;

    // Read previous state
    vec4 state = texelFetch(sTD2DInputs[0], coord, 0);
    float px    = state.r;
    float vx    = state.g;
    float alive = state.b;

    float uvY = (float(row) + 0.5) / float(textureSize(sTD2DInputs[0], 0).y);

    if (alive < 0.5) {
        // Dead: check spawn
        vec4 signal = fromRight
            ? texture(sTD2DInputs[2], vec2(0.5, uvY))
            : texture(sTD2DInputs[1], vec2(0.5, uvY));
        float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));

        float seed = float(row * 4 + col) * 12.9898 + uFrame * 78.233;
        float roll = hash(seed);
        float threshold = uSpawnProb - float(slot) * 0.15;

        if (lum > 0.3 && roll < threshold) {
            px = fromRight ? (uWidth - 1.0) : 0.0;
            float dir = fromRight ? -1.0 : 1.0;
            float vary = 0.7 + roll * 0.6;
            vx = dir * uInitSpeed * vary;
            alive = 1.0;
        }
    } else {
        // Physics
        vx *= uDrag;
        px += vx;

        if (px < -1.0 || px >= uWidth || abs(vx) < 0.05) {
            vx = 0.0;
            px = -10.0;
            alive = 0.0;
        }
    }

    fragColor = TDOutputSwizzle(vec4(px, vx, alive, 0.0));
}
