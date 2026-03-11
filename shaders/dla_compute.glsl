// DLA - Diffusion Limited Aggregation
// frozen: 0.0 = walking (brownian motion), 1.0 = aggregated

void main() {
    const uint id = TDIndex();
    if(id >= TDNumElements())
        return;

    vec3 pos = TDIn_P().xyz;
    float isFrozen = TDIn_frozen();
    float ft = TDIn_freezeTime();
    float frame = uTime.x;

    // Seed: first particle frozen at origin
    if(id == 0u) {
        P[id] = vec3(0.0);
        frozen[id] = 1.0;
        freezeTime[id] = 0.0;
        Color[id] = vec4(1.0, 1.0, 1.0, 1.0);
        return;
    }

    // Already frozen — just maintain state + color
    if(isFrozen > 0.5) {
        P[id] = pos;
        frozen[id] = 1.0;
        freezeTime[id] = ft;
        // Rainbow color cycling based on when frozen
        float t = ft / 800.0;
        float r = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 6.2831 * 3.0));
        float g = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 6.2831 * 3.0 + 2.094));
        float b = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 6.2831 * 3.0 + 4.189));
        Color[id] = vec4(r, g, b, 1.0);
        return;
    }

    // --- Brownian motion for walking particles ---
    uint seed = id * 1099087573u + uint(frame) * 2654435761u;
    seed ^= seed >> 16u;  seed *= 0x45d9f3bu;  seed ^= seed >> 16u;
    float rx = float(seed & 0xFFFFu) / 65535.0 - 0.5;
    seed = seed * 1099087573u + 12345u;
    float ry = float(seed & 0xFFFFu) / 65535.0 - 0.5;
    seed = seed * 1099087573u + 12345u;
    float rz = float(seed & 0xFFFFu) / 65535.0 - 0.5;

    float stepSize = 0.04;
    vec3 newPos = pos + vec3(rx, ry, rz) * stepSize;

    // Gentle drift toward center to keep particles near crystal
    float dist = length(newPos);
    if(dist > 0.3) {
        newPos -= normalize(newPos) * 0.005 * min(dist, 3.0);
    }

    // Hard bounds - respawn far if too far out
    if(dist > 6.0) {
        // Teleport to random position on a shell around the crystal
        newPos = normalize(newPos) * (2.0 + float(seed & 0xFFu) / 255.0 * 2.0);
    }

    // --- Check neighbors for frozen particles ---
    uint numN = TDIn_NumNebrs();
    bool shouldFreeze = false;

    for(uint i = 0u; i < numN; i++) {
        uint nIdx = TDIn_Nebr(0u, id, i);
        if(nIdx == 4294967295u) continue;
        float nFrozen = TDIn_frozen(0u, nIdx, 0u);
        if(nFrozen > 0.5) {
            // Stickiness: 70% chance to stick on contact
            // Use hash of id+frame for randomness
            uint stickSeed = id * 374761393u + uint(frame) * 668265263u;
            stickSeed ^= stickSeed >> 15u;
            float stickRand = float(stickSeed & 0xFFFFu) / 65535.0;
            if(stickRand < 0.7) {
                shouldFreeze = true;
            }
            break;
        }
    }

    if(shouldFreeze) {
        P[id] = pos;
        frozen[id] = 1.0;
        freezeTime[id] = frame;
        Color[id] = vec4(1.0, 1.0, 1.0, 1.0);
    } else {
        P[id] = newPos;
        frozen[id] = 0.0;
        freezeTime[id] = 0.0;
        Color[id] = vec4(0.08, 0.08, 0.1, 0.15);
    }
}
