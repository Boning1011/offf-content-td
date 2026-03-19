// Pixel Probability — randomly black out pixels based on a probability threshold
// Input: sTD2DInputs[0] — source image
// Uniform: uProb (vec0.x) — 0 = all black, 1 = fully pass through

uniform float uProb;

out vec4 fragColor;

// simple hash from pixel coordinate + a seed
float hash(vec2 p) {
    p = fract(p * vec2(443.8975, 397.2973));
    p += dot(p, p.yx + 19.19);
    return fract(p.x * p.y);
}

void main() {
    vec2 uv = vUV.st;
    vec4 col = texture(sTD2DInputs[0], uv);

    // per-pixel random value based on pixel coordinate
    vec2 res = uTDOutputInfo.res.zw;
    float r = hash(floor(uv * res));

    // if random > probability, kill the pixel
    fragColor = (r < uProb) ? col : vec4(0.0, 0.0, 0.0, col.a);
}
