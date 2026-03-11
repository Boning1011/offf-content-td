// Particle Life — absolute position per frame (no feedback)
// Each particle's position is computed analytically from time

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

vec2 hash12(float p) {
    vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

#define NS 5

// Species center: cyclic chase encoded analytically
vec2 speciesCenter(int s, float t) {
    float fi = float(s);
    float tau = 6.2831853;

    // Pentagon rotation — each species at slightly different speed = chasing
    float baseAngle = fi * tau / float(NS);
    float speed = 0.1 + fi * 0.015;
    float angle = baseAngle + t * speed;

    // Pulsing radius
    float r = 0.3 + 0.07 * sin(t * 0.2 + fi * 1.3);

    vec2 c = vec2(cos(angle) * r, sin(angle) * r * 0.6);

    // Epicycle (wobbly orbit within orbit)
    float epiA = t * (0.3 + fi * 0.05) + fi * 2.0;
    c += vec2(cos(epiA), sin(epiA)) * 0.05;

    return c;
}

void main() {
    const uint id = TDIndex();
    if (id >= TDNumElements()) return;

    float t = uTime.x;

    // Per-particle deterministic randomness
    float r0 = hash11(float(id) * 1.731);
    float r1 = hash11(float(id) * 3.917);
    float r2 = hash11(float(id) * 5.291);
    float r3 = hash11(float(id) * 7.113);
    float r4 = hash11(float(id) * 9.337);

    // === Species assignment ===
    int me = int(mod(r0 * float(NS), float(NS)));

    // === Colony center ===
    vec2 center = speciesCenter(me, t);

    // === Position within colony (ring + orbit) ===
    // Which ring (concentric layers)
    float ringIdx = floor(r1 * 5.0);
    float ringR = 0.01 + ringIdx * 0.015 + r2 * 0.006;

    // Breathing: rings expand/contract
    ringR *= 1.0 + 0.2 * sin(t * 0.3 + float(me) * 1.5);

    // Angle on the ring — each particle orbits at its own speed
    float orbitDir = mod(ringIdx, 2.0) < 1.0 ? 1.0 : -1.0;
    float orbitSpeed = 0.5 + r3 * 0.4;
    float angle = r4 * 6.2831853 + t * orbitSpeed * orbitDir;

    vec2 offset = vec2(cos(angle), sin(angle)) * ringR;

    // === Bacteria wiggle ===
    float wPhase = t * (6.0 + r0 * 4.0) + r0 * 50.0;
    float wMag = 0.004 + r1 * 0.003;
    vec2 wiggle = vec2(
        sin(wPhase) * wMag,
        cos(wPhase * 1.3) * wMag * 0.7
    );

    // === Chase/flee: lean toward prey, away from predator ===
    int prey = int(mod(float(me) + 1.0, float(NS)));
    int predator = int(mod(float(me) + 4.0, float(NS)));

    vec2 preyCenter = speciesCenter(prey, t);
    vec2 predCenter = speciesCenter(predator, t);

    // Particles on the prey-facing side lean toward prey
    vec2 toPrey = normalize(preyCenter - center + vec2(0.001));
    float preyAlignment = dot(normalize(offset + vec2(0.001)), toPrey);
    vec2 chaseLean = toPrey * 0.02 * max(preyAlignment, 0.0);

    // Particles on the predator-facing side lean away
    vec2 fromPred = normalize(center - predCenter + vec2(0.001));
    float predAlignment = dot(normalize(offset + vec2(0.001)), -fromPred);
    vec2 fleeLean = fromPred * 0.015 * max(predAlignment, 0.0);

    // === Final position ===
    vec2 pos = center + offset + wiggle + chaseLean + fleeLean;

    // Boundary
    pos = clamp(pos, vec2(-0.8, -0.5), vec2(0.8, 0.5));

    P[id] = vec3(pos, 0.0);
}
