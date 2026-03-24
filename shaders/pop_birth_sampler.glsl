// Sample input signal TOP at each source point, write birthCount attribute
// Points 0-1151: left edge (x=0), Points 1152-2303: right edge (x=383)
// Sampler 0: sSignalL — left input (1x1152)
// Sampler 1: sSignalR — right input (1x1152)

uniform float uSpawnScale;   // global multiplier on brightness → birth count
uniform float uLumThreshold;  // minimum brightness to emit (below = no particles)
uniform float uNumRows;      // 1152
uniform float uFrame;

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
    bool fromRight = (pos.x > 190.0);
    float uvY = (pos.y + 0.5) / uNumRows;

    vec4 signal = fromRight
        ? textureLod(sSignalR, vec2(0.5, uvY), 0.0)
        : textureLod(sSignalL, vec2(0.5, uvY), 0.0);
    float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));

    float bc = 0.0;
    if (lum > uLumThreshold) {
        // Only emit where signal is above threshold
        bc = (lum - uLumThreshold) * uSpawnScale;
        // Stochastic rounding for fractional births
        float fractPart = bc - floor(bc);
        float dither = rand(id + uint(uFrame) * 7919u);
        bc = floor(bc) + (dither < fractPart ? 1.0 : 0.0);
    }
    birthCount[id] = bc;

    // Store signal color for children
    scolor[id] = signal.rgb;
    P[id] = pos;
}
