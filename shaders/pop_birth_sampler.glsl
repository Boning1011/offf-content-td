// Sample input signal TOP at each source point, write birthCount attribute
// Points 0-1151: left edge (x=0), Points 1152-2303: right edge (x=383)
// Sampler 0: sSignalL — left input (1x1152)
// Sampler 1: sSignalR — right input (1x1152)

uniform float uSpawnScale;  // global multiplier on brightness → birth count
uniform float uNumRows;     // 1152
uniform float uFrame;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
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

    // Stochastic rounding: birthCount=0.3 → 30% chance of 1 per frame
    float bc = lum * uSpawnScale;
    float fractPart = bc - floor(bc);
    float dither = hash(float(id) * 7.31 + uFrame * 0.17);
    bc = floor(bc) + (dither < fractPart ? 1.0 : 0.0);
    birthCount[id] = bc;

    // Also store signal color for the Particle POP to pass to children
    scolor[id] = signal.rgb;

    // Pass through P unchanged
    P[id] = pos;
}
