# offf-content-td

## Connection
- **Port: 7001**
- Tool repo: `touchdesigner-agent` (TCP bridge client at `bridge/client.py`)
- Always connect via `TDClient(port=7001)`

## GLSL POP Variants (sharing pointgen1)
- `glsl1` (original) → `glsl1_compute` → `shaders/glsl1_compute.glsl`
- `glsl_grid` → `grid_compute` → `shaders/grid.glsl`
- `glsl_bacteria` → `bacteria_compute` → `shaders/bacteria.glsl`
- Pointgen: 1000 points, rectangle, sizex=1, sizey=2 (1:2 ratio, vertical/tall)
- uTime on vec0, uTimeDelta on vec1 (bacteria shader needs both)

## Particle Life

### Node chain
```
pointgen_life → attr_life → feedback_life → neighbor_life → glsl_life → geo1
```

### Key configuration
- `feedback_life.targetpop = glsl_life` (feedback reads glsl output, delayed 1 frame)
- `attr_life` creates: `vel` (float3), `Color` (float4), `PointScale` (float1, default 1.0)
- `glsl_life` created attrs: `vel` (float3), `Color` (float4), `PointScale` (float1)
- `glsl_life` outputattrs: `P`
- Shader file: `shaders/particle_life.glsl`, DAT: `particle_life_compute`
- Sampler: `sRamp` → `ramp1` (Ramp TOP for species coloring)

### Simulation parameters
- 5 species, asymmetric 5×5 interaction matrix, Neighbor POP for spatial queries
- Force model: g/d (inverse distance) with soft repulsion core
- Per-species scale array affects both visual size (PointScale) and interaction radii (pairScale)
- Uniforms (each a separate float on Vectors page):
  - `uRMax` (vec0) — interaction radius (working: 0.15)
  - `uFriction` (vec1) — velocity damping (working: 0.4)
  - `uRepCore` (vec2) — soft core radius as fraction of rMax (working: 0.15)
  - `uForce` (vec3) — force multiplier (working: 0.1)
  - `uDt` (vec4) — timestep (working: 0.01)
  - `uBoundsX` (vec5) — half-width boundary (working: 0.5)
  - `uBoundsY` (vec6) — half-height boundary (working: 0.5)

### Render chain
```
geo1 → render1 → comp1 → out1
```
- Point Sprite MAT (`pointsprite1`) on geo1
- `pointsprite1.pointscaleattrib = 'PointScale'` — auto-reads per-particle size
- Render bg must be opaque black (`bgcolora=1`)
- Ramp-based coloring: shader samples `ramp1` by normalized species ID via `textureLod(sRamp, vec2(t, 0.5), 0.0)`. Adjust colors by editing `ramp1` — no shader changes needed.

### Reset procedure
```python
td.execute("op('/project1/feedback_life').par.initializepulse.pulse()")
td.execute("op('/project1/feedback_life').par.startpulse.pulse()")
```

### Baseline version
Commit `aef0854` (2026-03-11) — solid foundation with ramp coloring, per-species scale, feedback simulation.
