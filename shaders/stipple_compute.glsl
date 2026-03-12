// Stippling / Halftone — image-driven particle density
//
// Sampler: sImage = grayscale source (Noise TOP, etc.)
// Uniform: uParams.x = drift strength, uParams.y = jitter amount, uParams.z = frame counter
//
// Dark areas keep more particles, bright areas reject them.
// Feedback provides frame-to-frame persistence for smooth animation.

void main() {
    const uint id = TDIndex();
    if (id >= TDNumElements())
        return;

    vec3 prevPos = TDIn_P().xyz;

    // Map particle XY [-0.5, 0.5] → UV [0, 1]
    vec2 uv = prevPos.xy + 0.5;

    // Sample source brightness (luminance)
    vec3 samp = textureLod(sImage, uv, 0.0).rgb;
    float brightness = dot(samp, vec3(0.299, 0.587, 0.114));
    float darkness = 1.0 - brightness;

    // Stable per-particle random threshold (does not change per frame)
    uint h = id * 2654435761u;
    h ^= h >> 16u;
    float threshold = float(h & 0xFFFFu) / 65535.0;

    // Rejection: hide particle if area is too bright for its threshold
    if (threshold > darkness * 1.2 + 0.05) {
        P[id] = vec3(99.0, 99.0, 0.0);
        Color[id] = vec4(0.0);
        return;
    }

    // --- Gradient drift toward darker regions ---
    float drift = uParams.x;   // ~0.15
    float eps = 0.004;
    float bR = dot(textureLod(sImage, uv + vec2(eps, 0.0), 0.0).rgb, vec3(0.299, 0.587, 0.114));
    float bU = dot(textureLod(sImage, uv + vec2(0.0, eps), 0.0).rgb, vec3(0.299, 0.587, 0.114));
    vec2 grad = vec2(bR - brightness, bU - brightness);
    vec2 newPos = prevPos.xy - grad * drift;

    // --- Small per-frame jitter for organic movement ---
    float jitter = uParams.y;  // ~0.0008
    float frame = uParams.z;
    uint seed = id * 1099087573u + uint(frame) * 2654435761u;
    seed ^= seed >> 16u; seed *= 0x45d9f3bu; seed ^= seed >> 16u;
    float r1 = float(seed & 0xFFFFu) / 65535.0 - 0.5;
    seed = seed * 1099087573u + 12345u;
    float r2 = float(seed & 0xFFFFu) / 65535.0 - 0.5;
    newPos += vec2(r1, r2) * jitter;

    // Clamp to image bounds
    newPos = clamp(newPos, vec2(-0.5), vec2(0.5));

    P[id] = vec3(newPos, 0.0);
    Color[id] = vec4(1.0, 1.0, 1.0, 1.0);
}
