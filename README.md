# SnowDrifts.jl

Snow drift magnitudes and widths per **ASCE/SEI 7-22**, Chapter 7 ("Snow
Loads"). All quantities use US customary units (lb/ft², lb/ft³, ft),
consistent with the standard's worked examples. SI is not currently
supported.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/<your-org>/SnowDrifts.jl")
```

No names are exported: after `using SnowDrifts`, call functions with the
module prefix, e.g. `SnowDrifts.drift_height(...)`. (You can still bring
specific names into unqualified scope with `using SnowDrifts: drift_height`
if you prefer.)

## What's implemented

| ASCE 7-22 reference | Function |
|---|---|
| Eq. (7.3-1) — flat roof snow load | `flat_roof_snow_load` |
| Eq. (7.4-1) — sloped (balanced) roof snow load | `sloped_roof_snow_load` |
| §7.1.2 — balanced snow height | `balanced_snow_height` |
| §7.3.3 / Table 7.3-4 — minimum snow load | `minimum_snow_load` |
| Eq. (7.7-1) — snow density, γ | `snow_density` |
| Eq. (7.6-1) — drift height | `drift_height` |
| §7.6.1 — unbalanced surcharge, hip/gable roofs | `unbalanced_gable_hip_surcharge` |
| §7.7.1 — leeward drift on lower roof | `leeward_drift` |
| §7.7.1 — windward drift on lower roof | `windward_drift` |
| §7.7.1 — combined roof-step evaluation | `roof_step_drift` |
| §7.7.2 — drift from adjacent structure | `adjacent_structure_drift` |
| §7.8 — parapet wall drift | `parapet_drift` |
| §7.8 — roof projection drift | `roof_projection_drift` |

`pg` (ground snow load) and `W2` (winter wind parameter) are
site- and risk-category-specific. Obtain them from the
[ASCE 7 Hazard Tool](https://asce7hazardtool.online/) or, for Alaska,
Table 7.2-1. This package does not embed that geodatabase.

## Example: drift at a roof step

```julia
using SnowDrifts

pg, W2 = 30.0, 0.45          # from the ASCE 7 Hazard Tool
Ce, Ct, Cs = 1.0, 1.0, 1.0

γ  = SnowDrifts.snow_density(pg)
pf = SnowDrifts.flat_roof_snow_load(pg; Ce=Ce, Ct=Ct)
ps = SnowDrifts.sloped_roof_snow_load(pf, Cs)
hb = SnowDrifts.balanced_snow_height(ps, γ)

hc = 6.0            # clear height from top of balanced snow to upper roof
lu_upper = 120.0    # length of upper roof
lu_lower = 60.0     # length of lower roof

result = SnowDrifts.roof_step_drift(pg, W2, γ, hb, hc, lu_upper, lu_lower)

if result.required
    println("Governing case: ", result.governing)
    println("Leeward:  ", result.leeward)
    println("Windward: ", result.windward)
else
    println("hc/hb < 0.2 — drift loads need not be applied")
end
```

The leeward and windward drifts are separate load cases (they are not
superimposed); ASCE 7-22 §7.7.1 requires checking both independently to
determine which controls the design of a given member.

## A note on ASCE 7-22 vs. ASCE 7-16

ASCE 7-22 replaced the drift-height relation used since 1988,

```
hd = 0.43 lu^(1/3) (pg + 10)^(1/4) − 1.5
```

(which could produce negative, and therefore physically meaningless,
drift heights for small `lu` or `pg`) with a new relation incorporating
the winter wind parameter `W2` (Eq. 7.6-1, implemented here as
`drift_height`):

```
hd = 1.5 * sqrt( pg^0.74 * lu^0.70 * W2^1.7 / γ )
```

ASCE 7-22 also removed the height cap (`hc`) on **windward** drifts
(§7.7.1) that ASCE 7-16 applied uniformly to both leeward and windward
cases — windward drift height and width in this package are therefore
computed uncapped, per the current standard.

## Testing

```
julia --project=. -e 'using Pkg; Pkg.test()'
```

The test suite validates `drift_height` and
`unbalanced_gable_hip_surcharge` numerically against Commentary Example 1
in ASCE 7-22 §C7.6.

## Disclaimer

This package is an engineering aid, not a substitute for the standard
itself or for the judgment of a licensed professional engineer. Verify
all inputs (`pg`, `W2`, `Ce`, `Ct`, `Cs`, and roof geometry) and outputs
against ASCE/SEI 7-22 before use in design.
