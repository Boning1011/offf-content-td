// Particle Life — Piecewise Linear force model (classic/original)
// Chain: feedback(target=glsl) -> neighbor -> glsl
// vel: read TDIn_ from input (feedback), write to created attr
//
// Force: normalized distance d = dist/rMax
//   d < beta:  repulsion = d/beta - 1  (linear -1 to 0)
//   d >= beta: attraction = g * (1 - |2d - 1 - beta| / (1 - beta))  (triangle)
//
// Uniforms (each is a separate float slider on the Vectors page):
//   uRMax, uFriction, uBeta, uForce, uDt, uBoundsX, uBoundsY

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

// Per-species scale: affects visual size AND interaction radii
const float scales[5] = float[5](0.8, 1.0, 0.6, 1.2, 0.9);

void main() {
    const uint id = TDIndex();
    if (id >= TDNumElements())
        return;

    vec3 pos = TDIn_P().xyz;
    vec3 velocity = TDIn_vel().xyz;
    uint myType = id % NUM_TYPES;
    float myScale = scales[myType];

    float rMax        = uRMax;
    float friction    = uFriction;
    float beta        = uBeta;          // repulsion zone (fraction of rMax)
    float forceFactor = uForce;
    float dt          = uDt;
    float bx          = uBoundsX;
    float by          = uBoundsY;

    uint numN = TDIn_NumNebrs();
    vec3 totalForce = vec3(0.0);

    for (uint i = 0u; i < numN; i++) {
        uint nebrIdx = TDIn_Nebr(0u, id, i);
        if (nebrIdx == 4294967295u) break;

        vec3 nebrPos = TDIn_P(0u, nebrIdx, 0u).xyz;
        uint nebrType = nebrIdx % NUM_TYPES;
        float pairScale = 0.5 * (myScale + scales[nebrType]);

        vec3 diff = nebrPos - pos;
        // Wrap-around shortest distance
        if (diff.x > bx) diff.x -= 2.0 * bx;
        if (diff.x < -bx) diff.x += 2.0 * bx;
        if (diff.y > by) diff.y -= 2.0 * by;
        if (diff.y < -by) diff.y += 2.0 * by;

        float dist = length(diff);
        float pairRMax = rMax * pairScale;
        if (dist < 0.0001 || dist > pairRMax) continue;

        float g = matrix[myType * NUM_TYPES + nebrType];

        // Piecewise linear force (classic Particle Life)
        float d = dist / pairRMax;  // normalized distance [0, 1]
        float force;
        if (d < beta) {
            // Repulsion zone: linear from -1 (at d=0) to 0 (at d=beta)
            force = d / beta - 1.0;
        } else {
            // Attraction zone: triangle peaking at d = (1+beta)/2
            force = g * (1.0 - abs(2.0 * d - 1.0 - beta) / (1.0 - beta));
        }

        totalForce += force * diff / dist;
    }

    // Apply force
    velocity += totalForce * forceFactor * dt;
    // Frame-rate independent friction: vel *= (1-friction)^(dt*60)
    velocity *= pow(1.0 - friction, dt * 60.0);
    pos += velocity * dt;

    // Wrap boundaries
    pos.x = mod(pos.x + bx, 2.0 * bx) - bx;
    pos.y = mod(pos.y + by, 2.0 * by) - by;
    pos.z = 0.0;

    P[id] = pos;
    vel[id] = velocity;
    // Sample ramp texture by species ID
    float t = float(myType) / float(NUM_TYPES - 1u);
    Color[id] = textureLod(sRamp, vec2(t, 0.5), 0.0);
    PointScale[id] = myScale;
}
