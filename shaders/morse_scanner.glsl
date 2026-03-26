// Morse Scanner - particle-style per-pixel scroll, no merge
//
// Input 0: feedback (previous frame) — RGB = color, A = speed factor
// Input 1: signal  - 1px vertical strip
//
// Pixels never merge. On collision they just stack up and stop.
// A pixel only leaves if the space ahead is free.

uniform float uFrame;
uniform float uDirection;
uniform float uDrag;
uniform float uSpeedVar;

out vec4 fragColor;

// PCG hash — much better distribution than sin-hash
uint pcg(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float rand(uint x, uint y, uint z) {
    uint h = pcg(x ^ pcg(y ^ pcg(z)));
    return float(h) * (1.0 / 4294967295.0);
}

void main()
{
    vec2 uv = vUV.st;
    vec2 res = uTDOutputInfo.res.zw;
    ivec2 coord = ivec2(gl_FragCoord.xy);

    float dir = sign(uDirection);
    int offset = (dir < 0.0) ? 1 : -1;

    bool isEdge = (dir < 0.0)
        ? (coord.x >= int(res.x) - 1)
        : (coord.x < 1);

    if (isEdge) {
        vec4 signal = texture(sTD2DInputs[1], vec2(0.5, uv.y));
        float spd = 1.0 - rand(uint(coord.y), uint(uFrame), 0u) * uSpeedVar;
        fragColor = TDOutputSwizzle(vec4(signal.rgb, spd));
        return;
    }

    // Read self, upstream (who might come in), downstream (where I would go)
    vec4 self       = texelFetch(sTD2DInputs[0], coord, 0);
    vec4 upstream   = texelFetch(sTD2DInputs[0], coord + ivec2(offset, 0), 0);
    vec4 downstream = texelFetch(sTD2DInputs[0], coord - ivec2(offset, 0), 0);

    bool selfOccupied = self.a > 0.01;
    bool upOccupied   = upstream.a > 0.01;
    bool downOccupied = downstream.a > 0.01;

    // Drag curves at each position
    float selfNorm = (dir < 0.0)
        ? (res.x - 1.0 - float(coord.x)) / res.x
        : float(coord.x) / res.x;
    float upNorm = (dir < 0.0)
        ? (res.x - 1.0 - float(coord.x + offset)) / res.x
        : float(coord.x + offset) / res.x;
    float downNorm = (dir < 0.0)
        ? (res.x - 1.0 - float(coord.x - offset)) / res.x
        : float(coord.x - offset) / res.x;

    float selfDrag = exp(-selfNorm * uDrag);
    float upDrag   = exp(-upNorm * uDrag);
    float downDrag = exp(-downNorm * uDrag);

    uint frame = uint(uFrame);

    // Dice rolls — keyed on each pixel's own position
    float selfRoll = rand(uint(coord.x), uint(coord.y), frame);
    float upRoll   = rand(uint(coord.x + offset), uint(coord.y), frame);
    float downRoll = rand(uint(coord.x - offset), uint(coord.y), frame);

    // Does downstream want to leave? (making room for me)
    bool downWantsMove = downOccupied && (downRoll < downstream.a * downDrag);
    bool canLeave = !downOccupied || downWantsMove;

    // Self: do I want to move AND can I actually leave?
    bool selfWantsMove = selfOccupied && (selfRoll < self.a * selfDrag);
    bool selfMoves = selfWantsMove && canLeave;

    // Upstream: wants to move AND I am free (empty or leaving)
    bool upWantsMove = upOccupied && (upRoll < upstream.a * upDrag);
    bool upArrives = upWantsMove && (!selfOccupied || selfMoves);

    // Resolve
    if (upArrives) {
        fragColor = TDOutputSwizzle(upstream);
    } else if (selfMoves) {
        fragColor = TDOutputSwizzle(vec4(0.0));
    } else if (selfOccupied) {
        fragColor = TDOutputSwizzle(self);
    } else {
        fragColor = TDOutputSwizzle(vec4(0.0));
    }
}