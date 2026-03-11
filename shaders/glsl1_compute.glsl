// Bacteria colony clustering shader
// Particles attract to noise-field hotspots and wiggle like microorganisms

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

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal noise — organic cluster potential field
float fbm(vec2 p, float t) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    for (int i = 0; i < 5; i++) {
        v += a * valueNoise(p + t * 0.04);
        p = p * 2.0 + shift;
        a *= 0.5;
        t *= 1.1;
    }
    return v;
}

// Gradient of cluster field — particles climb toward peaks
vec2 fieldGrad(vec2 p, float t) {
    float eps = 0.005;
    float cx = fbm(p + vec2(eps, 0.0), t) - fbm(p - vec2(eps, 0.0), t);
    float cy = fbm(p + vec2(0.0, eps), t) - fbm(p - vec2(0.0, eps), t);
    return vec2(cx, cy) / (2.0 * eps);
}

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

    // First-frame scatter
    if (t < 0.05) {
        P[id] = vec3((r2.x * 2.0 - 1.0) * 0.8, (r2.y * 2.0 - 1.0) * 0.5, 0.0);
        return;
    }

    vec2 pos = cur.xy;

    // === BACTERIA CLUSTERING ===

    // 1) Primary colony attraction — large blob clusters
    float fieldScale = 2.5;
    vec2 grad = fieldGrad(pos * fieldScale, t * 0.15);
    vec2 attractForce = grad * 1.2;

    // 2) Sub-colony structure — smaller clusters within big colonies
    vec2 grad2 = fieldGrad(pos * fieldScale * 3.0 + vec2(50.0), t * 0.1);
    attractForce += grad2 * 0.4;

    // 3) Micro cohesion — tighten local clumps
    vec2 grad3 = fieldGrad(pos * 8.0 + vec2(200.0, 300.0), t * 0.08);
    attractForce += grad3 * 0.25;

    // 4) Bacteria wiggle — rapid directional jitter
    float wiggleFreq = 8.0 + r0 * 6.0;
    float wiggleAngle = t * wiggleFreq + r0 * 100.0;
    float wiggleMag = 0.06 + r1 * 0.04;
    vec2 wiggle = vec2(cos(wiggleAngle), sin(wiggleAngle)) * wiggleMag;

    // 5) Slow persistent drift
    float driftAngle = r0 * 6.2831853 + sin(t * (0.15 + r1 * 0.2) + r0 * 50.0) * 3.14;
    vec2 drift = vec2(cos(driftAngle), sin(driftAngle)) * 0.03;

    // 6) Boundary repulsion
    vec2 boundary = vec2(0.0);
    float bx = 0.85;
    float by = 0.55;
    if (pos.x >  bx) boundary.x -= (pos.x - bx) * 5.0;
    if (pos.x < -bx) boundary.x -= (pos.x + bx) * 5.0;
    if (pos.y >  by) boundary.y -= (pos.y - by) * 5.0;
    if (pos.y < -by) boundary.y -= (pos.y + by) * 5.0;

    // Combine
    vec2 totalForce = attractForce + wiggle + drift + boundary;

    // Clamp speed
    float speed = length(totalForce);
    if (speed > 0.4) {
        totalForce = totalForce / speed * 0.4;
    }

    // Integrate with damping
    pos += totalForce * dt * 0.88;

    // Safety clamp
    pos.x = clamp(pos.x, -1.0, 1.0);
    pos.y = clamp(pos.y, -0.7, 0.7);

    P[id] = vec3(pos, 0.0);
}
