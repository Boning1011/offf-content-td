// DLA - Diffusion Limited Aggregation
// Edge-seeded, noise-controlled growth, variable point scale
// frozen: 0.0 = walking, 1.0 = aggregated
// sNoise: noise texture controlling growth density

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

    // Per-particle scale variation based on id hash
    uint scaleHash = id * 2654435761u;
    scaleHash ^= scaleHash >> 16u;
    float scaleRand = float(scaleHash & 0xFFFFu) / 65535.0;
    float pScale = 0.6 + scaleRand * 0.8;  // range 0.6 - 1.4

    // Thin edge seed
    float edgeDist = min(halfW - abs(pos.x), halfH - abs(pos.y));
    bool onEdge = edgeDist < 0.003;

    if(onEdge && isFrozen < 0.5) {
        P[id] = pos;
        frozen[id] = 1.0;
        freezeTime[id] = 0.0;
        PointScale[id] = pScale;
        Color[id] = vec4(1.0, 1.0, 1.0, 1.0);
        return;
    }

    // Already frozen
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

    float stepSize = 0.002;
    vec3 newPos = pos + vec3(rx, ry, rz) * stepSize;

    newPos.x = clamp(newPos.x, -halfW + 0.005, halfW - 0.005);
    newPos.y = clamp(newPos.y, -halfH + 0.005, halfH - 0.005);
    newPos.z = clamp(newPos.z, -0.025, 0.025);

    // --- Sample noise at particle position for growth control ---
    // Map pos to UV: x[-0.5,0.5]->u[0,1], y[-1,1]->v[0,1]
    vec2 uv = vec2((pos.x + halfW) / (2.0 * halfW),
                    (pos.y + halfH) / (2.0 * halfH));
    float noiseVal = textureLod(sNoise, uv, 0.0).r;

    // --- Check neighbors ---
    uint numN = TDIn_NumNebrs();
    bool shouldFreeze = false;

    for(uint i = 0u; i < numN; i++) {
        uint nIdx = TDIn_Nebr(0u, id, i);
        if(nIdx == 4294967295u) continue;
        float nFrozen = TDIn_frozen(0u, nIdx, 0u);
        if(nFrozen > 0.5) {
            // Stickiness modulated by noise: high noise = more growth
            float baseStick = 0.04;
            float stickChance = baseStick * (0.2 + noiseVal * 1.6);

            uint stickSeed = id * 374761393u + uint(frame) * 668265263u;
            stickSeed ^= stickSeed >> 15u;
            float stickRand = float(stickSeed & 0xFFFFu) / 65535.0;
            if(stickRand < stickChance) {
                shouldFreeze = true;
            }
            break;
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
