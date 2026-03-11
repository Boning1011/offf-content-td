// DLA - Diffusion Limited Aggregation with tip enhancement
//
// Uniforms (Vectors page on GLSL POP):
//   uTime.x    = frame counter
//   uParams    = (stickiness, stepSize, seedRadius, tipPower)
//   uBounds    = (halfW, halfH, walkAlpha, noiseStrength)
//   uScale     = (scaleMin, scaleRange, walkScaleMult, zDepth)

void main() {
    const uint id = TDIndex();
    if(id >= TDNumElements())
        return;

    vec3 pos = TDIn_P().xyz;
    float isFrozen = TDIn_frozen();
    float ft = TDIn_freezeTime();
    float frame = uTime.x;

    // Unpack uniforms
    float stickiness   = uParams.x;
    float stepSize     = uParams.y;
    float seedRadius   = uParams.z;
    float tipPower     = uParams.w;

    float halfW        = uBounds.x;
    float halfH        = uBounds.y;
    float walkAlpha    = uBounds.z;
    float noiseStr     = uBounds.w;

    float scaleMin     = uScale.x;
    float scaleRange   = uScale.y;
    float walkScaleMul = uScale.z;
    float zDepth       = uScale.w;

    // Per-particle scale variation
    uint scaleHash = id * 2654435761u;
    scaleHash ^= scaleHash >> 16u;
    float pScale = scaleMin + float(scaleHash & 0xFFFFu) / 65535.0 * scaleRange;

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
        if(minD < seedRadius) {
            P[id] = pos;
            frozen[id] = 1.0;
            freezeTime[id] = 0.0;
            PointScale[id] = pScale;
            Color[id] = vec4(1.0, 1.0, 1.0, 1.0);
            return;
        }
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

    vec3 newPos = pos + vec3(rx, ry, rz) * stepSize;
    newPos.x = clamp(newPos.x, -halfW, halfW);
    newPos.y = clamp(newPos.y, -halfH, halfH);
    newPos.z = clamp(newPos.z, -zDepth, zDepth);

    // Noise modulation
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
        // Tip enhancement: fewer frozen neighbors = more exposed = sticks easier
        float exposure = 1.0 / pow(float(frozenCount), tipPower);
        float stickChance = stickiness * exposure * (0.2 + noiseVal * noiseStr);

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
        P[id] = newPos;
        frozen[id] = 0.0;
        freezeTime[id] = 0.0;
        PointScale[id] = pScale * walkScaleMul;
        Color[id] = vec4(walkAlpha, walkAlpha, walkAlpha, walkAlpha);
    }
}
