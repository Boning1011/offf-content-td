// DLA with aggressive tip enhancement for dendritic branching
// Key insight: stickiness must be EXTREMELY low to prevent wall-advance

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

    // Per-particle scale
    uint scaleHash = id * 2654435761u;
    scaleHash ^= scaleHash >> 16u;
    float pScale = 0.6 + float(scaleHash & 0xFFFFu) / 65535.0 * 0.8;

    // --- Sparse seeds: corners + mid-edges ---
    if(isFrozen < 0.5) {
        vec2 p2 = vec2(pos.x, pos.y);
        float seeds[8] = float[8](
            length(p2 - vec2(-halfW, -halfH)),
            length(p2 - vec2( halfW, -halfH)),
            length(p2 - vec2(-halfW,  halfH)),
            length(p2 - vec2( halfW,  halfH)),
            length(p2 - vec2(0.0, -halfH)),
            length(p2 - vec2(0.0,  halfH)),
            length(p2 - vec2(-halfW, 0.0)),
            length(p2 - vec2( halfW, 0.0))
        );
        float minD = 999.0;
        for(int i = 0; i < 8; i++) minD = min(minD, seeds[i]);
        if(minD < 0.015) {
            P[id] = pos;
            frozen[id] = 1.0;
            freezeTime[id] = 0.0;
            PointScale[id] = pScale;
            Color[id] = vec4(1.0, 1.0, 1.0, 1.0);
            return;
        }
    }

    if(isFrozen > 0.5) {
        P[id] = pos;
        frozen[id] = 1.0;
        freezeTime[id] = ft;
        PointScale[id] = pScale;
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

    float stepSize = 0.008;
    vec3 newPos = pos + vec3(rx, ry, rz) * stepSize;
    newPos.x = clamp(newPos.x, -halfW, halfW);
    newPos.y = clamp(newPos.y, -halfH, halfH);
    newPos.z = clamp(newPos.z, -0.025, 0.025);

    // Noise
    vec2 uv = vec2((pos.x + halfW) / (2.0 * halfW),
                    (pos.y + halfH) / (2.0 * halfH));
    float noiseVal = textureLod(sNoise, uv, 0.0).r;

    // --- Neighbor scan ---
    uint numN = TDIn_NumNebrs();
    uint frozenCount = 0u;

    for(uint i = 0u; i < numN; i++) {
        uint nIdx = TDIn_Nebr(0u, id, i);
        if(nIdx == 4294967295u) continue;
        if(TDIn_frozen(0u, nIdx, 0u) > 0.5) frozenCount++;
    }

    bool shouldFreeze = false;
    if(frozenCount > 0u) {
        // Extreme tip enhancement with very low base rate
        // 1 frozen neighbor (pure tip): 0.5%
        // 2 frozen neighbors: 0.125%
        // 3+: essentially 0
        float exposure = 1.0 / (float(frozenCount) * float(frozenCount) * float(frozenCount));
        float stickChance = 0.005 * exposure * (0.2 + noiseVal * 1.6);

        uint stickSeed = id * 374761393u + uint(frame) * 668265263u;
        stickSeed ^= stickSeed >> 15u;
        float stickRand = float(stickSeed & 0xFFFFu) / 65535.0;
        if(stickRand < stickChance) {
            shouldFreeze = true;
        }
    }

    if(shouldFreeze) {
        P[id] = pos;
        frozen[id] = 1.0;
        freezeTime[id] = frame;
        PointScale[id] = pScale;
        Color[id] = vec4(1.0, 1.0, 1.0, 1.0);
    } else {
        float a = 0.03;
        P[id] = newPos;
        frozen[id] = 0.0;
        freezeTime[id] = 0.0;
        PointScale[id] = pScale * 0.5;
        Color[id] = vec4(a, a, a, a);
    }
}
