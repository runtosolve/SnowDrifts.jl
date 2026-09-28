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
"""
module SnowDrifts

export snow_density, flat_roof_snow_load, sloped_roof_snow_load,
       balanced_snow_height, minimum_snow_load,
       drift_height,
       DriftLoad,
       requires_drift_load, leeward_drift, windward_drift, roof_step_drift,
       adjacent_structure_drift,
       parapet_drift, roof_projection_drift,
       unbalanced_gable_hip_surcharge

include("types.jl")
include("balanced.jl")
include("drift_height.jl")
include("lower_roof_drifts.jl")
include("projections_parapets.jl")
include("unbalanced.jl")

end # module SnowDrifts
