// scroll_chain — drag scroll: speed decreases with distance from right edge
// Input 0: feedback (prev frame)
// Input 1: signal (in1), sampled at center column and injected at right edge
//
// Per-pixel speed: v(x) = (x / (W-1)) ^ uDrag
//   uDrag = 0 → uniform 1 px/frame (original behavior)
//   uDrag = 1 → linear falloff
//   uDrag > 1 → stronger drag, pile-up on the left
// Monotonic in x, so order is preserved: no pixel can overtake its left neighbor.

out vec4 fragColor;

void main() {
    vec2 uv = vUV.st;
    vec2 res = uTDOutputInfo.res.zw;
    ivec2 coord = ivec2(gl_FragCoord.xy);

    // Inject fresh signal at the right edge
    if (coord.x >= int(res.x) - 1) {
        fragColor = TDOutputSwizzle(texture(sTD2DInputs[1], vec2(0.5, uv.y)));
        return;
    }

    // Position-dependent scroll speed (0 at left, 1 at right)
    float nx = float(coord.x) / max(res.x - 1.0, 1.0);
    float speed = pow(nx, max(uDrag.x, 0.0));

    // Sub-pixel advection via linear texture filtering
    vec2 src = (vec2(coord) + vec2(speed, 0.0) + 0.5) / res.xy;
    fragColor = TDOutputSwizzle(texture(sTD2DInputs[0], src));
}
