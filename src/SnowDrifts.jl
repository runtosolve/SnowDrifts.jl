"""
    SnowDrifts

Snow drift magnitudes and widths per ASCE/SEI 7-22, Chapter 7 ("Snow
Loads"). Implements:

- Eq. (7.3-1): flat roof snow load, `pf`
- Eq. (7.4-1): sloped (balanced) roof snow load, `ps`
- Eq. (7.6-1): drift height, `hd`
- Eq. (7.7-1): snow density, `γ`
- §7.6.1: unbalanced surcharge for hip/gable roofs
- §7.7.1: leeward and windward drifts on lower roofs
- §7.7.2: drifts from adjacent structures
- §7.8: drifts at roof projections and parapets

All quantities use US customary units consistent with the standard's
worked examples: lb/ft² for pressures, lb/ft³ for density, and ft for
lengths and heights. SI is not currently supported.

Ground snow load `pg` and the winter wind parameter `W2` are site- and
risk-category-specific; obtain them from the ASCE 7 Hazard Tool
(https://asce7hazardtool.online/) or, for Alaska, Table 7.2-1. This
package does not embed that geodatabase.

## Output variables

Most functions return a single `Float64`. The drift functions return a
[`DriftLoad`](@ref), with fields:

| Field | Meaning | Units |
|---|---|---|
| `hd` | design drift height (surcharge peak) | ft |
| `w` | drift width (horizontal extent of the surcharge) | ft |
| `pd` | maximum drift surcharge intensity, `pd = hd * γ` | lb/ft² |
| `hd_raw` | drift height before any `hc` cap is applied | ft |

| Function | Returns |
|---|---|
| `snow_density` | `γ`, snow density, lb/ft³ |
| `flat_roof_snow_load` | `pf`, flat roof snow load, lb/ft² |
| `sloped_roof_snow_load` | `ps`, sloped (balanced) roof snow load, lb/ft² |
| `balanced_snow_height` | `hb`, height of balanced snow load, ft |
| `minimum_snow_load` | `pm`, minimum roof snow load, lb/ft² |
| `drift_height` | `hd`, drift height, ft |
| `requires_drift_load` | `Bool` — whether `hc/hb >= 0.2` |
| `leeward_drift`, `windward_drift`, `adjacent_structure_drift`, `parapet_drift` | `DriftLoad` |
| `unbalanced_gable_hip_surcharge` | `DriftLoad` (`pd` is the surcharge intensity, `w` its extent from the ridge) |
| `roof_step_drift` | `NamedTuple(required::Bool, leeward::DriftLoad, windward::DriftLoad, governing::Symbol)` |
| `roof_projection_drift` | `NamedTuple(required::Bool, drift::Union{DriftLoad,Nothing})` |
"""
module SnowDrifts

include("types.jl")
include("balanced.jl")
include("drift_height.jl")
include("lower_roof_drifts.jl")
include("projections_parapets.jl")
include("unbalanced.jl")

end # module SnowDrifts
