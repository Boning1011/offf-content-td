// Morse Scanner - per-pixel drag based on brightness + hue
//
// Input 0: feedback (previous frame) — RGB = color, A = luminance (drag key)
// Input 1: signal  - 1px vertical strip
//
// Three drag layers (additive):
//   1. Positional drag (uDrag): all pixels slow down further from entry
//   2. Brightness drag (uBrightDrag): dark pixels get extra drag
//   3. Hue drag (uHueDrag): per-row, from entry signal hue (hue 0=red fastest, 0.5=cyan slowest)

uniform float uFrame;
uniform float uDirection;
uniform float uDrag;        // positional drag (1-5 range)
uniform float uSpeedVar;    // random luminance jitter at birth
uniform float uRhythm;
uniform float uStride;
uniform float uBrightDrag;  // brightness-based extra drag (1-5 range, 0 = off)
uniform float uHueDrag;     // hue-based extra drag (1-5 range, 0 = off)
uniform float uThreshold;   // input luminance threshold (0-1, below = black)

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

float rgb2hue(vec3 c) {
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d = mx - mn;
    if (d < 0.001) return 0.0;
    float h;
    if (mx == c.r)      h = mod((c.g - c.b) / d, 6.0);
    else if (mx == c.g) h = (c.b - c.r) / d + 2.0;
    else                h = (c.r - c.g) / d + 4.0;
    return h / 6.0;
}

float calcDrag(float normDist, float alpha, float rowHue, float drag, float brightDrag, float hueDrag) {
    float brightPart = (1.0 - alpha) * brightDrag;
    float huePart = rowHue * hueDrag;
    return exp(-normDist * (drag + brightPart + huePart));
}

void main()
{
    vec2 uv = vUV.st;
    vec2 res = uTDOutputInfo.res.zw;
    ivec2 coord = ivec2(gl_FragCoord.xy);
    uint frame = uint(uFrame);

    float dir = sign(uDirection);
    int dirI = (dir < 0.0) ? 1 : -1;

    bool isEdge = (dir < 0.0)
        ? (coord.x >= int(res.x) - 1)
        : (coord.x < 1);

    // Edge: inject signal, threshold by luminance, store lum in alpha
    if (isEdge) {
        vec4 signal = texture(sTD2DInputs[1], vec2(0.5, uv.y));
        float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));
        if (lum < uThreshold) {
            fragColor = TDOutputSwizzle(vec4(0.0));
            return;
        }
        lum = clamp(lum - rand(uint(coord.y), frame, 0u) * uSpeedVar, 0.02, 1.0);
        fragColor = TDOutputSwizzle(vec4(signal.rgb, lum));
        return;
    }

    // Row hue: sample entry signal once per row
    vec3 rowSignal = texture(sTD2DInputs[1], vec2(0.5, uv.y)).rgb;
    float rowHue = rgb2hue(rowSignal);

    vec4 self = texelFetch(sTD2DInputs[0], coord, 0);
    bool selfOccupied = self.a > 0.01;

    uint bucket = uint(floor(uFrame / max(uRhythm, 1.0)));

    float selfNorm = (dir < 0.0)
        ? (res.x - 1.0 - float(coord.x)) / res.x
        : float(coord.x) / res.x;
    float selfDrag = calcDrag(selfNorm, self.a, rowHue, uDrag, uBrightDrag, uHueDrag);

    float strideRand = rand(uint(coord.x), uint(coord.y), bucket * 3u + 1u);
    int myStride = max(int(ceil(strideRand * uStride)), 1);

    float selfRoll = rand(uint(coord.x), uint(coord.y), bucket);
    bool selfWantsMove = selfOccupied && (selfRoll < selfDrag);

    ivec2 downCoord = coord - ivec2(dirI * myStride, 0);
    downCoord.x = clamp(downCoord.x, 0, int(res.x) - 1);
    vec4 downstream = texelFetch(sTD2DInputs[0], downCoord, 0);
    bool downOccupied = downstream.a > 0.01;

    float downNorm = (dir < 0.0)
        ? (res.x - 1.0 - float(downCoord.x)) / res.x
        : float(downCoord.x) / res.x;
    float downDrag = calcDrag(downNorm, downstream.a, rowHue, uDrag, uBrightDrag, uHueDrag);
    float downRoll = rand(uint(downCoord.x), uint(downCoord.y), bucket);
    bool downWantsMove = downOccupied && (downRoll < downDrag);
    bool canLeave = !downOccupied || downWantsMove;

    bool selfMoves = selfWantsMove && canLeave;

    // Check upstream arrivals
    bool anyArrives = false;
    vec4 arrivingPixel = vec4(0.0);

    for (int s = 1; s <= int(uStride); s++) {
        ivec2 upCoord = coord + ivec2(dirI * s, 0);
        if (upCoord.x < 0 || upCoord.x >= int(res.x)) continue;

        vec4 up = texelFetch(sTD2DInputs[0], upCoord, 0);
        if (up.a < 0.01) continue;

        float upStrideRand = rand(uint(upCoord.x), uint(upCoord.y), bucket * 3u + 1u);
        int upStride = max(int(ceil(upStrideRand * uStride)), 1);
        if (upStride != s) continue;

        float upNorm = (dir < 0.0)
            ? (res.x - 1.0 - float(upCoord.x)) / res.x
            : float(upCoord.x) / res.x;
        float upDrag = calcDrag(upNorm, up.a, rowHue, uDrag, uBrightDrag, uHueDrag);
        float upRoll = rand(uint(upCoord.x), uint(upCoord.y), bucket);
        bool upWantsMove = (upRoll < upDrag);

        if (upWantsMove && (!selfOccupied || selfMoves)) {
            anyArrives = true;
            arrivingPixel = up;
            break;
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
