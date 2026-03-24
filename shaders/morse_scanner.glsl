// Morse Code Scanner - scrolling signal history per scanline
//
// Input 0 (wired):  feedback (previous frame)
// Input 1 (tops):   signal  - 1px wide vertical strip
// Input 2 (tops):   speed   - 1px wide vertical strip, per-row scroll speed
//
// uDirection: sign = scroll direction (-1 left, +1 right)
//             magnitude = speed multiplier (1.0 = normal)
uniform float uFrame;
uniform float uDirection;
uniform float uFadeRate;
uniform float uSpeedScale;
uniform float uMinSpeed;
uniform float uDragMin;
uniform float uDragCurve;
uniform float uEntrySpeed;
out vec4 fragColor;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

void main()
{
    vec2 uv = vUV.st;
    vec2 res = uTDOutputInfo.res.zw;
    ivec2 coord = ivec2(gl_FragCoord.xy);

    float speedMul = abs(uDirection);
    float dir = sign(uDirection); // -1 = left, +1 = right

    // Per-row speed (0..1)
    float speedNoise = texture(sTD2DInputs[2], vec2(0.5, uv.y)).r;

    // Per-row random roll (same for entire row this frame)
    float row = float(coord.y);
    float roll = hash(row * 7.31 + uFrame * 0.17);
    float baseSpeed = max(speedNoise * speedMul * uSpeedScale, uMinSpeed);

    // Distance from entry edge (0.0 = just entered, 1.0 = far end)
    float dist = (dir < 0.0)
        ? float(coord.x) / res.x          // scrolling left: entered from right
        : 1.0 - float(coord.x) / res.x;   // scrolling right: entered from left

    // Per-pixel scroll probability: high near entry, normal at far end.
    // Instead of shifting multiple pixels (which stretches), we shift by
    // exactly 1 pixel but scroll more frequently near the entry.
    float rawSpeed = mix(uEntrySpeed, uDragMin, pow(dist, uDragCurve));
    float speedMod = max(rawSpeed, 1.0);
    bool scrollHere = (roll < baseSpeed * speedMod);

    if (scrollHere) {
        // Edge pixel (1px deep): write fresh signal
        bool isEdge = (dir < 0.0)
            ? (coord.x >= int(res.x) - 1)
            : (coord.x < 1);

        if (isEdge) {
            vec4 signal = texture(sTD2DInputs[1], vec2(0.5, uv.y));
            float lum = dot(signal.rgb, vec3(0.299, 0.587, 0.114));
            float morse = step(0.5, lum);
            fragColor = TDOutputSwizzle(vec4(signal.rgb * morse, 1.0));
        } else {
            // Always shift by exactly 1 pixel — no stretching
            int offset = (dir < 0.0) ? 1 : -1;
            vec4 prev = texelFetch(sTD2DInputs[0], coord + ivec2(offset, 0), 0);
            // Probabilistic fade to black
            float prevLum = dot(prev.rgb, vec3(0.299, 0.587, 0.114));
            if (prevLum > 0.01) {
                float fadeChance = uFadeRate * 0.03;
                float fadeTick = floor(uFrame / 4.0);
                float fadeRoll = hash(float(coord.x) * 3.17 + float(coord.y) * 7.23 + fadeTick * 1.31);
                if (fadeRoll < fadeChance) {
                    prev.rgb = mix(prev.rgb, vec3(0.0), 0.25);
                }
            }
            fragColor = TDOutputSwizzle(prev);
        }
    } else {
        // Don't scroll: hold previous frame
        vec4 prev = texelFetch(sTD2DInputs[0], coord, 0);
        // Probabilistic fade to black
        float prevLum = dot(prev.rgb, vec3(0.299, 0.587, 0.114));
        if (prevLum > 0.01) {
            float fadeChance = uFadeRate * 0.03;
            float fadeTick = floor(uFrame / 4.0);
            float fadeRoll = hash(float(coord.x) * 3.17 + float(coord.y) * 7.23 + fadeTick * 1.31);
            if (fadeRoll < fadeChance) {
                prev.rgb = mix(prev.rgb, vec3(0.0), 0.25);
            }
        }
        fragColor = TDOutputSwizzle(prev);
    }
}