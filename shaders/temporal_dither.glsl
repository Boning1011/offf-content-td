// Temporal Dither - flicker-fade transitions in time domain
// Input 0: source image (any TOP)
// Input 1: feedback (previous frame)
//   R = display value (0 or 1)
//   G = decay timer (1.0 = just started fading, decreases toward 0)
out vec4 fragColor;

void main()
{
    ivec2 coord = ivec2(gl_FragCoord.xy);

    float src = texelFetch(sTD2DInputs[0], coord, 0).r;
    float current = step(0.5, src);

    vec4 prev = texelFetch(sTD2DInputs[1], coord, 0);
    float prevDisplay = prev.r;
    float prevTimer = prev.g;

    float display;
    float timer;

    if (current > 0.5) {
        // Source is ON: show white, reset timer
        display = 1.0;
        timer = 1.0;
    } else if (prevTimer > 0.01) {
        // Source is OFF but timer still running: flicker-decay
        timer = prevTimer * 0.92;

        // Flicker frequency decreases as timer decreases
        // High timer = fast flicker, low timer = sparse flicker then off
        float phase = fract(float(coord.x * 73 + coord.y * 137) * 0.0073);
        float flickerChance = timer * timer;
        display = step(1.0 - flickerChance, phase) ;
    } else {
        // Fully decayed
        display = 0.0;
        timer = 0.0;
    }

    fragColor = TDOutputSwizzle(vec4(display, timer, 0.0, 1.0));
}
