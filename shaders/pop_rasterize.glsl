// Particle rasterizer — reads 4x1152 state, draws on 384x1152 output
// Input 0: particle state (4x1152) — R=pos.x, G=vel.x, B=alive
// Input 1: left signal (1x1152, for color)
// Input 2: right signal (1x1152, for color)

out vec4 fragColor;

void main() {
    ivec2 outCoord = ivec2(gl_FragCoord.xy);
    int row = outCoord.y;
    float targetX = float(outCoord.x);
    vec2 uvY = vec2(0.5, (float(row) + 0.5) / float(textureSize(sTD2DInputs[0], 0).y));

    // Check only the 4 particles assigned to this row
    for (int col = 0; col < 4; col++) {
        vec4 state = texelFetch(sTD2DInputs[0], ivec2(col, row), 0);
        float px    = state.r;
        float alive = state.b;

        if (alive > 0.5 && abs(round(px) - targetX) < 0.5) {
            // Hit! Get color from signal
            bool fromRight = (col >= 2);
            vec4 signal = fromRight
                ? texture(sTD2DInputs[2], uvY)
                : texture(sTD2DInputs[1], uvY);
            fragColor = TDOutputSwizzle(vec4(signal.rgb, 1.0));
            return;
        }
    }

    fragColor = TDOutputSwizzle(vec4(0.0));
}
