// Stippling — radius-based repulsion, brightness modulates particle radius
//
// Sampler: sImage = source image
//
// Uniforms (named floats on Vectors page):
//   uRepulsion   — repulsion force multiplier
//   uDamping     — velocity decay (0 = instant stop, 1 = no friction)
//   uHalfHeight  — bounding box half-height (1.0 for 1×2)
//   uRadiusMin   — particle radius in bright areas (e.g. 0.5)
//   uRadiusMax   — particle radius in dark areas (e.g. 1.5)
//   uMaxVelocity — velocity clamp
//   uBaseSpacing — base unit for desired distance between particles
//
// Each particle's radius = mix(uRadiusMin, uRadiusMax, darkness).
// Two particles repel when closer than (radiusA + radiusB) * uBaseSpacing.
// Dot size is uniform — density is purely from particle spacing.

void main() {
    const uint id = TDIndex();
    if (id >= TDNumElements())
        return;

    vec3 pos = TDIn_P().xyz;
    vec3 prevVel = TDIn_vel().xyz;
    float halfH = uHalfHeight;

    // Map to UV
    vec2 uv = vec2(pos.x + 0.5, (pos.y + halfH) / (2.0 * halfH));
    uv = clamp(uv, 0.0, 1.0);

    // My brightness → my radius
    float brightness = dot(textureLod(sImage, uv, 0.0).rgb, vec3(0.299, 0.587, 0.114));
    float darkness = 1.0 - brightness;
    float myRadius = mix(uRadiusMin, uRadiusMax, darkness);

    // --- Neighbor repulsion based on radius overlap ---
    vec2 repForce = vec2(0.0);
    uint numN = TDIn_NumNebrs();

    for (uint i = 0u; i < numN; i++) {
        uint nIdx = TDIn_Nebr(0u, id, i);
        if (nIdx == 4294967295u) continue;

        vec3 nPos = TDIn_P(0u, nIdx, 0u).xyz;
        vec2 diff = pos.xy - nPos.xy;
        float dist = length(diff);
        if (dist < 0.0001) continue;

        // Neighbor brightness → neighbor radius
        vec2 nUv = vec2(nPos.x + 0.5, (nPos.y + halfH) / (2.0 * halfH));
        nUv = clamp(nUv, 0.0, 1.0);
        float nBright = dot(textureLod(sImage, nUv, 0.0).rgb, vec3(0.299, 0.587, 0.114));
        float nRadius = mix(uRadiusMin, uRadiusMax, 1.0 - nBright);

        // Desired spacing = sum of radii scaled by base spacing unit
        float desiredDist = (myRadius + nRadius) * uBaseSpacing;

        if (dist < desiredDist) {
            // Linear spring: force proportional to overlap
            float overlap = (desiredDist - dist) / desiredDist;
            repForce += normalize(diff) * overlap * uRepulsion;
        }
    }

    // --- Boundary repulsion (acts like a wall of virtual particles) ---
    float edgeZone = uBaseSpacing * uRadiusMax * 2.0;
    float edgeStr = uRepulsion * 3.0;

    float dLeft  = pos.x + 0.5;
    float dRight = 0.5 - pos.x;
    float dBot   = pos.y + halfH;
    float dTop   = halfH - pos.y;

    if (dLeft  < edgeZone) repForce.x += edgeStr * (edgeZone - dLeft)  / edgeZone;
    if (dRight < edgeZone) repForce.x -= edgeStr * (edgeZone - dRight) / edgeZone;
    if (dBot   < edgeZone) repForce.y += edgeStr * (edgeZone - dBot)   / edgeZone;
    if (dTop   < edgeZone) repForce.y -= edgeStr * (edgeZone - dTop)   / edgeZone;

    // --- Damped velocity ---
    vec2 newVel = prevVel.xy * uDamping + repForce;

    float vMag = length(newVel);
    if (vMag > uMaxVelocity) newVel *= uMaxVelocity / vMag;
    if (vMag < 0.000005) newVel = vec2(0.0);

    vec2 newPos = pos.xy + newVel;

    // Hard clamp as safety net
    newPos.x = clamp(newPos.x, -0.5, 0.5);
    newPos.y = clamp(newPos.y, -halfH, halfH);

    P[id] = vec3(newPos, 0.0);
    vel[id] = vec3(newVel, 0.0);
    Color[id] = vec4(1.0, 1.0, 1.0, 1.0);
}
