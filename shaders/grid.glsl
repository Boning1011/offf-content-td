// --- hash helpers ---
float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Compute grid position for any point index
vec3 gridPosFor(uint pid, int cols, int rows, uint N) {
    int r = int(pid) / cols;
    int c = int(pid) % cols;
    int cInRow = (r < rows - 1) ? cols : int(N) - r * cols;
    float pu = (cInRow > 1) ? float(c) / float(cInRow - 1) * 2.0 - 1.0 : 0.0;
    float pv = (rows > 1) ? float(r) / float(rows - 1) * 2.0 - 1.0 : 0.0;
    return vec3(pu * 0.5, pv * 1.0, 0.0);
}

void main() {
    const uint id = TDIndex();
    uint N = TDNumElements();
    if(id >= N)
        return;

    float t = uTime.x;

    // --- grid layout ---
    int cols = int(ceil(sqrt(float(N) / 2.0)));
    int rows = int(ceil(float(N) / float(cols)));

    vec3 gridPos = gridPosFor(id, cols, rows, N);
    int row = int(id) / cols;
    int col = int(id) % cols;

    // --- multiple overlapping grouping scales ---
    float pointRand  = hash11(float(id) * 1.731);
    float pairRand   = hash21(vec2(float(col / 2), float(row)));
    float patchRand  = hash21(vec2(float(col / 3), float(row / 2)));
    float rowRand    = hash11(float(row) * 7.13);

    // Blend different scales — more patch weight for group feel
    float role = pointRand * 0.3 + pairRand * 0.25 + patchRand * 0.35 + rowRand * 0.1;

    // --- behavior thresholds ---
    // ~60% static, ~35% local wave, ~5% swappers
    float isStatic  = step(role, 0.60);
    float isSwapper = step(0.95, role);
    float isWave    = (1.0 - isStatic) * (1.0 - isSwapper);

    // --- row shift events (horizontal, whole row) ---
    float rowCycle = sin(t * 0.3 + rowRand * 40.0);
    float rowShift = smoothstep(0.92, 1.0, rowCycle);
    float rowDx = rowShift * (rowRand - 0.5) * 0.15;

    // --- column shift events (vertical, whole column) ---
    float colRand = hash11(float(col) * 11.37);
    float colCycle = sin(t * 0.25 + colRand * 50.0);
    float colShift = smoothstep(0.90, 1.0, colCycle);
    float colDy = colShift * (colRand - 0.5) * 0.25;

    // --- local wave (subtle wobble) ---
    float cellW = 1.0 / float(cols);
    float cellH = 2.0 / float(rows);
    float wp = pointRand * 6.283;
    float wf = 0.6 + pointRand * 1.5;
    float localDx = sin(t * wf + wp) * cellW * 0.15;
    float localDy = cos(t * wf * 0.7 + wp * 1.3) * cellH * 0.1;

    // --- swap: exchange positions with a distant partner ---
    // Force partner far away: offset row by ~half grid, col by varied amount
    float h1 = hash11(float(id) * 3.917);
    float h2 = hash11(float(id) * 7.291);
    int partnerRow = (row + rows / 2 + int(h1 * float(rows / 3))) % rows;
    int partnerCol = (col + cols / 2 + int(h2 * float(cols / 3))) % cols;
    uint partnerId = clamp(uint(partnerRow * cols + partnerCol), 0u, N - 1u);
    vec3 partnerPos = gridPosFor(partnerId, cols, rows, N);

    // Periodic swap: smoothly go to partner and back
    float swapSpeed = 0.4 + hash11(float(id) * 5.23) * 0.3;
    float swapPhase = hash11(float(id) * 2.11) * 6.283;
    float swapT = sin(t * swapSpeed + swapPhase) * 0.5 + 0.5; // 0..1
    // Sharpen the transition so it rests at endpoints
    swapT = smoothstep(0.1, 0.9, swapT);

    vec3 swapPos = mix(gridPos, partnerPos, swapT);

    // --- compose ---
    vec3 finalPos = gridPos;

    // Row shift (horizontal) and column shift (vertical) for non-static
    finalPos.x += rowDx * (1.0 - isStatic);
    finalPos.y += colDy * (1.0 - isStatic);

    // Local wave
    finalPos.x += localDx * isWave;
    finalPos.y += localDy * isWave;

    // Swappers: override position entirely
    finalPos = mix(finalPos, swapPos, isSwapper);

    P[id] = finalPos;
}
