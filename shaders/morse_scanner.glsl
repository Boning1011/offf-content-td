// Morse Code Scanner - horizontal streaming dots/dashes per scanline
uniform float uTime;
out vec4 fragColor;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

float noise1D(float x, float seed) {
    float i = floor(x);
    float f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash(i + seed), hash(i + 1.0 + seed), f);
}

void main()
{
    vec2 uv = vUV.st;
    vec2 res = uTDOutputInfo.res.zw;
    float row = floor(uv.y * res.y);
    float rowSeed = hash(row * 13.37);

    // Each row scrolls at a different speed
    float speed = 30.0 + rowSeed * 80.0;
    float x = uv.x * res.x + uTime * speed;

    // Scale to cell units
    float cellScale = 6.0;
    float nx = x / cellScale;

    // Layer 1: slow wave â€” creates long on/off regions (dashes & gaps)
    float n1 = noise1D(nx * 0.05, row * 7.31);

    // Layer 2: medium detail â€” breaks up edges
    float n2 = noise1D(nx * 0.2, row * 13.17) * 0.25;

    // Layer 3: sparse spikes â€” occasional isolated dots
    float spike = noise1D(nx * 0.8, row * 29.53);
    spike = smoothstep(0.85, 0.9, spike) * 0.6;

    float combined = n1 + n2 + spike;

    // High threshold: mostly dark, signals break through
    float threshold = 0.62 + rowSeed * 0.1;
    float morse = step(threshold, combined);

    fragColor = TDOutputSwizzle(vec4(vec3(morse), 1.0));
}
