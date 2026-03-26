// Morse Scanner - chunky rhythmic movement
//
// Input 0: feedback (previous frame) — RGB = color, A = speed factor
// Input 1: signal  - 1px vertical strip
//
// Movement is decided in time buckets (every N frames), not every frame.
// When a pixel moves, it jumps multiple pixels at once.
// When it pauses, it holds for the full bucket duration.

uniform float uFrame;
uniform float uDirection;
uniform float uDrag;
uniform float uSpeedVar;
uniform float uRhythm;     // bucket size in frames (1 = every frame, 8 = chunky)
uniform float uStride;
uniform float uBrightSpeed;  // 0 = brightness has no effect, 1 = speed scales with luminance     // max pixels to jump per move (1 = original, 3 = chunky)

out vec4 fragColor;

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
    int dirI = (dir < 0.0) ? 1 : -1;

    bool isEdge = (dir < 0.0)
        ? (coord.x >= int(res.x) - 1)
        : (coord.x < 1);

    if (isEdge) {
        vec4 signal = texture(sTD2DInputs[1], vec2(0.5, uv.y));
        float spd = 1.0 - rand(uint(coord.y), uint(uFrame), 0u) * uSpeedVar;
        float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));
        spd *= mix(1.0, lum, uBrightSpeed);
        fragColor = TDOutputSwizzle(vec4(signal.rgb, spd));
        return;
    }

    vec4 self = texelFetch(sTD2DInputs[0], coord, 0);
    bool selfOccupied = self.a > 0.01;

    // Time bucket: decision changes every uRhythm frames
    uint bucket = uint(floor(uFrame / max(uRhythm, 1.0)));

    // Drag at my position
    float selfNorm = (dir < 0.0)
        ? (res.x - 1.0 - float(coord.x)) / res.x
        : float(coord.x) / res.x;
    float selfDrag = exp(-selfNorm * uDrag);

    // Per-pixel stride: 1 to uStride, varies per pixel per bucket
    float strideRand = rand(uint(coord.x), uint(coord.y), bucket * 3u + 1u);
    int myStride = max(int(ceil(strideRand * uStride)), 1);

    // Movement decision for self (once per bucket)
    float selfRoll = rand(uint(coord.x), uint(coord.y), bucket);
    bool selfWantsMove = selfOccupied && (selfRoll < self.a * selfDrag);

    // Check downstream: can I leave? (is the space myStride ahead free or leaving?)
    ivec2 downCoord = coord - ivec2(dirI * myStride, 0);
    // Clamp to valid range
    downCoord.x = clamp(downCoord.x, 0, int(res.x) - 1);
    vec4 downstream = texelFetch(sTD2DInputs[0], downCoord, 0);
    bool downOccupied = downstream.a > 0.01;

    float downNorm = (dir < 0.0)
        ? (res.x - 1.0 - float(downCoord.x)) / res.x
        : float(downCoord.x) / res.x;
    float downDrag = exp(-downNorm * uDrag);
    float downRoll = rand(uint(downCoord.x), uint(downCoord.y), bucket);
    bool downWantsMove = downOccupied && (downRoll < downstream.a * downDrag);
    bool canLeave = !downOccupied || downWantsMove;

    bool selfMoves = selfWantsMove && canLeave;

    // Check all upstream pixels that could jump into me
    // Any pixel within uStride distance upstream could land here
    bool anyArrives = false;
    vec4 arrivingPixel = vec4(0.0);

    for (int s = 1; s <= int(uStride); s++) {
        ivec2 upCoord = coord + ivec2(dirI * s, 0);
        if (upCoord.x < 0 || upCoord.x >= int(res.x)) continue;

        vec4 up = texelFetch(sTD2DInputs[0], upCoord, 0);
        if (up.a < 0.01) continue;

        // What stride did this upstream pixel roll?
        float upStrideRand = rand(uint(upCoord.x), uint(upCoord.y), bucket * 3u + 1u);
        int upStride = max(int(ceil(upStrideRand * uStride)), 1);

        // Does it want to jump exactly s pixels (landing on me)?
        if (upStride != s) continue;

        float upNorm = (dir < 0.0)
            ? (res.x - 1.0 - float(upCoord.x)) / res.x
            : float(upCoord.x) / res.x;
        float upDrag = exp(-upNorm * uDrag);
        float upRoll = rand(uint(upCoord.x), uint(upCoord.y), bucket);
        bool upWantsMove = (upRoll < up.a * upDrag);

        if (upWantsMove && (!selfOccupied || selfMoves)) {
            anyArrives = true;
            arrivingPixel = up;
            break;  // first one wins
        }
    }

    // Resolve
    if (anyArrives) {
        fragColor = TDOutputSwizzle(arrivingPixel);
    } else if (selfMoves) {
        fragColor = TDOutputSwizzle(vec4(0.0));
    } else if (selfOccupied) {
        fragColor = TDOutputSwizzle(self);
    } else {
        fragColor = TDOutputSwizzle(vec4(0.0));
    }
}