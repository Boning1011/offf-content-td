// Particle Life - 5 species with asymmetric attraction/repulsion
// Chain: feedback(target=glsl) -> neighbor -> glsl
// vel: read TDIn_ from input (feedback), write to created attr
// Force model: g/d (WebGL-style) with soft repulsion core

const uint NUM_TYPES = 5u;

// Interaction matrix: matrix[myType * NUM_TYPES + nebrType]
// Positive = attract, negative = repel
const float matrix[25] = float[25](
    //  T0     T1     T2     T3     T4
     0.10,  0.50, -0.20, -0.40,  0.30,   // Type 0
     0.60, -0.10, -0.40,  0.20, -0.20,   // Type 1
    -0.40,  0.60,  0.10,  0.40,  0.15,   // Type 2
     0.20, -0.30,  0.50, -0.15, -0.30,   // Type 3
    -0.30,  0.20, -0.20,  0.60,  0.10    // Type 4
);

void main() {
    const uint id = TDIndex();
    if (id >= TDNumElements())
        return;

    vec3 pos = TDIn_P().xyz;
    vec3 velocity = TDIn_vel().xyz;
    uint myType = id % NUM_TYPES;

    float rMax        = uParams.x;
    float friction    = uParams.y;
    float repCore     = uParams.z;   // soft repulsion core radius (fraction of rMax)
    float forceFactor = uParams.w;
    float dt          = uTime.x;
    float bx          = uBounds.x;
    float by          = uBounds.y;

    uint numN = TDIn_NumNebrs();
    vec3 totalForce = vec3(0.0);

    for (uint i = 0u; i < numN; i++) {
        uint nebrIdx = TDIn_Nebr(0u, id, i);
        if (nebrIdx == 4294967295u) break;

        vec3 nebrPos = TDIn_P(0u, nebrIdx, 0u).xyz;
        uint nebrType = nebrIdx % NUM_TYPES;

        vec3 diff = nebrPos - pos;
        // Wrap-around shortest distance
        if (diff.x > bx) diff.x -= 2.0 * bx;
        if (diff.x < -bx) diff.x += 2.0 * bx;
        if (diff.y > by) diff.y -= 2.0 * by;
        if (diff.y < -by) diff.y += 2.0 * by;

        float dist = length(diff);
        if (dist < 0.0001 || dist > rMax) continue;

        float g = matrix[myType * NUM_TYPES + nebrType];

        // g/d force with capped core: prevents divergence at close range
        float coreR = repCore * rMax;
        // Cap attraction: g/max(dist, coreR) — force plateaus inside core
        float attract = g / max(dist, coreR);
        // Universal repulsion inside core: pushes apart when too close
        float repulse = (dist < coreR)
            ? -(1.0 - dist / coreR) / coreR
            : 0.0;
        float force = attract + repulse;

        totalForce += force * diff / dist;
    }

    // Apply force
    velocity += totalForce * forceFactor * dt;
    // Frame-rate independent friction: vel *= friction^(dt*60)
    velocity *= pow(1.0 - friction, dt * 60.0);
    pos += velocity * dt;

    // Wrap boundaries
    pos.x = mod(pos.x + bx, 2.0 * bx) - bx;
    pos.y = mod(pos.y + by, 2.0 * by) - by;
    pos.z = 0.0;

    P[id] = pos;
    vel[id] = velocity;
}
