"""
    drift_height(pg, lu, W2, γ) -> hd

Snow drift height, `hd` (ft), from ASCE 7-22 Eq. (7.6-1):

    hd = 1.5 * sqrt( pg^0.74 * lu^0.70 * W2^1.7 / γ )

# Arguments
- `pg`: ground snow load, lb/ft²
- `lu`: length of the roof upwind of the drift, ft
- `W2`: winter wind parameter (fraction of time, October–April, that wind
  speed is ≥ 10 mph), from the ASCE 7 Hazard Tool (or Table 7.2-1 for
  Alaska)
- `γ`: snow density, lb/ft³, from [`snow_density`](@ref) (Eq. 7.7-1)

This is the fundamental drift-height relation used throughout ASCE 7-22
Chapter 7: unbalanced loads on hip/gable roofs (§7.6.1), drifts on lower
roofs (§7.7), and drifts at roof projections/parapets (§7.8). It replaces
the ASCE 7-16 relation hd = 0.43 lu^(1/3) (pg+10)^(1/4) − 1.5, which could
go negative for small lu or pg; the new form is positive for all valid
inputs.
"""
function drift_height(pg::Real, lu::Real, W2::Real, γ::Real)
    pg > 0 || throw(ArgumentError("pg must be positive"))
    lu >= 0 || throw(ArgumentError("lu must be nonnegative"))
    W2 > 0 || throw(ArgumentError("W2 must be positive"))
    γ > 0 || throw(ArgumentError("γ must be positive"))
    return 1.5 * sqrt(pg^0.74 * lu^0.70 * W2^1.7 / γ)
end
