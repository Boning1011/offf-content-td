// Particle Life - 5 species with asymmetric attraction/repulsion
// Chain: feedback(target=glsl) -> neighbor -> glsl
// vel/col: read TDIn_ from input (feedback), write to created attrs

const uint NUM_TYPES = 5u;

const float matrix[25] = float[25](
    //  T0     T1     T2     T3     T4
    -0.10,  0.34,  0.10, -0.40,  0.25,   // Type 0 (green)
     0.40, -0.17, -0.34,  0.10, -0.30,   // Type 1 (red)
    -0.30,  0.50, -0.10,  0.34,  0.15,   // Type 2 (yellow)
     0.15, -0.30,  0.40, -0.20, -0.25,   // Type 3 (cyan)
    -0.20,  0.15, -0.30,  0.50, -0.10    // Type 4 (magenta)
);

const vec4 typeColors[5] = vec4[5](
    vec4(0.30, 0.90, 0.40, 1.0),
    vec4(0.95, 0.25, 0.25, 1.0),
    vec4(0.95, 0.90, 0.20, 1.0),
    vec4(0.20, 0.80, 0.95, 1.0),
    vec4(0.85, 0.30, 0.90, 1.0)
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
    float repZone     = uParams.z;
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
        float dist = length(diff);
        if (dist < 0.0001 || dist > rMax) continue;

        vec3 dir = diff / dist;
        float nd = dist / rMax;
        float g = matrix[myType * NUM_TYPES + nebrType];

        float f;
        if (nd < repZone) {
            f = nd / repZone - 1.0;
        } else {
            f = g * (1.0 - abs(2.0 * nd - 1.0 - repZone) / (1.0 - repZone));
        }
        totalForce += f * dir;
    }

    velocity = velocity * (1.0 - friction) + totalForce * rMax * forceFactor * dt;
    pos += velocity * dt;

    pos.x = mod(pos.x + bx, 2.0 * bx) - bx;
    pos.y = mod(pos.y + by, 2.0 * by) - by;
    pos.z = 0.0;

    P[id] = pos;
    vel[id] = velocity;
    col[id] = typeColors[myType];
}
