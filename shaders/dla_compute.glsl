// DLA - Diffusion Limited Aggregation
// Edge-seeded growth inward in a 1x2 rectangle
// frozen: 0.0 = walking, 1.0 = aggregated

void main() {
    const uint id = TDIndex();
    if(id >= TDNumElements())
        return;

    vec3 pos = TDIn_P().xyz;
    float isFrozen = TDIn_frozen();
    float ft = TDIn_freezeTime();
    float frame = uTime.x;

    float halfW = 0.5;
    float halfH = 1.0;

    // Very thin edge seed: only outermost 0.003 band
    float edgeDist = min(min(halfW - abs(pos.x), halfH - abs(pos.y)), 999.0);
    bool onEdge = edgeDist < 0.003;

    if(onEdge && isFrozen < 0.5) {
        P[id] = pos;
        frozen[id] = 1.0;
        freezeTime[id] = 0.0;
        Color[id] = vec4(1.0, 1.0, 1.0, 1.0);
        return;
    }

    // Already frozen
    if(isFrozen > 0.5) {
        P[id] = pos;
        frozen[id] = 1.0;
        freezeTime[id] = ft;
        Color[id] = vec4(1.0, 1.0, 1.0, 1.0);
        return;
    }

    // --- Brownian motion ---
    uint seed = id * 1099087573u + uint(frame) * 2654435761u;
    seed ^= seed >> 16u;  seed *= 0x45d9f3bu;  seed ^= seed >> 16u;
    float rx = float(seed & 0xFFFFu) / 65535.0 - 0.5;
    seed = seed * 1099087573u + 12345u;
    float ry = float(seed & 0xFFFFu) / 65535.0 - 0.5;
    seed = seed * 1099087573u + 12345u;
    float rz = float(seed & 0xFFFFu) / 65535.0 - 0.5;

    float stepSize = 0.002;
    vec3 newPos = pos + vec3(rx, ry, rz) * stepSize;

    // Clamp inside bounds
    newPos.x = clamp(newPos.x, -halfW + 0.005, halfW - 0.005);
    newPos.y = clamp(newPos.y, -halfH + 0.005, halfH - 0.005);
    newPos.z = clamp(newPos.z, -0.025, 0.025);

    // --- Check neighbors ---
    uint numN = TDIn_NumNebrs();
    bool shouldFreeze = false;

    for(uint i = 0u; i < numN; i++) {
        uint nIdx = TDIn_Nebr(0u, id, i);
        if(nIdx == 4294967295u) continue;
        float nFrozen = TDIn_frozen(0u, nIdx, 0u);
        if(nFrozen > 0.5) {
            // Very low stickiness for slow dendritic growth
            uint stickSeed = id * 374761393u + uint(frame) * 668265263u;
            stickSeed ^= stickSeed >> 15u;
            float stickRand = float(stickSeed & 0xFFFFu) / 65535.0;
            if(stickRand < 0.05) {
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
        Color[id] = vec4(1.0, 1.0, 1.0, 0.02);
    }
}
