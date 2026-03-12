# Particle Life — Design Notes & Future Directions

## Current Implementation

### Algorithm Overview

Each frame, for every particle:
1. Read previous position & velocity from feedback
2. Determine species (`id % 5`)
3. Loop over neighbors (from Neighbor POP spatial hash)
4. Compute pairwise force using asymmetric interaction matrix
5. Accumulate forces → update velocity (with friction decay) → update position
6. Wrap position at domain boundaries

### Force Model: g/d with Soft Core

Inspired by [CapsAdmin/webgl-particles](https://github.com/CapsAdmin/webgl-particles).

```
force = g / max(dist, coreR)          // attraction/repulsion (capped at core)
      + repulsion(dist, coreR)         // universal push inside core radius
```

- **g**: interaction coefficient from the 5x5 matrix (positive = attract, negative = repel)
- **g/d**: force grows as particles approach — creates tight clusters and chase dynamics
- **Soft core cap**: `g / max(dist, coreR)` prevents force divergence at close range
- **Universal repulsion**: linear push `-(1 - dist/coreR) / coreR` inside core radius — prevents collapse

This differs from the original Particle Life (piecewise linear) but produces more organic, fluid behavior.

### Interaction Matrix

5 species with asymmetric relationships — `matrix[A * 5 + B]` is the force A feels toward B.

```
         T0     T1     T2     T3     T4
T0:    +0.10  +0.50  -0.20  -0.40  +0.30
T1:    +0.60  -0.10  -0.40  +0.20  -0.20
T2:    -0.40  +0.60  +0.10  +0.40  +0.15
T3:    +0.20  -0.30  +0.50  -0.15  -0.30
T4:    -0.30  +0.20  -0.20  +0.60  +0.10
```

Key relationships:
- **T0 <-> T1**: mutual strong attraction (+0.50 / +0.60) — form tight mixed clusters
- **T2 -> T1**: chase (+0.60), but T1 repels T2 (-0.40) — classic predator-prey
- **T3 -> T2**: chase (+0.50), T2 also attracted to T3 (+0.40) — mutual clustering
- **T4 -> T3**: chase (+0.60), but T3 repels T4 (-0.30) — another chase-flee pair

Emergent macro behavior: layered/onion-like clustering or spiral chase chains.

### Per-Species Scale

```glsl
const float scales[5] = float[5](0.8, 1.0, 0.6, 1.2, 0.9);
```

Affects both visual point size AND interaction radius (`pairRMax = rMax * avg(scaleA, scaleB)`).
Larger species "see" farther and appear bigger — creates natural hierarchy.

### Simplifications

| Aspect | Current | Full Version |
|--------|---------|--------------|
| Force model | g/d with cap | Could be piecewise linear, Lennard-Jones, etc. |
| Matrix | Hardcoded in shader | Could be uniform / texture / runtime-editable |
| Neighbor query | No wrap-around | Neighbor POP doesn't support periodic boundaries — causes edge artifacts |
| Species assignment | Fixed (`id % 5`) | Could be dynamic (mutation, spatial, etc.) |
| Coloring | Ramp by species ID | No per-particle variation within species |

### Working Parameters

| Uniform | Value | Role |
|---------|-------|------|
| `uRMax` | 0.15 | Interaction radius |
| `uFriction` | 0.4 | Velocity damping per frame |
| `uRepCore` | 0.25 | Soft core radius (fraction of rMax) |
| `uForce` | 0.1 | Global force multiplier |
| `uDt` | 0.01 | Fixed timestep |
| `uBoundsX` | 0.5 | Half-width of domain |
| `uBoundsY` | 1.0 | Half-height of domain |

Friction is frame-rate independent: `vel *= pow(1 - friction, dt * 60)`.

---

## Ideas & Future Directions

### 1. Spatially Varying Interaction Matrix

Blend between different force rules based on world position:

```glsl
float blend = smoothstep(-by, by, pos.y);
float g = mix(uniformRepulsion, matrix[...], blend);
```

- Bottom region: universal repulsion → even particle distribution
- Top region: normal matrix → organic Particle Life clusters
- Transition zone: gradient between order and chaos

Could also use radial distance, noise fields, or TOP textures to drive spatial variation.

### 2. Species Mutation / Reactive Affinity

Particles change species based on local conditions:
- Surrounded by 3+ hostile neighbors → mutate
- Enter a spatial "reaction zone" → transform
- Probability matrix: each species pair has a mutation chance

Creates ecosystem dynamics — population waves, predator-prey oscillations, extinction events.

### 3. Time-Varying Matrix

Slowly modulate matrix coefficients over time:

```glsl
float phase = uTime * 0.1;
float g = matrix[idx] + 0.3 * sin(phase + float(idx));
```

The entire system periodically reorganizes — breathing, pulsing macro structures.

### 4. Multiple Force Matrices (from community research)

Separate matrices for:
- Attraction strength
- Repulsion strength
- Attraction radius
- Repulsion radius

Each pair of species gets 4 independent parameters instead of 1 — much richer dynamics.

### 5. Interaction Probability

Not every encounter produces force — add a probability per species pair. Creates "sparse connection" effects and organic noise at the macro level.

### 6. Interaction Viscosity

Different species pairs produce different local drag. Two species that interact might slow each other down (high viscosity) or speed up (negative viscosity / catalytic).

### 7. Distance-Dependent Force Profiles

Instead of one force function, use different profiles at different ranges:
- Close: strong repulsion (current)
- Mid: attraction/repulsion from matrix (current)
- Far: weak universal attraction (new — creates large-scale coherence)

### 8. Texture-Driven Parameters

Use TOP inputs to spatially control any parameter:
- A noise TOP controlling `forceFactor` across space
- A gradient TOP controlling `friction` (sticky zones vs slippery zones)
- A video feed modulating the interaction matrix

Natural fit for TouchDesigner's texture-based workflow.

### 9. 3D Extension

Current simulation is 2D (`pos.z = 0`). Adding Z:
- Change pointgen to sphere/cube distribution
- Remove `pos.z = 0` line
- Add `bz` boundary + Z wrap-around
- Render with instanced geometry instead of point sprites

### 10. Neighbor Wrap-Around Fix

Current Neighbor POP doesn't support periodic boundaries. Particles at edges "lose" neighbors on the other side. Possible fixes:
- Ghost particles: duplicate edge particles on the opposite side (expensive)
- Custom spatial hash in the GLSL shader itself (complex but correct)
- Accept the artifact and use it aesthetically (current approach)

---

## References

- [Particle Life](https://particle-life.com/) — original concept, interactive demos
- [hunar4321/particle-life](https://github.com/hunar4321/particle-life) — C++/JS/Python implementations
- [CapsAdmin/webgl-particles](https://github.com/CapsAdmin/webgl-particles) — WebGL reference (g/d force model)
- [Clusters by Ventrella](https://www.ventrella.com/Clusters/) — influential predecessor
- [Particle Life WebGPU (lisyarus)](https://lisyarus.github.io/blog/posts/particle-life-simulation-in-browser-using-webgpu.html) — WebGPU implementation notes
- [Particle Life 3D/4D](https://tucan444.itch.io/particle-life-3d-4d) — higher-dimensional extensions
- [ALIEN Project](https://www.alien-project.org/) — CUDA soft-body artificial life with sensors/muscles
- [Sandbox Science](https://sandbox-science.com/particle-life) — extended model with probability, viscosity, reactive affinity
- [Codrops/UntilLabs](https://tympanus.net/codrops/2025/12/10/simulating-life-in-the-browser-creating-a-living-particle-system-for-the-untillabs-website/) — photo→particle system, production WebGL
- [Red Blob Games — Hunar Alife](https://www.redblobgames.com/x/2234-hunar-alife-simulation/) — interactive analysis
