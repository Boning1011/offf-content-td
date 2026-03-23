// Particle rasterizer — reads 16x1152 state, draws on 384x1152 output
// Input 0: particle state (16x1152) — R=pos.x, G=vel.x, B=brightness, A=packed color

out vec4 fragColor;

// Unpack RGB from a single float
vec3 unpackColor(float f) {
    float r = mod(f, 256.0);
    float g = mod(floor(f / 256.0), 256.0);
    float b = mod(floor(f / 65536.0), 256.0);
    return vec3(r, g, b) / 255.0;
}

void main() {
    ivec2 outCoord = ivec2(gl_FragCoord.xy);
    int row = outCoord.y;
    float targetX = float(outCoord.x);

    // Accumulate from all 16 particle slots for this row
    vec3 totalColor = vec3(0.0);

    for (int col = 0; col < 16; col++) {
        vec4 state = texelFetch(sTD2DInputs[0], ivec2(col, row), 0);
        float px         = state.r;
        float brightness = state.b;
        float packedCol  = state.a;

        if (brightness > 0.005 && abs(round(px) - targetX) < 0.5) {
            vec3 spawnColor = unpackColor(packedCol);
            totalColor += spawnColor * brightness;
        }
    }

    fragColor = TDOutputSwizzle(vec4(min(totalColor, vec3(1.0)), step(0.001, length(totalColor))));
}
