// ca_ctrl: spatial kill-rate map + global interval/frame
uniform float uKillRate;
uniform float uInterval;
uniform float uFrame;
out vec4 fragColor;

void main() {
    float mapVal = texture(sTD2DInputs[0], vUV.st).r;
    fragColor = TDOutputSwizzle(vec4(mapVal * uKillRate, uInterval, uFrame, 1.0));
}
