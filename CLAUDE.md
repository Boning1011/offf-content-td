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

## Side LED Effects (Side_LED_ALL)

### Architecture: Effect_1 is the source, Effect_2+ are clones
All effects live under `/project1/Side_LED_ALL/Side_LED_Effect_1`. Effect_2 and others are clones — only edit Effect_1.

Top-level parameters exposed on `Side_LED_ALL` (parentshortcut: `settings`). Reference from inside as `parent.settings.par.X`.

### Effect history — key architectural change (2026-03-30)
**Cellular Automata (Brian's Brain) was removed and replaced by Streak Effect.**
- Old: `ca_glsl` / `cellular_automata_v2` — Brian's Brain CA with color propagation
- New: `streak_glsl` — per-pixel vertical streaks, speed tied to spawn brightness, random up/down direction

The CA effect nodes (`ca_glsl`, `ca_ctrl`, `ca_feedback`, `pixel_probability`, `cellular_automata`, `cellular_automata_v2`) no longer exist in the scene. Do not attempt to reference or restore them.

### Current effect chain (Effect_1)
```
in_side_A/B → lum_threshold → pixel_probability → streak_glsl (+ ca_feedback loop) → streak_lum_alpha → comp5 → out
                                                          ↑ feedback reads streak_glsl directly (velocity encoding preserved)
morse_chain_R/L → morse scanner (feedback loop) → comp5
```

### Streak effect key nodes
- `streak_glsl` — main shader, alpha encodes velocity (not opacity)
- `streak_lum_alpha` — downstream only: converts velocity-alpha to luminance for compositing
- `ca_feedback` — Feedback TOP, target = `streak_glsl` (provides previous frame)
- `level1` — brightness control, wired to `parent.settings.par.Streakbrightness`

### Streak Effect tab params (Side_LED_ALL)
- `Pixelprobability` — pixel survival probability at entry
- `Lumthreshold` — min input luminance to trigger a streak
- `Streakdecay` — trail decay per frame (and moving head decay)
- `Streakspeed` — max streak speed in px/frame
- `Streakbrightness` — overall brightness multiplier (level1.brightness1)

### Morse scanner key nodes (morse_chain_R/L)
- `morse1` (GLSL Multi TOP) — main scanner with feedback
- `morse_scanner` (Text DAT) — shader: `shaders/morse_scanner.glsl`
- `input_pixel_probability1` — time-bucketed pixel dropout at entry
- `hsvadj2` — value multiplier for color fade (wired to Colorfaderate)

### Scanline Effect tab params (Side_LED_ALL)
- `Pixelprobability` — morse entry pixel probability
- `Pixelprobrate` — how many frames between pixel probability pattern re-rolls
- `Morsesignalthresh` — input luminance threshold for morse scanner entry
- `Colorfaderate` — color fade per frame (range 0–0.001; 0.0001 = valuemult 0.9999)
