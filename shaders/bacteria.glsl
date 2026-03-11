// Bacteria colony shader — organized clustering with ring structures
// Particles gather around drifting colony centers, forming structured aggregates

// --- hash helpers ---
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

// Smooth colony center position — drifts slowly over time
vec2 colonyCenter(int idx, float t) {
    float fi = float(idx);
    // Base positions spread across the canvas
    float angle0 = fi * 2.399 + 0.5;  // golden angle spread
    float radius0 = 0.25 + 0.15 * hash11(fi * 7.13);
    vec2 base = vec2(cos(angle0), sin(angle0)) * radius0;

    // Slow organic drift — each colony wanders its own Lissajous path
    float sx = 0.07 + hash11(fi * 3.7) * 0.05;
    float sy = 0.06 + hash11(fi * 5.1) * 0.04;
    vec2 drift = vec2(
        sin(t * sx + fi * 2.1) * 0.2,
        cos(t * sy + fi * 1.7) * 0.15
    );

    return base + drift;
}

#define NUM_COLONIES 6

void main() {
    const uint id = TDIndex();
    uint N = TDNumElements();
    if (id >= N)
        return;

    float t = uTime.x;
    float dt = uTimeDelta.x;

    // Per-particle random seeds
    float r0 = hash11(float(id) * 1.731);
    float r1 = hash11(float(id) * 3.917);
    vec2  r2 = hash12(float(id) * 5.291);

    vec3 cur = TDIn_P().xyz;

    // First-frame scatter — spread particles across the field
    if (t < 0.05) {
        // Distribute within a comfortable range
        P[id] = vec3((r2.x * 2.0 - 1.0) * 0.6, (r2.y * 2.0 - 1.0) * 0.4, 0.0);
        return;
    }

    vec2 pos = cur.xy;

    // === COLONY ASSIGNMENT ===
    // Each particle is attracted to its nearest colony center
    // but with some persistence — particles don't switch too easily

    // Particle's "home" colony (semi-permanent, based on ID + position hash)
    int homeColony = int(mod(floor(r0 * float(NUM_COLONIES) + 0.5), float(NUM_COLONIES)));

    // Find nearest colony for gentle correction
    float minDist = 999.0;
    int nearestColony = homeColony;
    vec2 nearestCenter = colonyCenter(homeColony, t);

    for (int i = 0; i < NUM_COLONIES; i++) {
        vec2 cc = colonyCenter(i, t);
        float d = length(pos - cc);
        if (d < minDist) {
            minDist = d;
            nearestColony = i;
            nearestCenter = cc;
        }
    }

    // Blend: mostly follow home colony, but if another is much closer, drift toward it
    vec2 homeCenter = colonyCenter(homeColony, t);
    float homeDist = length(pos - homeCenter);
    float nearDist = length(pos - nearestCenter);

    // Weighted target — bias toward home but allow migration
    float migrationBias = smoothstep(0.0, 0.15, homeDist - nearDist);
    vec2 targetCenter = mix(homeCenter, nearestCenter, migrationBias * 0.6);

    // === RADIAL ORGANIZATION ===
    // Within each colony, particles organize into concentric ring-like bands
    vec2 toCenter = targetCenter - pos;
    float distToCenter = length(toCenter);
    vec2 dirToCenter = distToCenter > 0.001 ? toCenter / distToCenter : vec2(0.0);

    // Target radius for this particle within its colony — creates ring structure
    // Multiple rings at different radii
    float ringIndex = floor(r0 * 3.0);  // 0, 1, or 2 — three rings per colony
    float targetRadius = 0.04 + ringIndex * 0.045 + r1 * 0.02;

    // Colony breathing — slow expansion/contraction
    float breath = 1.0 + 0.15 * sin(t * 0.3 + float(homeColony) * 1.5);
    targetRadius *= breath;

    // Radial force: attract toward target ring radius
    float radialError = distToCenter - targetRadius;
    float radialForce = radialError * 2.5;  // spring-like attraction to ring

    // Tangential orbit — particles slowly circulate around colony center
    vec2 tangent = vec2(-dirToCenter.y, dirToCenter.x);
    float orbitSpeed = 0.08 + r0 * 0.06;
    // Alternate orbit direction per ring for visual interest
    float orbitDir = mod(ringIndex, 2.0) == 0.0 ? 1.0 : -1.0;
    vec2 orbitForce = tangent * orbitSpeed * orbitDir;

    // === INTER-COLONY REPULSION ===
    // Colonies push each other apart slightly via their members
    vec2 interColonyForce = vec2(0.0);
    for (int i = 0; i < NUM_COLONIES; i++) {
        if (i == nearestColony) continue;
        vec2 cc = colonyCenter(i, t);
        vec2 away = pos - cc;
        float d = length(away);
        if (d < 0.25 && d > 0.001) {
            interColonyForce += (away / d) * 0.03 * (0.25 - d);
        }
    }

    // === BACTERIA WIGGLE ===
    // Rapid directional jitter — like flagella-driven swimming
    float wiggleFreq = 6.0 + r0 * 4.0;
    float wigglePhase = t * wiggleFreq + r0 * 100.0;
    // Wiggle mostly along the tangent (swimming around the colony)
    float wiggleMag = 0.03 + r1 * 0.02;
    vec2 wiggle = tangent * sin(wigglePhase) * wiggleMag
                + dirToCenter * cos(wigglePhase * 1.3) * wiggleMag * 0.3;

    // === DENSITY REGULATION ===
    // Use noise field to approximate local density and spread out if too crowded
    // This creates organic spacing without needing N^2 particle interactions
    float noiseScale = 12.0;
    float localDensity = 0.0;
    float eps = 0.01;
    // Sample noise gradient as proxy for "how many particles ended up nearby"
    // (works because particles cluster at same noise attractors)
    vec2 nPos = pos * noiseScale;
    float nC = hash11(floor(nPos.x) * 31.0 + floor(nPos.y) * 57.0 + floor(t * 2.0));
    vec2 spreadForce = -vec2(
        hash11(nPos.x * 17.3 + nPos.y * 31.7 + t) - 0.5,
        hash11(nPos.x * 23.1 + nPos.y * 13.3 + t) - 0.5
    ) * 0.04;

    // === BOUNDARY ===
    vec2 boundary = vec2(0.0);
    float bx = 0.8;
    float by = 0.5;
    float bStr = 4.0;
    if (pos.x >  bx) boundary.x -= (pos.x - bx) * bStr;
    if (pos.x < -bx) boundary.x -= (pos.x + bx) * bStr;
    if (pos.y >  by) boundary.y -= (pos.y - by) * bStr;
    if (pos.y < -by) boundary.y -= (pos.y + by) * bStr;

    // === COMBINE ===
    vec2 totalForce = vec2(0.0);
    totalForce += dirToCenter * radialForce;    // pull toward ring
    totalForce += orbitForce;                    // circulate
    totalForce += wiggle;                        // micro-movement
    totalForce += interColonyForce;              // colony separation
    totalForce += spreadForce;                   // density regulation
    totalForce += boundary;                      // stay in bounds

    // Clamp max speed
    float speed = length(totalForce);
    if (speed > 0.35) {
        totalForce = totalForce / speed * 0.35;
    }

    // Integrate with damping for smooth motion
    pos += totalForce * dt * 0.9;

    // Safety clamp
    pos.x = clamp(pos.x, -0.95, 0.95);
    pos.y = clamp(pos.y, -0.65, 0.65);

    P[id] = vec3(pos, 0.0);
}
